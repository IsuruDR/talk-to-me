#!/bin/bash
# Speaks a casual summary of what the session accomplished when the main agent stops.
# Reads the last few assistant messages from the transcript, summarizes via claude CLI,
# then speaks the summary using local TTS.
#
# TTS priority: piper (neural, natural) > macOS say > espeak > spd-say > festival
# Reads config from ~/.config/talk-to-me/config.json

set -euo pipefail

INPUT=$(cat)
TTS_DIR="/tmp/talk-to-me-tts/$$"
PIPER_VOICES_DIR="$HOME/.local/share/talk-to-me/piper-voices"

# First-run nudge: if dependencies are missing, write a one-time hint file.
NUDGE_FILE="$HOME/.config/talk-to-me/.setup-nudged"
if [ ! -f "$NUDGE_FILE" ]; then
  MISSING=""
  command -v jq &>/dev/null || MISSING="jq"
  command -v claude &>/dev/null || MISSING="${MISSING:+$MISSING, }claude"
  if [ -n "$MISSING" ]; then
    mkdir -p "$HOME/.config/talk-to-me"
    touch "$NUDGE_FILE"
    echo "[talk-to-me] Missing dependencies: $MISSING. Run /talk-to-me:setup to install everything." >&2
    exit 1
  fi
  mkdir -p "$HOME/.config/talk-to-me"
  touch "$NUDGE_FILE"
fi

# Skip subagent completions — only speak for the main session
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // empty')
if [ -n "$AGENT_ID" ]; then
  exit 0
fi

# Get session info from the Stop hook input
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  exit 0
fi

# Read all user config upfront
CONFIG_FILE="$HOME/.config/talk-to-me/config.json"
MIN_DURATION=300
VOICE=""
RATE=""
TTS_ENGINE=""
PIPER_VOICE=""

if [ -f "$CONFIG_FILE" ]; then
  ENABLED=$(jq -r '.enabled // true' "$CONFIG_FILE")
  if [ "$ENABLED" = "false" ]; then
    exit 0
  fi
  MIN_DURATION=$(jq -r '.min_duration // 300' "$CONFIG_FILE")
  VOICE=$(jq -r '.voice // empty' "$CONFIG_FILE")
  RATE=$(jq -r '.rate // empty' "$CONFIG_FILE")
  TTS_ENGINE=$(jq -r '.tts_engine // empty' "$CONFIG_FILE")
  PIPER_VOICE=$(jq -r '.piper_voice // empty' "$CONFIG_FILE")
fi

# Default piper voice
[ -z "$PIPER_VOICE" ] && PIPER_VOICE="en_US-lessac-high"

# Check if user is in a meeting or mic is active — stay silent
is_in_meeting() {
  # Check for known meeting app call processes (works even with mic muted)
  pgrep -x CptHost >/dev/null 2>&1 && return 0       # Zoom in-call
  pgrep -f "Microsoft Teams.*callservice" >/dev/null 2>&1 && return 0  # Teams in-call
  pgrep -f "FaceTime" >/dev/null 2>&1 && return 0     # FaceTime

  # Fallback: check if mic hardware is active (catches any app using mic)
  case "$(uname)" in
    Darwin)
      swift -e 'import AVFoundation; print(AVCaptureDevice.default(for: .audio)?.isInUseByAnotherApplication ?? false)' 2>/dev/null | grep -q "true" && return 0 ;;
    Linux)
      [ "$(pactl list source-outputs 2>/dev/null | grep -c 'Corked: no')" -gt 0 ] && return 0 ;;
  esac
  return 1
}

if is_in_meeting; then
  exit 0
fi

# Check elapsed time — only speak if the agent worked long enough
PROMPT_DIR="/tmp/talk-to-me-prompts"
TS_FILE="$PROMPT_DIR/$SESSION_ID.ts"
if [ -n "$SESSION_ID" ] && [ -f "$TS_FILE" ]; then
  START_TS=$(cat "$TS_FILE")
  NOW_TS=$(date +%s)
  ELAPSED=$((NOW_TS - START_TS))
  if [ "$ELAPSED" -lt "$MIN_DURATION" ]; then
    rm -f "$TS_FILE" "$PROMPT_DIR/$SESSION_ID.txt"
    exit 0
  fi
fi

# Read the user's most recent prompt (saved by UserPromptSubmit hook)
USER_PROMPT=""
PROMPT_FILE="$PROMPT_DIR/$SESSION_ID.txt"
if [ -n "$SESSION_ID" ] && [ -f "$PROMPT_FILE" ]; then
  USER_PROMPT=$(head -c 500 "$PROMPT_FILE")
  rm -f "$PROMPT_FILE" "$TS_FILE"
fi

# Extract the last few assistant text messages from the transcript (tail for recency)
CONTEXT=$(tail -20 "$TRANSCRIPT" | jq -r '
  select(.type == "assistant") |
  [.message.content[]? | select(.type == "text") | .text] | join("\n")
' 2>/dev/null | tail -c 2000)

# If no context found, stay silent
if [ -z "$CONTEXT" ]; then
  exit 0
fi

# Need claude CLI to summarize — stay silent if unavailable
if ! command -v claude &>/dev/null; then
  exit 0
fi

# Build the prompt with user question + assistant context
PROMPT_CONTEXT=""
if [ -n "$USER_PROMPT" ]; then
  PROMPT_CONTEXT="User asked: $USER_PROMPT

Assistant's work (truncated):
$CONTEXT"
else
  PROMPT_CONTEXT="Recent conversation:
$CONTEXT"
fi

# Summarize with claude CLI (headless mode)
# NOTE: The summary is spoken by a TTS engine with limited prosody.
# Avoid slang, contractions like "wanna/gonna", rhetorical questions,
# and emoji. Use clear, simple sentences that sound natural when read
# with flat intonation.
PROMPT="A coding session just finished. Summarize what was done in ONE sentence under 30 words. Only describe what actually happened in the conversation below. Do not invent or assume work that is not mentioned. It should be a statement of done.

Rules:
- Simple clear words. No slang. No contractions like wanna or gonna.
- No emoji. No exclamation marks. No quotation marks. No questions.
- Plain statement only.

$PROMPT_CONTEXT

Your one-sentence summary:"

SUMMARY=$(echo "$PROMPT" | claude --print --model haiku 2>/dev/null | tr -d '\n' | head -c 200)

if [ -z "$SUMMARY" ]; then
  exit 0
fi

# Prepend project directory name for context
PROJECT_NAME=""
if [ -n "$CWD" ]; then
  PROJECT_NAME=$(basename "$CWD")
fi

if [ -n "$PROJECT_NAME" ]; then
  MESSAGE="$PROJECT_NAME. $SUMMARY"
else
  MESSAGE="$SUMMARY"
fi

# --- Playback lock (serialize across parallel sessions) ---

LOCK_DIR="/tmp/talk-to-me-playback.lock"
LOCK_TIMEOUT=30

acquire_playback_lock() {
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    # Remove stale lock (older than LOCK_TIMEOUT seconds)
    if [ -d "$LOCK_DIR" ]; then
      case "$(uname)" in
        Darwin) LOCK_AGE=$(( $(date +%s) - $(stat -f %m "$LOCK_DIR") )) ;;
        *)      LOCK_AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK_DIR") )) ;;
      esac
      [ "$LOCK_AGE" -gt "$LOCK_TIMEOUT" ] && rmdir "$LOCK_DIR" 2>/dev/null
    fi
    sleep 0.5
  done
}

release_playback_lock() {
  rmdir "$LOCK_DIR" 2>/dev/null
}

# --- TTS Engine Functions (foreground — lock must be held) ---

speak_piper() {
  local model_path="$PIPER_VOICES_DIR/$PIPER_VOICE.onnx"
  if [ ! -f "$model_path" ]; then
    return 1
  fi
  mkdir -p "$TTS_DIR"
  local wav="$TTS_DIR/output.wav"
  echo "$1" | piper --model "$model_path" --output_file "$wav" 2>/dev/null
  if [ -f "$wav" ]; then
    if command -v afplay &>/dev/null; then
      afplay "$wav"
    elif command -v aplay &>/dev/null; then
      aplay "$wav"
    fi
    rm -rf "$TTS_DIR"
  fi
}

speak_say() {
  CMD=(say)
  [ -n "$VOICE" ] && CMD+=(-v "$VOICE")
  [ -n "$RATE" ] && CMD+=(-r "$RATE")
  "${CMD[@]}" "$1"
}

speak_espeak() {
  CMD=(espeak)
  [ -n "$VOICE" ] && CMD+=(-v "$VOICE")
  [ -n "$RATE" ] && CMD+=(-s "$RATE")
  "${CMD[@]}" "$1"
}

speak_spd_say() {
  CMD=(spd-say)
  [ -n "$VOICE" ] && CMD+=(-o "$VOICE")
  [ -n "$RATE" ] && CMD+=(-r "$RATE")
  "${CMD[@]}" "$1"
}

speak_festival() {
  echo "$1" | festival --tts
}

# Acquire lock, speak, release
acquire_playback_lock
trap release_playback_lock EXIT

# If user forced a specific engine, use it
if [ -n "$TTS_ENGINE" ]; then
  case "$TTS_ENGINE" in
    piper)   speak_piper "$MESSAGE" ;;
    say)     speak_say "$MESSAGE" ;;
    espeak)  speak_espeak "$MESSAGE" ;;
    spd-say) speak_spd_say "$MESSAGE" ;;
    festival) speak_festival "$MESSAGE" ;;
  esac
  exit 0
fi

# Auto-detect best available engine
if command -v piper &>/dev/null && [ -f "$PIPER_VOICES_DIR/$PIPER_VOICE.onnx" ]; then
  speak_piper "$MESSAGE"
elif command -v say &>/dev/null; then
  speak_say "$MESSAGE"
elif command -v espeak &>/dev/null; then
  speak_espeak "$MESSAGE"
elif command -v spd-say &>/dev/null; then
  speak_spd_say "$MESSAGE"
elif command -v festival &>/dev/null; then
  speak_festival "$MESSAGE"
fi

exit 0

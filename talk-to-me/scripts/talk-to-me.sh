#!/bin/bash
# Speaks a casual summary of what the session accomplished when the main agent stops.
# Reads the last few assistant messages from the transcript, summarizes via ollama,
# then speaks the summary using local TTS.
# Falls silent if ollama is unavailable — no fallback, no noise.
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
  command -v ollama &>/dev/null || MISSING="${MISSING:+$MISSING, }ollama"
  if [ -n "$MISSING" ]; then
    mkdir -p "$HOME/.config/talk-to-me"
    touch "$NUDGE_FILE"
    echo "[talk-to-me] Missing dependencies: $MISSING. Run /talk-to-me:setup to install everything." >&2
    exit 1
  fi
  if command -v ollama &>/dev/null && ! ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -q '.'; then
    mkdir -p "$HOME/.config/talk-to-me"
    touch "$NUDGE_FILE"
    echo "[talk-to-me] ollama is installed but has no models. Run /talk-to-me:setup to pull one." >&2
    exit 1
  fi
  mkdir -p "$HOME/.config/talk-to-me"
  touch "$NUDGE_FILE"
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
MIN_DURATION=60
VOICE=""
RATE=""
MODEL=""
TTS_ENGINE=""
PIPER_VOICE=""

if [ -f "$CONFIG_FILE" ]; then
  MIN_DURATION=$(jq -r '.min_duration // 60' "$CONFIG_FILE")
  VOICE=$(jq -r '.voice // empty' "$CONFIG_FILE")
  RATE=$(jq -r '.rate // empty' "$CONFIG_FILE")
  MODEL=$(jq -r '.model // empty' "$CONFIG_FILE")
  TTS_ENGINE=$(jq -r '.tts_engine // empty' "$CONFIG_FILE")
  PIPER_VOICE=$(jq -r '.piper_voice // empty' "$CONFIG_FILE")
fi

# Default piper voice
[ -z "$PIPER_VOICE" ] && PIPER_VOICE="en_US-lessac-high"

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

# Need ollama to summarize — stay silent if unavailable
if ! command -v ollama &>/dev/null; then
  exit 0
fi

if ! ollama list &>/dev/null 2>&1; then
  exit 0
fi

# Auto-detect ollama model
if [ -z "$MODEL" ]; then
  MODEL=$(ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -iE '^(qwen2\.5:0\.5b|qwen2\.5:1\.5b|qwen2\.5:3b|llama3\.2:1b|llama3\.2:3b|gemma2:2b|phi3:mini|smollm)' | head -1)
fi

if [ -z "$MODEL" ]; then
  MODEL=$(ollama list 2>/dev/null | awk 'NR>1 {print $1}' | head -1)
fi

if [ -z "$MODEL" ]; then
  exit 0
fi

# Build the ollama prompt with user question + assistant context
PROMPT_CONTEXT=""
if [ -n "$USER_PROMPT" ]; then
  PROMPT_CONTEXT="User asked: $USER_PROMPT

Assistant's work (truncated):
$CONTEXT"
else
  PROMPT_CONTEXT="Recent conversation:
$CONTEXT"
fi

# Summarize with ollama
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

Your one-sentence casual summary:"

SUMMARY=$(ollama run "$MODEL" "$PROMPT" 2>/dev/null | tr -d '\n' | head -c 200)

if [ -z "$SUMMARY" ]; then
  exit 0
fi

# Prepend project directory name for context
PROJECT_NAME=""
if [ -n "$CWD" ]; then
  PROJECT_NAME=$(basename "$CWD")
fi

if [ -n "$PROJECT_NAME" ]; then
  MESSAGE="In $PROJECT_NAME. $SUMMARY"
else
  MESSAGE="$SUMMARY"
fi

# --- TTS Engine Functions ---

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
      afplay "$wav" && rm -rf "$TTS_DIR" &
    elif command -v aplay &>/dev/null; then
      aplay "$wav" && rm -rf "$TTS_DIR" &
    fi
  fi
}

speak_say() {
  CMD=(say)
  [ -n "$VOICE" ] && CMD+=(-v "$VOICE")
  [ -n "$RATE" ] && CMD+=(-r "$RATE")
  "${CMD[@]}" "$1" &
}

speak_espeak() {
  CMD=(espeak)
  [ -n "$VOICE" ] && CMD+=(-v "$VOICE")
  [ -n "$RATE" ] && CMD+=(-s "$RATE")
  "${CMD[@]}" "$1" &
}

speak_spd_say() {
  CMD=(spd-say)
  [ -n "$VOICE" ] && CMD+=(-o "$VOICE")
  [ -n "$RATE" ] && CMD+=(-r "$RATE")
  "${CMD[@]}" "$1" &
}

speak_festival() {
  echo "$1" | festival --tts &
}

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

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
TTS_DIR="/tmp/talk-to-me-tts"
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

# Get the transcript path from the Stop hook input
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty')

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  exit 0
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

# Read user config
CONFIG_FILE="$HOME/.config/talk-to-me/config.json"
VOICE=""
RATE=""
MODEL=""
TTS_ENGINE=""
PIPER_VOICE=""

if [ -f "$CONFIG_FILE" ]; then
  VOICE=$(jq -r '.voice // empty' "$CONFIG_FILE")
  RATE=$(jq -r '.rate // empty' "$CONFIG_FILE")
  MODEL=$(jq -r '.model // empty' "$CONFIG_FILE")
  TTS_ENGINE=$(jq -r '.tts_engine // empty' "$CONFIG_FILE")
  PIPER_VOICE=$(jq -r '.piper_voice // empty' "$CONFIG_FILE")
fi

# Default piper voice
[ -z "$PIPER_VOICE" ] && PIPER_VOICE="en_US-lessac-high"

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

# Summarize with ollama
PROMPT="You are a casual notification voice assistant. A coding session just finished. Based on the recent conversation below, write ONE short casual sentence (under 15 words) saying what was accomplished. Sound like a chill coworker giving a quick update. Don't use quotes or punctuation marks that would sound weird spoken aloud. Don't start with 'Hey' or 'So'.

Recent conversation:
$CONTEXT

Your one-sentence casual summary:"

MESSAGE=$(ollama run "$MODEL" "$PROMPT" 2>/dev/null | tr -d '\n' | head -c 200)

if [ -z "$MESSAGE" ]; then
  exit 0
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
      afplay "$wav" &
    elif command -v aplay &>/dev/null; then
      aplay "$wav" &
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

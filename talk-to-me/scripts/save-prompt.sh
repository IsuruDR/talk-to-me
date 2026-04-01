#!/bin/bash
# Saves the user's prompt and a timestamp to a session-specific temp file.
# Called by the UserPromptSubmit hook. The Stop hook reads this
# to include the user's question in the summary context and to check
# whether enough time has elapsed to warrant a spoken summary.

set -euo pipefail

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty')

if [ -z "$SESSION_ID" ] || [ -z "$PROMPT" ]; then
  exit 0
fi

# Save prompt and start timestamp per session
PROMPT_DIR="/tmp/talk-to-me-prompts"
mkdir -p "$PROMPT_DIR"
echo "$PROMPT" > "$PROMPT_DIR/$SESSION_ID.txt"
date +%s > "$PROMPT_DIR/$SESSION_ID.ts"

exit 0

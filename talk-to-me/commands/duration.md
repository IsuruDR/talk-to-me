---
description: Set minimum duration (seconds) before talk-to-me speaks a summary
allowed-tools: Bash, Read, Write
---

# Duration

Set the minimum number of seconds the agent must work before speaking a summary when the session ends.

Default is `300` (5 minutes). Set to `0` to always speak.

## Behavior

1. Read current config from `~/.config/talk-to-me/config.json` (if it exists).
2. If the user passed an argument (e.g. `/talk-to-me:duration 60`), set `min_duration` to that value.
3. If no argument, show the current value and ask what they want to set it to.
4. Write the updated config to `~/.config/talk-to-me/config.json` (create parent dirs if needed). Preserve any existing fields.
5. Confirm the change.

## Examples

- `/talk-to-me:duration 60` — speak after 1 minute of work
- `/talk-to-me:duration 0` — always speak
- `/talk-to-me:duration 300` — speak after 5 minutes (default)
- `/talk-to-me:duration` — show current value and prompt

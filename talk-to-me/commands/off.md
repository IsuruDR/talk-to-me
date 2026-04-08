---
description: Disable talk-to-me announcements without uninstalling
allowed-tools: Bash, Read, Write
---

# Disable talk-to-me

1. Read `~/.config/talk-to-me/config.json` (create if missing).
2. Set `"enabled": false`. Preserve all other fields.
3. Write the config back.
4. Confirm: "talk-to-me is now **off**. Run `/talk-to-me:on` to re-enable."

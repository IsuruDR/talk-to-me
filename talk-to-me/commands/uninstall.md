---
description: Remove talk-to-me hooks from settings and clean up all data
allowed-tools: Bash, Read, Write
---

# Uninstall

Remove all talk-to-me hooks from `~/.claude/settings.json` and clean up data files.

## Steps

### 1. Remove hooks from settings.json

Read `~/.claude/settings.json`. Remove any entries in `hooks.UserPromptSubmit` and `hooks.Stop` arrays where the command references `talk-to-me`. If removing the entry leaves the array empty, remove the key entirely. Write back the updated JSON. Be careful not to modify any other hooks.

### 2. Uninstall piper

Run:
```sh
pip3 uninstall -y piper-tts 2>/dev/null; brew uninstall piper 2>/dev/null; true
```

### 3. Clean up data

```sh
rm -rf ~/.config/talk-to-me
rm -rf ~/.local/share/talk-to-me
```

### 4. Reload plugins

Tell the user to run:
```
/reload-plugins
```

### 5. Show summary

```
Uninstall complete!

  hooks:   ✓ removed from settings.json
  piper:   ✓ uninstalled
  data:    ✓ cleaned up

To finish, run:
  /plugin uninstall talk-to-me@talk-to-me
  /plugin marketplace remove talk-to-me
```

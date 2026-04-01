---
description: Install and verify all dependencies for talk-to-me (ollama, jq, TTS engine, model)
allowed-tools: Bash, Read, Write
---

# Setup

Walk the user through installing everything needed for the talk-to-me plugin. Check each dependency, install what's missing, and verify the full pipeline works.

## Dependency checklist

Run these checks in order. For each one, check if it exists, and if not, offer to install it.

### 1. jq

- **Check**: `command -v jq`
- **macOS**: `brew install jq`
- **Linux (Debian/Ubuntu)**: `sudo apt install -y jq`
- **Linux (Fedora)**: `sudo dnf install -y jq`

### 2. TTS engine

Check which TTS engine is available. At least one is required.

- **macOS**: `say` is built-in — just verify with `command -v say`
- **Linux**: check for `espeak`, `spd-say`, or `festival` in that order

If on Linux and none are found, recommend:
```sh
sudo apt install -y espeak    # Lightweight, good enough
```

### 3. ollama

- **Check**: `command -v ollama`
- **macOS**: `brew install ollama`
- **Linux**: `curl -fsSL https://ollama.com/install.sh | sh`

After installing, check if the ollama server is running:
- **Check**: `ollama list` (if it errors, the server isn't running)
- **Start**: `ollama serve &` (or tell user it runs as a background service on Linux after install)

On macOS, after `brew install ollama`, the user needs to start the Ollama app or run `ollama serve` in the background. Check if it's running and guide them.

### 4. Pull a model

- **Check**: `ollama list` — look for any model
- If no models: `ollama pull qwen2.5:3b` (good balance of speed and quality)
- If models exist already, show them and confirm one will be used

### 5. Verify the full pipeline

Run an end-to-end test by piping sample hook input through the script:

```sh
echo '{"tool_input":{"description":"Explore HelloSign integration"},"tool_response":[{"type":"text","text":"Mapped the complete HelloSign signing flow including API endpoints, authentication setup, and signer configuration. Found that documents are sent ad-hoc without templates, using a single hardcoded signer."}]}' | ${CLAUDE_PLUGIN_ROOT}/scripts/talk-to-me.sh
```

If the user hears a spoken summary, setup is complete. If not, diagnose which step failed.

### 6. Optional: configure voice and model

After everything works, mention that `/talk-to-me:voice` lets them customize the TTS voice, speech rate, and ollama model.

## Reset nudge marker

After a successful setup, remove the first-run nudge marker so the hook knows everything is configured:

```sh
rm -f ~/.config/talk-to-me/.setup-nudged
```

This ensures the hook won't show the "run /talk-to-me:setup" message again, and also means if someone later uninstalls a dependency, the hook will re-detect and nudge again on next run.

## Output

At the end, show a summary:

```
Setup complete!

  jq:      ✓ installed
  TTS:     ✓ say (macOS)
  ollama:  ✓ running
  model:   ✓ qwen2.5:3b

Run /talk-to-me:voice to customize the voice and model.
```

## Arguments

- `/talk-to-me:setup` — run the full setup flow
- `/talk-to-me:setup check` — just check dependencies without installing anything

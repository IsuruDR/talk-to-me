---
description: Install and verify all dependencies for talk-to-me (jq, piper TTS, voice model)
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

### 2. Claude CLI

- **Check**: `command -v claude`
- This should already be installed since the user is running the plugin from Claude Code. If missing, something is wrong with their setup.

### 3. TTS engine (Piper recommended)

**Piper — neural TTS, natural sounding, cross-platform:**
- **Check**: `command -v piper`
- **Install**: `pip3 install piper-tts` (or `pip3 install --break-system-packages piper-tts` if needed)
- If piper install fails due to pip restrictions, try: `pipx install piper-tts` or `brew install piper`

**Download a voice model** (required for piper):
```sh
mkdir -p ~/.local/share/talk-to-me/piper-voices
cd ~/.local/share/talk-to-me/piper-voices
curl -sL "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/high/en_US-lessac-high.onnx" -o en_US-lessac-high.onnx
curl -sL "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/high/en_US-lessac-high.onnx.json" -o en_US-lessac-high.onnx.json
```

**Verify piper works**:
```sh
echo "Just finished setting up the talk to me plugin" | piper --model ~/.local/share/talk-to-me/piper-voices/en_US-lessac-high.onnx --output_file /tmp/piper-test.wav && afplay /tmp/piper-test.wav
```

If the user doesn't want to install piper, fallbacks are available:
- **macOS**: `say` is built-in (robotic but works)
- **Linux**: `espeak`, `spd-say`, or `festival`

### 4. Verify the full pipeline

Test piper TTS directly:
```sh
echo "Just wrapped up all the code changes and everything looks good" | piper --model ~/.local/share/talk-to-me/piper-voices/en_US-lessac-high.onnx --output_file /tmp/piper-test.wav && afplay /tmp/piper-test.wav
```

If the user hears the speech, setup is complete.

### 5. Optional: configure voice and settings

After everything works, mention that `/talk-to-me:voice` lets them customize the TTS engine, piper voice, and minimum duration threshold.

## Available piper voices

If the user wants to try different voices, these are good English options. Download both the `.onnx` and `.onnx.json` files to `~/.local/share/talk-to-me/piper-voices/`:

| Voice | Quality | Gender | Accent | Size |
|-------|---------|--------|--------|------|
| `en_US-lessac-high` | High | Female | US | ~65MB |
| `en_US-lessac-medium` | Medium | Female | US | ~65MB |
| `en_US-ryan-high` | High | Male | US | ~65MB |
| `en_US-amy-medium` | Medium | Female | US | ~65MB |
| `en_GB-alan-medium` | Medium | Male | British | ~65MB |
| `en_GB-alba-medium` | Medium | Female | British | ~65MB |

Base URL: `https://huggingface.co/rhasspy/piper-voices/resolve/main/en/`
Full catalog: https://rhasspy.github.io/piper-samples/

## Reset nudge marker

After a successful setup, remove the first-run nudge marker:

```sh
rm -f ~/.config/talk-to-me/.setup-nudged
```

## Output

At the end, show a summary:

```
Setup complete!

  jq:      ✓ installed
  claude:  ✓ available
  TTS:     ✓ piper (en_US-lessac-high)

Run /talk-to-me:voice to customize the voice and settings.
```

## Arguments

- `/talk-to-me:setup` — run the full setup flow
- `/talk-to-me:setup check` — just check dependencies without installing anything

---
description: Configure TTS engine, voice, and settings for session completion announcements
allowed-tools: Bash, Read, Write
---

# Voice Configuration

Help the user configure the talk-to-me plugin: TTS engine, voice, and minimum duration threshold.

## Config location

Settings are stored in `~/.config/talk-to-me/config.json`. Create the directory and file if they don't exist. The schema is:

```json
{
  "enabled": true,
  "tts_engine": "piper",
  "piper_voice": "en_US-lessac-high",
  "voice": "Daniel",
  "rate": null,
  "min_duration": 300
}
```

- `enabled`: whether talk-to-me is active. `true` (default) or `false` to disable without uninstalling.
- `tts_engine`: which TTS to use — `"piper"`, `"say"`, `"espeak"`, `"spd-say"`, `"festival"`. `null` means auto-detect best available.
- `piper_voice`: piper voice model name (without `.onnx` extension). Default `"en_US-lessac-high"`. Only used when tts_engine is piper.
- `voice`: voice name for say/espeak/spd-say engines. `null` means system default.
- `rate`: speech rate override (words per minute) for say/espeak/spd-say. `null` means system default.
- `min_duration`: minimum seconds the agent must work before speaking a summary. Default `300` (5 minutes). Set to `0` to always speak.

## Behavior

1. **Read current config** from `~/.config/talk-to-me/config.json` (if it exists) and show all current settings.

2. **Detect available TTS engines** in priority order:
   - Piper: `command -v piper` and check for voice models in `~/.local/share/talk-to-me/piper-voices/`
   - macOS say: `command -v say`
   - Linux espeak/spd-say/festival

3. **Show current configuration** in a clean summary, then **ask what the user wants to do**:
   - Turn on / off
   - Change the TTS engine
   - Change the voice
   - Change the minimum duration threshold
   - Reset to defaults

## TTS Engine Selection

### Piper — recommended (neural TTS, natural sounding)
- **Check**: `command -v piper`
- **Voice models stored in**: `~/.local/share/talk-to-me/piper-voices/`
- **Available voices** (list `.onnx` files in the voices directory):
  - `en_US-lessac-high` — Female US (default, best quality)
  - `en_US-ryan-high` — Male US
  - `en_GB-alan-medium` — Male British
  - `en_GB-alba-medium` — Female British
### macOS say — fallback
- **List voices**: `say -v '?' | grep "en_"`

## Saving

When the user picks settings, write the config to `~/.config/talk-to-me/config.json` (create parent dirs if needed). Only include fields the user explicitly set — omit fields that should use defaults. Confirm the save.

## Arguments

If the user passes arguments to this command:
- `/talk-to-me:voice on` — enable talk-to-me
- `/talk-to-me:voice off` — disable talk-to-me (keeps config, just silences it)
- `/talk-to-me:voice duration <seconds>` — set minimum duration before speaking (default 300)
- `/talk-to-me:voice reset` — reset to system defaults (delete config file)
- `/talk-to-me:voice list` — list available engines and voices
- No arguments — run the full interactive flow

---
description: Configure TTS engine, voice, and summarization model for session completion announcements
allowed-tools: Bash, Read, Write
---

# Voice Configuration

Help the user configure the talk-to-me plugin: TTS engine, voice, and the ollama model used to summarize session output.

## Config location

Settings are stored in `~/.config/talk-to-me/config.json`. Create the directory and file if they don't exist. The schema is:

```json
{
  "tts_engine": "piper",
  "piper_voice": "en_US-lessac-high",
  "voice": "Daniel",
  "rate": null,
  "model": "qwen2.5:3b"
}
```

- `tts_engine`: which TTS to use — `"piper"`, `"say"`, `"espeak"`, `"spd-say"`, `"festival"`. `null` means auto-detect best available.
- `piper_voice`: piper voice model name (without `.onnx` extension). Default `"en_US-lessac-high"`. Only used when tts_engine is piper.
- `voice`: voice name for say/espeak/spd-say engines. `null` means system default.
- `rate`: speech rate override (words per minute) for say/espeak/spd-say. `null` means system default.
- `model`: ollama model for summarization. `null` means auto-detect the smallest available model.

## Behavior

1. **Read current config** from `~/.config/talk-to-me/config.json` (if it exists) and show all current settings.

2. **Detect available TTS engines** in priority order:
   - Piper: `command -v piper` and check for voice models in `~/.local/share/talk-to-me/piper-voices/`
   - macOS say: `command -v say`
   - Linux espeak/spd-say/festival

3. **Check ollama status**: run `ollama list` to see which models are available.

4. **Show current configuration** in a clean summary, then **ask what the user wants to do**:
   - Preview a voice / TTS engine
   - Change the TTS engine
   - Change the voice
   - Change the summarization model
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
- **Preview a piper voice**:
  ```sh
  echo "Done mapping out the HelloSign integration and all the API endpoints" | piper --model ~/.local/share/talk-to-me/piper-voices/<voice_name>.onnx --output_file /tmp/talk-to-me-preview.wav && afplay /tmp/talk-to-me-preview.wav
  ```
- **To download a new voice**: download both `.onnx` and `.onnx.json` from https://huggingface.co/rhasspy/piper-voices/tree/main/en/ to `~/.local/share/talk-to-me/piper-voices/`
- Full voice catalog with samples: https://rhasspy.github.io/piper-samples/

### macOS say — fallback
- **Preview**: `say -v "<voice_name>" "Done mapping out the HelloSign integration and all the API endpoints"`
- **List voices**: `say -v '?' | grep "en_"`

## Model selection

When the user wants to change the ollama summarization model:
1. Show available models from `ollama list`
2. Recommend lightweight models for speed: qwen2.5:0.5b, qwen2.5:1.5b, qwen2.5:3b, llama3.2:1b, llama3.2:3b, gemma2:2b
3. If the user wants a model that isn't pulled yet, offer to pull it with `ollama pull <model>`
4. Let them test the model by running a sample summarization:
   ```
   ollama run <model> "You are a casual notification voice assistant. An AI agent just finished a task. Write ONE short casual sentence (under 30 words) saying what it did. ALWAYS end with a question like requesting the user to take a look. The sentence should be a statement of completion. Sound like a chill coworker. Task: Explore HelloSign integration. Output: Done mapping out the helloSign integration and all the API endpoints, please take a look."
   ```

## Saving

When the user picks settings, write the config to `~/.config/talk-to-me/config.json` (create parent dirs if needed). Only include fields the user explicitly set — omit fields that should use defaults. Confirm the save.

## Arguments

If the user passes arguments to this command:
- `/talk-to-me:voice preview <name>` — preview that voice (auto-detects engine)
- `/talk-to-me:voice engine <name>` — set the TTS engine (piper, say, espeak)
- `/talk-to-me:voice set <name>` — set the voice for the current engine
- `/talk-to-me:voice model <name>` — set the ollama model
- `/talk-to-me:voice reset` — reset to system defaults (delete config file)
- `/talk-to-me:voice list` — list available engines, voices, and models
- No arguments — run the full interactive flow

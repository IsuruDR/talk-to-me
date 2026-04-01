---
description: Configure voice, speech rate, and summarization model for agent completion announcements
allowed-tools: Bash, Read, Write
---

# Voice Configuration

Help the user configure the talk-to-me plugin: TTS voice, speech rate, and the ollama model used to summarize agent output.

## Config location

Settings are stored in `~/.config/talk-to-me/config.json`. Create the directory and file if they don't exist. The schema is:

```json
{
  "voice": "Samantha",
  "rate": null,
  "model": "qwen2.5:3b"
}
```

- `voice`: the TTS voice name (platform-specific). `null` means system default.
- `rate`: speech rate override (words per minute). `null` means system default.
- `model`: ollama model for summarization. `null` means auto-detect the smallest available model.

## Behavior

1. **Read current config** from `~/.config/talk-to-me/config.json` (if it exists) and show all current settings.

2. **Check ollama status**: run `ollama list` to see which models are available. If ollama isn't installed, mention that the plugin requires it and suggest `brew install ollama` (macOS) or the ollama install script (Linux).

3. **Detect the platform and TTS engine**:
   - macOS: run `say -v ?` to get available voices
   - Linux espeak: run `espeak --voices` to get available voices
   - Linux spd-say: run `spd-say -L` to get available voices

4. **Show current configuration** in a clean summary, then **ask what the user wants to do**:
   - Preview a voice
   - Change the voice
   - Change the speech rate
   - Change the summarization model
   - Reset to defaults

## Preview

When the user wants to preview a voice, run the TTS command with a sample message:

- macOS: `say -v "<voice_name>" "Done mapping out the HelloSign integration and all the API endpoints"`
- Linux espeak: `espeak -v "<voice_name>" "Done mapping out the HelloSign integration and all the API endpoints"`
- Linux spd-say: `spd-say -o "<voice_name>" "Done mapping out the HelloSign integration and all the API endpoints"`

If the user also wants to test a rate:
- macOS: `say -v "<voice_name>" -r <rate> "Done mapping out the HelloSign integration and all the API endpoints"`

Let the user preview as many voices as they want before making a choice.

## Model selection

When the user wants to change the model:
1. Show available models from `ollama list`
2. Recommend lightweight models for speed: qwen2.5:0.5b, qwen2.5:1.5b, qwen2.5:3b, llama3.2:1b, llama3.2:3b, gemma2:2b
3. If the user wants a model that isn't pulled yet, offer to pull it with `ollama pull <model>`
4. Let them test the model by running a sample summarization:
   ```
   ollama run <model> "You are a casual notification voice assistant. An AI agent just finished a task. Write ONE short casual sentence (under 15 words) saying what it did. Sound like a chill coworker. Task: Explore HelloSign integration. Output: Mapped the complete HelloSign signing flow, API endpoints, authentication, and signer configuration."
   ```

## Saving

When the user picks settings, write the config to `~/.config/talk-to-me/config.json` (create parent dirs if needed). Only include fields the user explicitly set — omit fields that should use defaults. Confirm the save.

## Arguments

If the user passes arguments to this command:
- `/talk-to-me:voice preview <name>` — immediately preview that voice, then offer to save or try others
- `/talk-to-me:voice set <name>` — immediately set that voice and confirm
- `/talk-to-me:voice model <name>` — set the ollama model and confirm
- `/talk-to-me:voice reset` — reset to system defaults (delete config file)
- `/talk-to-me:voice list` — list available voices and models
- No arguments — run the full interactive flow

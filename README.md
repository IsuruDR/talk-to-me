# talk-to-me

A Claude Code plugin that speaks a casual summary of what your session accomplished when the main agent finishes.

When you're running parallel agents and multitasking, it's easy to miss when Claude is done. This plugin summarizes the session via Claude CLI, then speaks it aloud in a natural voice — e.g., *"talk-to-me. Finished setting up piper TTS and committed the changes."*

## How it works

```mermaid
flowchart LR
    A[User sends prompt] --> B[Save prompt + timestamp]
    B --> C[Agent completes]
    C --> D[Summarize via\nclaude --print --model haiku]
    D --> E[Generate WAV via piper]
    E --> F[Play audio]
    F --> G[Clean up temp files]
```

The plugin registers two hooks:

1. **UserPromptSubmit** — saves the user's prompt and a timestamp for each session
2. **Stop** — when the main agent finishes, checks elapsed time, reads the transcript, summarizes via `claude --print`, and speaks via piper TTS

Quick interactions (under 5 minutes) stay silent. Only longer tasks get announced.

Generated audio files are written to a PID-scoped temp directory (`/tmp/talk-to-me-tts/{pid}/`) and automatically cleaned up after playback completes.

If piper isn't installed, falls back to macOS `say` or Linux `espeak`.

## Quick start

After installing the plugin, run:

```
/talk-to-me:setup
```

This installs all dependencies (jq, piper, a voice model), then verifies the full pipeline.

## Requirements

Handled automatically by `/talk-to-me:setup`:

- **Claude CLI** — already installed (you're running Claude Code)
- **jq** — JSON parsing (`brew install jq` / `apt install jq`)
- **piper-tts** — neural text-to-speech (`pip install piper-tts`)
- A piper voice model (~65MB, downloaded during setup)

## Platform support

| Platform | TTS engine | Quality |
|----------|-----------|---------|
| macOS / Linux | **piper** (neural) | Natural, human-like |
| macOS | `say` (fallback) | Robotic but built-in |
| Linux | `espeak` / `spd-say` / `festival` (fallback) | Robotic but built-in |

Piper is recommended. It's fast (sub-second), cross-platform, and sounds natural. The plugin auto-detects the best available engine.

## Installation

### From GitHub (recommended)

In Claude Code, run:

```
/plugin marketplace add IsuruDR/talk-to-me
```

Then install the plugin:

```
/plugin install talk-to-me@talk-to-me
```

Run 

```
/reload-plugins
```

then run (MUST RUN)
```
/talk-to-me:setup
``` 
to install dependencies and register hooks. **Note:** It will download piper and a voice model.

**`/talk-to-me:setup` is required** — it installs piper, downloads a voice model, and registers the Stop/UserPromptSubmit hooks in your settings. The plugin will not work without running setup first.

It would say out load "Just wrapped up all the code changes and everything looks good" after a successful setup 😁

### From a local clone

```sh
git clone https://github.com/IsuruDR/talk-to-me.git
```

In Claude Code:

```
/plugin marketplace add /path/to/talk-to-me
/plugin install talk-to-me@talk-to-me
```

Restart Claude Code, then run `/talk-to-me:setup` to install dependencies and register hooks.

## Commands

```
/talk-to-me:setup                    # Install dependencies and register hooks
/talk-to-me:on                       # Enable talk-to-me
/talk-to-me:off                      # Disable without uninstalling
/talk-to-me:duration 60              # Set minimum duration before speaking (seconds)
/talk-to-me:uninstall                # Remove hooks and clean up all data
```

### Config file

Settings are stored in `~/.config/talk-to-me/config.json`:

```json
{
  "enabled": true,
  "min_duration": 300
}
```

| Field | Description | Default |
|-------|------------|---------|
| `enabled` | Whether talk-to-me is active | `true` |
| `min_duration` | Minimum seconds before speaking | `300` (set `0` for always) |

All fields are optional. Omitted fields use sensible defaults.

## Updating

The `/plugin update` command may not detect new versions automatically. To update, reinstall:

```
/plugin uninstall talk-to-me
/plugin install talk-to-me@talk-to-me
/reload-plugins
```

Then re-run `/talk-to-me:setup` to re-register hooks.

## Uninstall

Fist run

```
/talk-to-me:uninstall
``` 

This removes hooks from settings, uninstalls piper, and cleans up all data. You might need to allow Claude Code to edit the settings files.

Then remove the plugin itself:

```
/plugin uninstall talk-to-me@talk-to-me
/plugin marketplace remove talk-to-me
```

## License

MIT

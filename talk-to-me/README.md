# talk-to-me

A Claude Code plugin that announces when subagents finish their tasks using local text-to-speech.

When you run parallel agents, it can be hard to notice when each one completes. This plugin uses a local LLM to summarize what the agent actually accomplished, then speaks it aloud in a casual tone — e.g., *"Done mapping out the HelloSign integration and all the API endpoints"*.

## How it works

```
Agent finishes → hook extracts agent output (first 2000 chars)
    → ollama summarizes it into one casual sentence
    → local TTS speaks the summary aloud
```

The plugin registers a `PostToolUse` hook on the `Task` tool. When a subagent completes, it:

1. Extracts the agent's actual output from `tool_response`
2. Sends it to a local ollama model for a one-sentence casual summary
3. Speaks the summary using your system's TTS engine

If ollama isn't running or no models are available, the plugin stays silent — no errors, no fallback noise.

## Quick start

After installing the plugin, run:

```
/talk-to-me:setup
```

This checks and installs all dependencies (jq, ollama, a model, TTS engine), then verifies the full pipeline works end-to-end. You'll hear a test announcement when it's done.

## Requirements

These are handled automatically by `/talk-to-me:setup`, but for reference:

- **ollama** — local LLM runtime ([install](https://ollama.com))
- **jq** — JSON parsing (`brew install jq` / `apt install jq`)
- A pulled ollama model (any small model works — `ollama pull qwen2.5:3b`)

## Platform support

| Platform | TTS engine | Install |
|----------|-----------|---------|
| macOS | `say` (built-in) | Nothing to install |
| Linux | `espeak` | `sudo apt install espeak` |
| Linux | `spd-say` (speech-dispatcher) | `sudo apt install speech-dispatcher` |
| Linux | `festival` | `sudo apt install festival` |

The plugin tries each engine in order and uses the first one available.

## Installation

### From GitHub (recommended)

In Claude Code, run:

```
/plugin marketplace add your-username/talk-to-me
```

Then install the plugin:

```
/plugin install talk-to-me@talk-to-me
```

Restart Claude Code, then run `/talk-to-me:setup` to install dependencies.

### From a local clone

```sh
git clone https://github.com/your-username/talk-to-me.git
```

In Claude Code:

```
/plugin marketplace add /path/to/talk-to-me
/plugin install talk-to-me@talk-to-me
```

Restart Claude Code, then run `/talk-to-me:setup` to install dependencies.

### From an existing marketplace

If this plugin is included in a marketplace you already use:

```
/plugin install talk-to-me@<marketplace-name>
```

Restart Claude Code, then run `/talk-to-me:setup` to install dependencies.

## Configuration

Use the `/talk-to-me:voice` command inside Claude Code to configure everything interactively.

```
/talk-to-me:voice              # Interactive setup — voice, rate, and model
/talk-to-me:voice list         # List available voices and models
/talk-to-me:voice preview Sam  # Preview a specific voice
/talk-to-me:voice set Daniel   # Set voice directly
/talk-to-me:voice model qwen2.5:1.5b  # Set the summarization model
/talk-to-me:voice reset        # Reset to system defaults
```

### Config file

Settings are stored in `~/.config/talk-to-me/config.json`:

```json
{
  "voice": "Samantha",
  "rate": null,
  "model": "qwen2.5:3b"
}
```

| Field | Description | Default |
|-------|------------|---------|
| `voice` | TTS voice name (platform-specific) | System default |
| `rate` | Speech rate (words per minute) | System default |
| `model` | Ollama model for summarization | Auto-detect smallest available |

All fields are optional. Omitted fields use sensible defaults.

## Recommended models

Any small ollama model works. The summarization task is trivial — a sentence from a few paragraphs. Smaller = faster announcements.

| Model | Size | Speed |
|-------|------|-------|
| `qwen2.5:0.5b` | ~400MB | Fastest |
| `qwen2.5:1.5b` | ~1GB | Fast |
| `llama3.2:1b` | ~700MB | Fast |
| `qwen2.5:3b` | ~2GB | Good balance |
| `llama3.2:3b` | ~2GB | Good balance |

## License

MIT

---
name: kwaainet-integration
description: Reference for integrating with the KwaaiNet binary. Covers CLI interface, API endpoints, daemon management, configuration, and known gotchas. Use when writing code that interacts with kwaainet.
---

# KwaaiNet Integration Reference

Tested against KwaaiNet v0.4.1. See also `docs/KWAAINET_INTEGRATION.md`.

## Two-Service Architecture

Fallow manages two KwaaiNet processes:
1. **P2P daemon** (`kwaainet start --daemon`): joins the distributed network via p2pd on port 8080
2. **API server** (`kwaainet serve --port 11435`): local OpenAI-compatible HTTP API

## CLI Interface

```bash
# Setup
kwaainet setup                    # First-time setup (creates ~/.kwaainet/config.yaml)

# P2P Daemon
kwaainet start --daemon           # Start background P2P node
kwaainet stop                     # Graceful shutdown
kwaainet status                   # Show running state, PID, uptime

# Local API
kwaainet serve --port 11435       # Start OpenAI-compatible API (blocks, long-running)
kwaainet serve --port 11435 llama3.1:8b  # Serve a specific model

# Configuration
kwaainet config                   # Show current config
kwaainet config set KEY VALUE     # Update config value

# Shard Management
kwaainet shard api --port 8080    # Distributed inference API (alternative to serve)
kwaainet shard run "prompt"       # Direct shard inference

# Other
kwaainet benchmark                # Measure local inference throughput
kwaainet update                   # Self-update (DISABLE inside Fallow bundle)
```

## Local API Endpoints (port 11435)

Once `kwaainet serve` is running:
- `http://localhost:11435/v1/models`: list available models
- `http://localhost:11435/v1/chat/completions`: chat completions (SSE streaming)

There is NO separate HTTP health endpoint. Use:
- `kwaainet status` CLI to check daemon health
- `GET /v1/models` to check API server health

## Configuration

Config stored at `~/.kwaainet/config.yaml`. Key fields:
- `model`: Model identifier (e.g., "unsloth/Llama-3.1-8B-Instruct")
- `blocks`: Number of model blocks to serve
- `port`: P2P node port (default 8080)
- `public_name`: Node display name on network map

## Integration Gotchas

1. **Self-update must be disabled.** `kwaainet update` would mutate the binary inside a signed app bundle, breaking code signing.

2. **Model loading takes time.** `kwaainet serve` loads the model into memory on startup (~12s for 8B params). Fallow waits up to 30 seconds.

3. **Local model required.** `kwaainet serve` needs a local model (Ollama or HuggingFace cache). If no model is found, serve fails.

4. **p2pd companion binary.** KwaaiNet requires `p2pd` alongside `kwaainet`. Both must be bundled and signed.

5. **Config persistence.** `~/.kwaainet/config.yaml` is created by `kwaainet setup`. Fallow checks for this file to detect first-run.

6. **Port layout.** Port 8080 is p2pd (P2P networking). Port 11435 is `kwaainet serve` (local API). These are separate processes.

7. **Graceful shutdown.** `kwaainet stop` takes ~5 seconds. The serve process is stopped via SIGTERM.

## Binary Bundle Structure

Inside Fallow.app:
```
Fallow.app/
  Contents/
    MacOS/
      Fallow              -- Main Swift app binary
    Helpers/
      kwaainet            -- KwaaiNet binary (re-signed with Developer ID)
      p2pd                -- p2p daemon (re-signed)
    Resources/
      ...
    Info.plist
```

Both `kwaainet` and `p2pd` must be signed with your Developer ID before the outer app is signed. Sign innermost first.

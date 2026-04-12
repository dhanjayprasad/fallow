# KwaaiNet Integration

This document describes how Fallow integrates with the [KwaaiNet](https://github.com/Kwaai-AI-Lab/KwaaiNet) binary (tested against v0.4.1). Written for contributors and the KwaaiNet team.

## Pinned Version

Fallow was developed and tested against **KwaaiNet v0.4.1**. Pin to a specific tested release. The binary is bundled inside the app and must not self-update (code signing would break).

## Architecture

Fallow manages TWO KwaaiNet services:

1. **P2P daemon** (`kwaainet start --daemon`): joins the distributed network, serves model shards to peers. Uses port 8080 (via p2pd).
2. **Local API server** (`kwaainet serve --port 11435`): serves an OpenAI-compatible HTTP API for the chat interface. Uses port 11435.

Both are started when the user clicks "Start Contributing" and stopped on "Stop Contributing" or app quit.

## Binary Location

In development, Fallow resolves `kwaainet` from the system PATH (DEBUG builds only). In release builds, the binary must be at:

```
Fallow.app/Contents/Helpers/kwaainet
Fallow.app/Contents/Helpers/p2pd
```

Both must be signed with the same Developer ID before the outer app is signed.

## CLI Interface

| Command | Purpose | Used By |
|---------|---------|---------|
| `kwaainet setup` | First-time config creation | KwaaiNetManager (auto-detected) |
| `kwaainet start --daemon` | Launch P2P background node | KwaaiNetManager.start() |
| `kwaainet stop` | Graceful daemon shutdown | KwaaiNetManager.stop() |
| `kwaainet status` | Show daemon running state | KwaaiNetManager.refreshStatus() |
| `kwaainet serve --port 11435` | Start local OpenAI API server | KwaaiNetManager.start() |

## HTTP API

Once `kwaainet serve` is running:

**Model discovery**:
```
GET http://localhost:11435/v1/models
Response: { "data": [{ "id": "llama3.1:8b", "object": "model", "owned_by": "kwaai" }] }
```

**Chat completions** (SSE streaming):
```
POST http://localhost:11435/v1/chat/completions
Content-Type: application/json
X-Fallow-Token: <session-token>

{
  "model": "llama3.1:8b",
  "messages": [{"role": "user", "content": "..."}],
  "stream": true
}
```

SSE frames follow the OpenAI format: `data: {"choices":[{"delta":{"content":"token"}}]}` terminated by `data: [DONE]`.

## Authentication

Fallow generates a random 32-byte hex token on each daemon start and passes it to kwaainet as the `FALLOW_AUTH_TOKEN` environment variable. All HTTP requests from Fallow include this token in the `X-Fallow-Token` header.

KwaaiNet does not currently validate this token server-side. The plumbing is in place for when KwaaiNet adds token validation.

## First-Run Setup

Before starting, Fallow checks for `~/.kwaainet/config.yaml`. If the file does not exist, Fallow runs `kwaainet setup` automatically and shows progress in the menu bar popover. Setup creates the config file and default settings.

## Binary Verification

In Release builds, Fallow verifies the kwaainet binary's code signature using `SecStaticCodeCheckValidity` before launching. Debug builds skip this check.

## Known Gotchas

1. **Self-update must be disabled.** `kwaainet update` would mutate the binary inside a signed app bundle.

2. **Model loading takes time.** `kwaainet serve` loads the model into memory on startup. For an 8B parameter model, this takes ~12 seconds. Fallow waits up to 30 seconds.

3. **p2pd companion binary.** KwaaiNet requires `p2pd` alongside `kwaainet`. Both must be bundled and signed.

4. **Config persistence.** KwaaiNet stores config at `~/.kwaainet/config.yaml`. This must survive across app updates.

5. **Port layout.** Port 8080 is used by p2pd for P2P networking. Port 11435 is used by `kwaainet serve` for the local API. These are different from the port numbers in KwaaiNet's own documentation for `shard api`.

6. **Graceful shutdown.** `kwaainet stop` takes ~5 seconds to drain P2P connections. The serve process is terminated directly via SIGTERM.

7. **Local models.** `kwaainet serve` requires a local model (e.g., Ollama's `llama3.1:8b`). If no model is available, serve fails with "Model not found in local cache."

## What Fallow Does NOT Do

- Fallow does not modify KwaaiNet configuration files
- Fallow does not call `kwaainet update`
- Fallow does not manage model downloads (requires Ollama or manual setup)
- Fallow does not expose KwaaiNet's network ports to the internet
- Fallow does not claim to verify inference output correctness

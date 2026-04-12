# KwaaiNet Integration

This document describes how Fallow integrates with the [KwaaiNet](https://github.com/Kwaai-AI-Lab/KwaaiNet) binary. It is written for contributors and for the KwaaiNet team to review.

## Pinned Version

Fallow pins to a specific tested KwaaiNet release. The binary is bundled inside the app and must not self-update (code signing would break). Check the [KwaaiNet releases page](https://github.com/Kwaai-AI-Lab/KwaaiNet/releases) for the current stable version.

## Binary Location

In development, Fallow resolves `kwaainet` from the system PATH (DEBUG builds only). In release builds, the binary must be at:

```
Fallow.app/Contents/Helpers/kwaainet
Fallow.app/Contents/Helpers/p2pd
```

Both must be signed with the same Developer ID before the outer app is signed. Sign innermost first.

## CLI Interface

Fallow uses these CLI commands:

| Command | Purpose | Used By |
|---------|---------|---------|
| `kwaainet start --daemon` | Launch background node | KwaaiNetManager.start() |
| `kwaainet stop` | Graceful shutdown | KwaaiNetManager.stop() |
| `kwaainet setup` | First-time identity and model setup | Not yet automated |
| `kwaainet status` | Show running state | Reserved for future use |

## HTTP API

Once the daemon is running, Fallow communicates via HTTP:

**Health check** (5-second timeout):
```
GET http://localhost:8080/health
200 OK = daemon is running
```

**Model discovery**:
```
GET http://localhost:8000/v1/models
Response: { "data": [{ "id": "model-name", ... }] }
```

**Chat completions** (SSE streaming):
```
POST http://localhost:8000/v1/chat/completions
Content-Type: application/json

{
  "model": "<discovered model id>",
  "messages": [{"role": "user", "content": "..."}],
  "stream": true
}
```

SSE frames follow the OpenAI format: `data: {"choices":[{"delta":{"content":"token"}}]}` terminated by `data: [DONE]`.

## Authentication

Fallow generates a random 32-byte hex token on each daemon start and passes it to kwaainet as the `FALLOW_AUTH_TOKEN` environment variable. All HTTP requests from Fallow include this token in the `X-Fallow-Token` header.

KwaaiNet does not currently validate this token server-side. The plumbing is in place for when KwaaiNet adds token validation. The token prevents casual API abuse by other processes on the same machine.

## First-Run Setup

Before starting the daemon, Fallow checks for `~/.kwaainet/identity.key`. If the file does not exist, Fallow runs `kwaainet setup` automatically and shows progress in the menu bar popover. This creates the identity keypair and downloads dependencies.

## Binary Verification

In Release builds, Fallow verifies the kwaainet binary's code signature using `SecStaticCodeCheckValidity` before launching it. If the signature is missing or invalid, the binary is not executed. Debug builds skip this check (development binaries are typically unsigned).

## Known Gotchas

1. **Self-update must be disabled.** `kwaainet update` would mutate the binary inside a signed app bundle. Fallow manages updates by shipping new DMGs with updated binaries.

2. **First-run model download.** `kwaainet setup` and the first `start` download model weights (potentially several GB). Fallow waits up to 30 seconds for the health endpoint during startup, but model download may take longer. Future versions should surface download progress.

3. **p2pd companion binary.** KwaaiNet requires `p2pd` alongside `kwaainet`. Both must be bundled and signed. `kwaainet setup --get-deps` downloads it, but inside a bundle it must be pre-included.

4. **Identity persistence.** KwaaiNet generates `~/.kwaainet/identity.key` (Ed25519 keypair) on first setup. This must survive across app updates. Do not delete `~/.kwaainet/`.

5. **Port conflicts.** Ports 8080 (node) and 8000 (API) are hardcoded. If another service uses these ports, KwaaiNet will fail to start. Future versions should detect conflicts and support configurable ports.

6. **Graceful shutdown timing.** `kwaainet stop` may take several seconds to drain connections. Fallow gives it 5 seconds during app termination before logging a warning.

## What Fallow Does NOT Do

- Fallow does not modify KwaaiNet configuration files
- Fallow does not call `kwaainet update` (breaks code signing)
- Fallow does not manage model downloads (deferred to v0.2)
- Fallow does not expose KwaaiNet's network ports to the internet
- Fallow does not claim to verify inference output correctness

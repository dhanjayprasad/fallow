---
name: kwaainet-integration
description: Reference for integrating with the KwaaiNet binary. Covers CLI interface, API endpoints, daemon management, configuration, and known gotchas. Use when writing code that interacts with kwaainet.
---

# KwaaiNet Integration Reference

## Pinned Version

Pin to a specific tested release. Do not auto-track latest. Check https://github.com/Kwaai-AI-Lab/KwaaiNet/releases for the current stable version.

## CLI Interface

```bash
# Lifecycle
kwaainet setup                    # First-time setup (creates identity, downloads deps)
kwaainet setup --get-deps         # Download p2pd if missing
kwaainet benchmark                # Measure local inference throughput
kwaainet start --daemon           # Start background node
kwaainet stop                     # Graceful shutdown
kwaainet status                   # Show running state, connections, model info
kwaainet config                   # Show current config
kwaainet config set KEY VALUE     # Update config value

# Inference API
kwaainet serve                    # Start OpenAI-compatible API server

# Shard management
kwaainet shard serve              # Serve model shards
kwaainet shard status             # Show shard serving status
kwaainet shard download           # Download model shards

# Other
kwaainet update                   # Self-update (DISABLE inside Fallow bundle)
kwaainet uninstall                # Full removal
```

## Local API Endpoints

Once running, KwaaiNet exposes:
- `http://localhost:8080/health` -- Node health check
- `http://localhost:8000/v1/models` -- List available models
- `http://localhost:8000/v1/chat/completions` -- Chat completions (SSE streaming supported)
- `http://localhost:8000/v1/completions` -- Text completions

## Configuration

Config stored at `~/.kwaainet/config.yaml`. Key fields:
- `model`: Model identifier (e.g., "unsloth/Llama-3.1-8B-Instruct")
- `blocks`: Number of model blocks to serve
- `port`: Node port (default 8080)
- `public_name`: Node display name on network map

## Integration Gotchas

1. **Self-update must be disabled.** KwaaiNet has `kwaainet update` which would mutate the binary inside a signed app bundle, breaking code signing. Fallow must manage updates by shipping new DMGs with updated binaries.

2. **Model download on first run.** `kwaainet setup` and first `kwaainet start` will download model weights (potentially several GB). This takes minutes on fast connections. Fallow must show progress/status during this phase, not just a spinning indicator.

3. **p2pd companion binary.** KwaaiNet requires a `p2pd` binary alongside `kwaainet`. Both must be bundled and signed. `kwaainet setup --get-deps` downloads it, but inside a bundle, it must be pre-included.

4. **Identity persistence.** KwaaiNet generates `~/.kwaainet/identity.key` (Ed25519 keypair) on first setup. This must persist across app updates. Do not delete `~/.kwaainet/` during updates.

5. **Port conflicts.** Default ports 8080 (node) and 8000 (API) may conflict with other services. Fallow should check port availability before starting and potentially configure alternative ports.

6. **Status output format.** `kwaainet status` output may change between versions. Parse defensively. Prefer querying the local HTTP API over parsing CLI output where possible.

7. **Graceful shutdown timing.** `kwaainet stop` may take several seconds to drain connections and save state. Do not force-kill immediately. Wait for process exit, with a timeout fallback.

## Binary Bundle Structure

Inside Fallow.app:
```
Fallow.app/
  Contents/
    MacOS/
      Fallow              -- Main Swift app binary
    Helpers/
      kwaainet            -- KwaaiNet binary (re-signed with Fallow's Developer ID)
      p2pd                -- p2p daemon (re-signed)
    Resources/
      ...
    Info.plist
```

Both `kwaainet` and `p2pd` must be signed with your Developer ID before the outer app is signed. Sign innermost first, then outer.

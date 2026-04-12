---
name: debug-kwaainet
description: Troubleshoot KwaaiNet integration issues. Use when kwaainet fails to start, health checks fail, or the chat API is not responding.
---

# Debug KwaaiNet Skill

Systematic troubleshooting for KwaaiNet integration problems. Tested against v0.4.1.

## Step 1: Is kwaainet installed?

```bash
which kwaainet
kwaainet --version
```

If not found, install it:
```bash
curl --proto '=https' --tlsv1.2 -LsSf https://github.com/Kwaai-AI-Lab/KwaaiNet/releases/latest/download/kwaainet-installer.sh | sh
kwaainet setup
```

## Step 2: Has setup been run?

```bash
ls ~/.kwaainet/config.yaml
```

If missing, run `kwaainet setup`. Fallow auto-detects this and runs setup on first launch.

## Step 3: Can the P2P daemon start?

```bash
kwaainet start --daemon
echo "Exit code: $?"
kwaainet status
```

Expected: status shows "Running" with a PID. The daemon uses port 8080 via p2pd.

Common failures:
- **"port already in use"**: Another service on port 8080. Check with `lsof -i :8080`.
- **"already running"**: Daemon is already up. Check with `kwaainet status`.

## Step 4: Can the local API server start?

```bash
kwaainet serve --port 11435 llama3.1:8b &
sleep 15  # Model loading takes ~12s
curl -s http://localhost:11435/v1/models
```

Expected: JSON with `data` array containing model objects.

Common failures:
- **"Model not found in local cache"**: The model must be available locally (e.g., via Ollama). Install it: `ollama pull llama3.1:8b`
- **Port 11435 in use**: Check with `lsof -i :11435`.

## Step 5: Can chat completions work?

```bash
curl -s http://localhost:11435/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"llama3.1:8b","messages":[{"role":"user","content":"hello"}],"stream":false}'
```

Expected: JSON response with `choices[0].message.content`.

## Step 6: Check Fallow's binary resolution

In the Fallow source, `KwaaiNetManager.binaryPath` resolves the binary:
1. First checks `Bundle.main.url(forAuxiliaryExecutable: "kwaainet")`
2. In DEBUG builds only, falls back to `ProcessRunner.findInPath("kwaainet")`

If running from SPM or Xcode without bundled binary, make sure kwaainet is in your PATH.

## Step 7: Check system state

```bash
# Power source
pmset -g batt

# Thermal state
# Check in System Information > Hardware

# Idle time (ResourceGovernor requires idle > threshold)
ioreg -c IOHIDSystem | grep HIDIdleTime
```

## Common Issues

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| "kwaainet not found" | Not in PATH or bundle | Install kwaainet or check PATH |
| "Model not found" | No local model available | `ollama pull llama3.1:8b` |
| API returns nothing | Model still loading (~12s) | Wait longer; check logs |
| Daemon starts but no API | `kwaainet serve` not started | Fallow starts both; check logs |
| Governor blocks contribution | System not idle, on battery, or thermal | Check SettingsView conditions |
| Credits not accruing | Onboarding not completed | Complete the consent flow first |
| Port conflict on 8080 | Another service using p2pd port | Stop conflicting service |
| Port conflict on 11435 | Another kwaainet serve instance | `kill` the old process |

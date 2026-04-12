---
name: debug-kwaainet
description: Troubleshoot KwaaiNet integration issues. Use when kwaainet fails to start, health checks fail, or the chat API is not responding.
---

# Debug KwaaiNet Skill

Systematic troubleshooting for KwaaiNet integration problems.

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

## Step 2: Can the daemon start?

```bash
kwaainet start --daemon
echo "Exit code: $?"
```

Common failures:
- **"port already in use"**: Another service on port 8080 or 8000. Check with `lsof -i :8080` and `lsof -i :8000`.
- **"identity not found"**: Run `kwaainet setup` first.
- **"model not found"**: First run needs to download model weights. This can take minutes. Watch logs.

## Step 3: Is the health endpoint responding?

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health
```

Expected: `200`. If no response, the daemon is not running or is still starting.

## Step 4: Is the API endpoint responding?

```bash
curl -s http://localhost:8000/v1/models | python3 -m json.tool
```

Expected: JSON with `data` array containing model objects. The `id` field is what Fallow sends in chat requests.

## Step 5: Can chat completions work?

```bash
curl -s http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"default","messages":[{"role":"user","content":"hello"}],"stream":false}'
```

Expected: JSON response with `choices[0].message.content`.

## Step 6: Check Fallow's binary resolution

In the Fallow source, `KwaaiNetManager.binaryPath` resolves the binary:
1. First checks `Bundle.main.url(forAuxiliaryExecutable: "kwaainet")`
2. In DEBUG builds only, falls back to `ProcessRunner.findInPath("kwaainet")`

If running from Xcode, the bundle path won't have kwaainet. Make sure kwaainet is in your PATH for development.

## Step 7: Check system state

```bash
# Power source
pmset -g batt

# Thermal state (if high, ResourceGovernor may block contribution)
# Check in System Information > Hardware > Thermal

# Idle time (ResourceGovernor requires idle > threshold)
ioreg -c IOHIDSystem | grep HIDIdleTime
```

## Common Issues

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| "kwaainet not found" | Not in PATH or bundle | Install kwaainet or check PATH |
| Health check times out | Daemon still starting | Wait longer; first run downloads models |
| Chat returns 404 | API server not started | Check if port 8000 is listening |
| Governor blocks contribution | System not idle, on battery, or thermal | Check SettingsView conditions |
| Credits not accruing | Onboarding not completed | Complete the consent flow first |

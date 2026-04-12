# Claude Code Workflow for Fallow

## Setup

1. Open the `fallow/` directory in Claude Code:
   ```bash
   cd fallow
   claude
   ```

2. Claude Code will automatically load:
   - `CLAUDE.md` (project context and rules)
   - All agents from `.claude/agents/`
   - All skills from `.claude/skills/`

3. Verify agents are loaded:
   ```
   /agents
   ```
   You should see: architect, product-critic, security-reviewer, swift-expert

## Daily Workflow

### Starting the Weekend Prototype

```
/weekend-prototype
```

This walks you through the minimal proof-of-concept build.

### Writing New Code

Write your Swift code normally. When you want a review:

```
@swift-expert Review the KwaaiNetManager implementation I just wrote
```

### Making Design Decisions

When you are unsure about an approach:

```
@architect Should I use Process or NSTask to manage the kwaainet subprocess? Here are the trade-offs I see: [explain]
```

### Running a Full Review Cycle

Before shipping or before a major decision:

```
/architecture-review
```

This guides you through invoking each agent in sequence.

### Quick Product Check

When you are adding a feature and want to gut-check whether it belongs in v0.1:

```
@product-critic I want to add [feature]. Is this necessary for the first 10 users?
```

### Security Audit

When touching process management, networking, or code signing:

```
@security-reviewer I am bundling the kwaainet binary inside the app bundle at Contents/Helpers/. Review the security implications.
```

## Tips

### Keep Agents Honest

Agents are configured to be critical, not encouraging. If an agent says "looks good," something is wrong. Push back:

```
@architect You said the approach looks fine. What is the riskiest assumption you are making?
```

### Use the KwaaiNet Integration Skill as Reference

When writing code that touches KwaaiNet:

```
/kwaainet-integration
```

This loads the full integration reference (CLI commands, API endpoints, gotchas, bundle structure).

### Iterate Fast

The weekend prototype skill is designed for speed. Do not optimise, refactor, or beautify during the prototype phase. Get it working first. Make it good later.

### Document Decisions

When you reject agent feedback, document why in a comment or in the relevant source file. Future you will want to know why you made that choice.

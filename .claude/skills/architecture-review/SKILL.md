---
name: architecture-review
description: Run a multi-agent architecture review cycle. Invokes architect, product-critic, and security-reviewer agents in sequence against a plan or implementation. Use when making significant design decisions or before shipping a milestone.
---

# Architecture Review Cycle

Run this when you need a thorough review of a design decision, feature plan, or code change.

## Process

1. **Write the proposal.** Document what you plan to build, why, and how. Be specific about the implementation approach.

2. **Invoke the architect agent.** Ask it to review the proposal for structural risks, dependency concerns, and scope creep.
   ```
   @architect Review this proposal: [paste or reference the document]
   ```

3. **Address architect feedback.** Update the proposal based on valid concerns. Note any feedback you deliberately chose to reject and why.

4. **Invoke the product-critic agent.** Ask it to evaluate the updated proposal from a user perspective.
   ```
   @product-critic Evaluate this feature plan from a user's perspective: [paste or reference]
   ```

5. **Invoke the security-reviewer agent.** Ask it to audit the trust and security implications.
   ```
   @security-reviewer Audit the security implications of this plan: [paste or reference]
   ```

6. **Synthesise.** Collect all feedback, categorise as: must-fix, should-fix, noted-for-later. Update the plan.

7. **If building Swift code, invoke swift-expert** for implementation review.
   ```
   @swift-expert Review this implementation: [paste or reference code]
   ```

## When to Run This

- Before starting a new component
- Before changing the KwaaiNet integration boundary
- Before adding any new dependency
- Before the v0.1 launch
- When you are unsure whether something belongs in v0.1 or should be deferred

## Anti-Patterns

- Do NOT run this on trivial changes (renaming a variable, fixing a typo).
- Do NOT ignore agent feedback without documenting why.
- Do NOT let review cycles delay shipping. Time-box each cycle to 30 minutes. If consensus is not reached, go with the simplest option.

---
name: adr-records
description: "Use when writing or organising Architecture Decision Records — deciding what warrants an ADR, Nygard and MADR templates, documenting context/options/consequences, statuses (proposed, accepted, superseded), numbering, and review flow."
license: MIT
---

# Architecture Decision Records

An ADR is a short document capturing one significant decision, its
context, and its consequences. Its value shows up a year later when
someone asks "why did we do it this way?"

## When to Use This Skill
- Choosing a database, framework, protocol, or hosting model
- Decisions that are expensive to reverse or affect many teams
- Settling a recurring debate so it stays settled

## Where they live
```
docs/adr/
  0001-record-architecture-decisions.md
  0002-use-postgres-for-primary-storage.md
  0003-adopt-event-driven-order-pipeline.md
```
Number sequentially; never renumber. Tools like `adr-tools` or `log4brains` are optional.

## Template (MADR-style)
```markdown
# 0004. Use server-side sessions instead of JWTs

- Status: accepted
- Date: 2026-03-14
- Deciders: platform team

## Context
What problem forces a decision now? Constraints, requirements, facts.

## Options considered
1. Server-side sessions in Redis
2. Stateless JWT access + refresh tokens
3. Managed auth provider sessions

## Decision
We will use option 1 because …

## Consequences
- Positive: instant revocation, smaller cookies
- Negative: Redis becomes a dependency for every request
- Follow-ups: add session store monitoring
```

## Lifecycle
- **Proposed** → reviewed via pull request like code.
- **Accepted** → merged; the decision is now the default.
- **Superseded by 00NN** → never delete or rewrite an accepted ADR; write a new one and link both ways.
- **Deprecated** → no longer relevant, kept for history.

## Writing rules
- One decision per ADR; one to two pages.
- Write the context so a newcomer understands the forces at play.
- List real alternatives and why they lost — that's the most valuable part.
- Be honest about negative consequences.
- Link to benchmarks, spikes, or RFCs that informed the decision.

## Avoid
- ADRs for trivial or easily reversible choices
- Writing ADRs after the fact with invented reasoning
- Editing accepted ADRs to match a new reality

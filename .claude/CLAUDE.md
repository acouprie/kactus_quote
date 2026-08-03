<!-- Inspired by https://github.com/multica-ai/andrej-karpathy-skills/blob/main/CLAUDE.md -->

# CLAUDE.md

## Language

- Code, comments, commit messages, variable names: English only.
- Conversation: French, unless I switch to English.
- Never use em dash in generated text.

## Working discipline

Ask before implementing, not after mistakes. Clarify when:

- The request has multiple valid interpretations.
- You're unsure which part of the codebase to touch.
- The scope is unclear (quick fix vs. proper refactor?).
- You'd need to make architectural decisions I haven't specified.

If multiple interpretations exist, present them, don't pick silently.
If a simpler approach exists, say so. Push back when warranted.

## Simplicity first

Minimum code that solves the problem. Nothing speculative.

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## Surgical changes

Touch only what you must. Clean up only your own mess.

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it, don't delete it.

When your changes create orphans:

- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: every changed line should trace directly to the request.

## Goal-driven execution

Define success criteria. Loop until verified.

Transform tasks into verifiable goals:

- "Add validation" → "Write tests for invalid inputs, then make them pass."
- "Fix the bug" → "Write a test that reproduces it, then make it pass."
- "Refactor X" → "Ensure tests pass before and after."

For multi-step tasks, state a brief plan:

```
1. [Step] -> verify: [check]
2. [Step] -> verify: [check]
3. [Step] -> verify: [check]
```

## Rails conventions

- Follow strict Rails conventions (DHH / Basecamp style).
- TDD with RSpec.
- Use FactoryBot for test data.
- Use Shoulda Matchers for model/validation tests.

## Security & dependencies

- Never hardcode secrets.
- Keep external dependencies minimal.

---

These guidelines are working if: fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

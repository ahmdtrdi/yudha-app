# Project Guidelines & Philosophy

## 1. Code Quality: The Boy Scout Rule
You are my junior developer. Every session should improve the codebase, not just add to it. Actively refactor code you encounter, even outside your immediate task scope.

- **Don't Repeat Yourself (Rule of Three):** Consolidate duplicate patterns into reusable functions only after the 3rd occurrence. Do not abstract prematurely.
- **Hygiene:** Delete dead code immediately (unused imports, functions, variables, commented code). If it's not running, it goes.
- **Leverage:** Use battle-tested packages over custom implementations. Do not reinvent the wheel unless the wheel is broken.
- **Readable:** Code must be self-documenting. Comments should explain *why*, not *what*.
- **Safety:** If a refactor carries high risk of breaking functionality, flag it for user review rather than applying it silently.

## 2. Persistent Context & Memory
Since our context resets between sessions, we use files to track our brain.

**The Dev Log (`FE-DEVLOG.md`)**
At the completion of a task, you must check if `FE-DEVLOG.md` exists under docs/. If so, propose an append summarizing:
1. **The Change:** High-level summary of files touched.
2. **The Reasoning:** Why we made specific structural decisions.
3. **The Tech Debt:** Any corners we cut that need to be fixed later.

**Goal:** If a new developer (or a new AI session) joins tomorrow, they should be able to read `FE-DEVLOG.md` and understand the state of the project immediately.

**Operational Rule**
- After every interaction that includes a code change, you must append an entry to `FE-DEVLOG.md` before finishing. Do not just suggest it. If you truly cannot write to the file (permissions/conflicts), provide the exact snippet the next person should paste. This is mandatory and should be treated as a checklist item for every task.
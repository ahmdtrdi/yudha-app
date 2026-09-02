# Project Guidelines & Philosophy

## 1. Code Quality: The Boy Scout Rule
You are a persistent developer. Every session should improve the codebase, not just add to it. Actively refactor code you encounter, even outside your immediate task scope.

- **Don't Repeat Yourself (Rule of Three):** Consolidate duplicate patterns into reusable functions only after the 3rd occurrence. Do not abstract prematurely.
- **Hygiene:** Delete dead code immediately (unused imports, functions, variables, commented code). If it's not running, it goes. Pay attention to canonical. 
- **Leverage:** Use battle-tested packages over custom implementations. Do not reinvent the wheel unless the wheel is broken.
- **Readable:** Code must be self-documenting. Comments should explain *why*, not *what*. No need to put every change in comments, the DEVLOG will do the explanation.
- **Safety:** If a refactor carries high risk of breaking functionality, flag it for user review rather than applying it silently.
- **Patch, Don't Replace:** Treat existing files as the source of truth and only patch them incrementally, so the work stays intact while we iterate.

## 2. Persistent Context & Memory
Since our context resets between sessions, we use files to track our brain.

**The Dev Log (`docs/devlog/*.md`)**
At the completion of a task, you must ask what my role is and check if the corresponding role log exists under `docs/devlog/` (example: `docs/devlog/FE-DEVLOG.md` for frontend). If not, create one. If so, propose an append summarizing:
1. **The Change:** High-level summary of files touched.
2. **The Reasoning:** Why we made specific structural decisions.
3. **The Tech Debt:** Any corners we cut that need to be fixed later.

**Goal:** If a new developer (or a new AI session) joins tomorrow, they should be able to read `docs/*-DEVLOG.md` and understand the state of the project immediately.

**Operational Rule**
- After every interaction that includes a code change, you must append an entry to the corresponding file in `docs/devlog/` before finishing. Do not just suggest it. If you truly cannot write to the file (permissions/conflicts), provide the exact snippet the next person should paste. This is mandatory and should be treated as a checklist item for every task.

## 3. Reusable Skills & SOPs (`docs/skill/*.md`)
When dealing with recurring, standard, or mission-critical workflows, check `docs/skill/` first before re-inventing execution steps.

- **Check Existing Skills**: Before executing repetitive operational tasks (e.g. deployment, question taxonomy classification, content seeding, database migrations), inspect `docs/skill/` for approved quick guides and execution rules:
  - `docs/skill/deploy_web.md`: Panduan deploy Flutter Web ke Vercel via CLI/Dashboard.
  - `docs/skill/question_taxonomy.md`: Panduan taksonomi dan kategorisasi bank soal (CPNS & BUMN).
  - `docs/skill/content_pipeline.md`: Panduan validasi, sinkronisasi, dan seeding bank soal.
  - `docs/skill/supabase_ops.md`: Panduan pengelolaan schema, migrasi, dan postchecks database.
- **Document New Skills Proactively**: If you identify a workflow, pattern, or troubleshooting guide that is likely to be executed repeatedly in future AI/developer sessions, create or update the appropriate markdown file in `docs/skill/`. Keep instructions crisp, actionable, and ready for immediate AI execution.


# YUDHA Learning System V2 — Adopted Design Record

> **Status:** Adopted into [`PRD.md`](PRD.md) on 2026-08-31; retained as a historical design record<br>
> **Record version:** 1.0<br>
> **Last updated:** 2026-08-31<br>
> **Product timezone:** Asia/Jakarta (WIB, UTC+7)<br>
> **Normative language:** English<br>
> **User-facing language:** Indonesian<br>
> **Audience:** Product, Mobile, Web, App Backend, Game Backend, Data, Content/SME, QA, DevOps, and Security

## Document authority

This document records the design proposal that Product approved and ingested into Section 11 of [`PRD.md`](PRD.md). It remains available for provenance and review history, but it is no longer an independent specification.

- [`PRD.md`](PRD.md) is the sole authoritative YUDHA product and architecture contract. If this record differs from the PRD, the PRD wins.
- This record must not be used to override current production behavior, release gates, public contracts, or product boundaries by itself.
- This record superseded the four workspace-local source notes named in the Source Reconciliation section during consolidation; the adopted PRD now carries the authoritative reconciled decisions.
- The source notes are historical inputs, not additional specifications.
- A statement using **must** or **shall** records the requirement adopted into the PRD, subject to its delivery gates and explicit decision debt.
- Exact formulas and thresholds labeled **Proposed learning-v1 policy** are runnable initial policies, but they are not scientifically validated and require versioning and later calibration.
- A statement labeled **Decision debt** is intentionally unresolved. Engineers must not invent, hardcode, or silently select an answer.
- A statement labeled **Current compatibility** describes behavior that remains available during migration but is not the V2 end state.

The authoritative adopted text and current delivery status are in [PRD.md](PRD.md).

---

## 1. Product outcome

YUDHA Learning System V2 turns authoritative learner activity into a transparent, repeatable learning loop:

    Solo, PvP, and Assessment evidence
                    ↓
          validate and classify
                    ↓
       immutable learning attempts
                    ↓
     learner state per user and skill
                    ↓
        one next-best Solo action
                    ↓
    mobile learning dashboard and feedback
                    ↓
          learner completes Solo
                    └──────────────→ repeat

The central product rule is:

> Analytics determines the learner's current state. Recommendation chooses the next Solo learning action. Solo delivers practice. Assessment validates progress independently. PvP remains a separate competition context.

V2 must help the learner answer:

1. What have I covered?
2. What am I improving?
3. What needs attention?
4. What should I do next?
5. Has my progress been independently validated?

V2 must not:

- collapse Solo, PvP, and Assessment into one unexplained score;
- present engagement, rank, or repeated-question success as mastery;
- claim an official exam outcome, hiring outcome, psychological diagnosis, or certification;
- treat one short session as proof of mastery;
- use an LLM to calculate learner state, choose access, or control progression;
- overwrite raw attempts when a formula changes; or
- hardcode five questions as a permanent V2 domain invariant.

### 1.1 In scope

- Stable skill-level taxonomy contracts.
- Authoritative question metadata and content versioning.
- Solo mechanics: Focus, Standard, and Speed.
- Solo question selection: Balanced, Recommended, and Custom.
- Immutable evidence from Solo, PvP, and future web Assessment.
- Versioned evidence classification, learner state, and recommendations.
- One primary Solo recommendation with an evidence-based explanation.
- Mobile learning and after-session dashboards.
- Mobile display of Assessment results produced on the web.
- Separate Competition analytics.
- An internal admin web dashboard for question-quality review.
- Additive migration from current Practice and Analytics contracts.

### 1.2 Outside the adopted contract or intentionally deferred

- Detailed web Assessment UX, session delivery, and public Assessment APIs.
- The final CPNS/BUMN skill catalog; it remains an SME-owned versioned artifact.
- A final V2 Solo session length or stopping rule.
- Automated machine-learning recommendations, IRT, Elo-style ability estimation, or population benchmarking.
- Automatic question deactivation.
- Shipping behavior outside the approved delivery gates or silently resolving registered decision debt.

---

## 2. Current-to-target change matrix

| Area | Current implementation / approved MVP | Approved V2 target |
|---|---|---|
| Domain name | Practice | Solo in all new public and logical contracts; Practice remains a compatibility alias |
| Topic grain | Target, category, optional subcategory | Target and stable skill ID, with category/subcategory retained for navigation |
| Session choice | Category and subcategory | Independent mechanic and question-selection choices |
| Mechanics | One untimed Practice flow | Focus, Standard, and Speed |
| Question selection | Server-selected category pool | Balanced, Recommended, and Custom |
| Session length | Exactly five questions | Versioned delivery policy; final policy remains decision debt |
| Hints | Hint content is delivered with the question and client reports use | Hint content is returned only by a server-tracked hint endpoint |
| Timer | No automatic Solo timeout | Focus has no deadline; Standard and effective Speed use server-authoritative deadlines |
| Response time | Client response time is accepted | Server elapsed time is authoritative for timed modes; validated client active time supports Focus |
| Accuracy | Broad answer accuracy | Activity, assisted, independent, and unseen-independent accuracy are separate |
| Pace | Average response time | Median valid effective time and comparable pace ratios |
| Evidence lanes | Practice and Ranked answers may be combined for recommendation | Solo, PvP, and Assessment remain separate evidence lanes |
| Learner state | Weak category/subcategory | Versioned learner state per user × target × skill |
| Recommendation | Practice or Interview based on a 90-day rule list | One Solo learning action selected through ordered objective gates |
| Recommendation evaluation | Not tracked end to end | Shown, accepted, dismissed, started, completed, immediate result, and delayed result |
| Assessment | No learning Assessment activity | Future web evidence source; mobile displays available results only |
| Data foundation | Source operational rows | Append-only canonical learning-attempt ledger plus derived projections |
| Learner dashboard | Aggregate Practice and battle statistics | Coverage, skill state, evidence, pace, retention, Assessment result, activity, and separate Competition |
| Content quality | No complete review workflow | Admin web metrics, triage, resolution, and controlled deactivation |

**Current compatibility:** The existing five-question Practice flow, /practice routes, /analytics route, Practice physical tables, current daily mission keys, and current PvP socket events continue until their consumers pass the migration gates in Section 20.

---

## 3. Canonical terminology and types

### 3.1 Product terminology

| Term | Meaning |
|---|---|
| **Solo** | The non-PvP learning activity. It is the V2 replacement term for Practice. |
| **Mechanic** | How the learner experiences a Solo question: Focus, Standard, or Speed. |
| **Question selection** | Which content is selected: Balanced, Recommended, or Custom. |
| **Delivery policy** | How long a Solo session continues and why it ends. Its V2 default is unresolved. |
| **Skill** | The lowest stable, SME-approved curriculum unit that can support reliable evidence and recommendation. |
| **Attempt** | One immutable record of an answered or timed-out learning question. |
| **Independent evidence** | Valid first-attempt evidence without a requested hint. |
| **Unseen evidence** | Evidence from a question the learner had not previously encountered. |
| **Assessment** | A future web-based standardized validation activity using held-out or unseen content. |
| **Competition** | PvP rank, match, and performance information, kept separate from the learning dashboard. |
| **Learner state** | Versioned derived Solo status for one user and skill. |
| **Assessment validation** | A separate indication of whether Assessment evidence validates progress. |

### 3.2 Approved public enums

    type MechanicMode =
      | "focus"
      | "standard"
      | "speed";

    type QuestionSelectionType =
      | "balanced"
      | "recommended"
      | "custom";

    type LearningObjective =
      | "repair_accuracy"
      | "spaced_review"
      | "collect_evidence"
      | "build_fluency"
      | "maintain_coverage";

    type LearningSource =
      | "solo"
      | "pvp"
      | "assessment";

    type EvidenceConfidence =
      | "low"
      | "medium"
      | "high";

    type SoloSkillStatus =
      | "collecting_data"
      | "needs_repair"
      | "developing"
      | "needs_review"
      | "needs_fluency"
      | "secure";

    type AssessmentValidationStatus =
      | "not_available"
      | "insufficient_evidence"
      | "baseline_recorded"
      | "validated"
      | "needs_revalidation";

    type CompletionReason =
      | "policy_completed"
      | "user_stopped"
      | "question_inventory_exhausted"
      | "abandoned";

    type PolicyStopTrigger =
      | "fixed_count_reached"
      | "fixed_duration_reached"
      | "mastery_evidence_reached"
      | "adaptive_condition_reached"
      | "user_continue_ended";

The following delivery-policy values are reserved contract vocabulary, not enabled V2 policies:

    type StoppingRule =
      | "fixed_count"
      | "fixed_duration"
      | "mastery_evidence"
      | "adaptive"
      | "user_continues";

### 3.3 Compatibility naming

All new V2 documentation, endpoints, payloads, logical entities, analytics fields, and UI copy use **Solo**.

Legacy names remain temporary mappings:

| Legacy | V2 |
|---|---|
| Practice | Solo |
| practice session | Solo session |
| practice answer | Solo attempt source record |
| daily_practice | daily_solo after consumer migration |
| Practice recommendation | Solo recommendation |
| weak topic | skill state with evidence and confidence |

Physical Practice table names may remain during the additive migration. Their presence must not make Practice the V2 public term.

---

## 4. System boundaries and evidence lanes

### 4.1 Shared pipeline, separate meaning

Solo, PvP, and Assessment write a common canonical attempt shape, but their results are never averaged blindly.

The aggregation grain is:

    user × target × skill × learning source × mechanic

Mechanic is populated only for Solo. It is null for PvP and Assessment.

### 4.2 Solo evidence

Solo primarily supports:

- daily learner-state calculation;
- understanding and independent accuracy;
- hint dependency;
- pace development;
- spaced-review scheduling;
- recommendation generation; and
- immediate and delayed recommendation evaluation.

### 4.3 Assessment evidence

Assessment supports:

- baseline and latest validated score;
- held-out or unseen transfer evidence;
- independent validation of progress;
- category or skill-level validation where the Assessment blueprint supports it; and
- readiness language only when sufficient standardized evidence exists.

Assessment is web-based and is not implemented in Mobile. Mobile may display Assessment results returned by the learning API.

Assessment never becomes the primary next-action recommendation in learning-v1. When Assessment evidence exists, its skill gap may be used as a separate signal when ranking Solo repair candidates.

Detailed Assessment delivery, browser security, session APIs, and web UI are outside this proposal.

### 4.4 PvP evidence

PvP supports:

- competitive performance;
- Solo-to-PvP context comparison;
- pressure-context observations; and
- separate Competition advice.

PvP does not determine Solo mastery, does not create a weak-topic label, and never becomes the primary next action in learning-v1.

The current public PvP socket events remain unchanged during V2 migration. The Game Backend maps authoritative match results and logs into canonical attempts without requiring a new client event vocabulary.

### 4.5 Prohibited aggregate

The system must never calculate or display:

    overall accuracy = (Solo + PvP + Assessment) / 3

Each cross-context comparison must expose both underlying metrics, their sample sizes, and their confidence.

---

## 5. Skill taxonomy and question authority

### 5.1 Taxonomy contract

The actual CPNS and BUMN skill tree belongs in a versioned, SME-approved content artifact. This document defines the contract that artifact must satisfy.

Each taxonomy release must include:

- schema version;
- content version;
- approval status;
- SME approval state and approver identity or reference;
- target IDs;
- category IDs;
- subcategory IDs;
- stable skill IDs;
- localized labels;
- enabled/disabled state and reason;
- curriculum weight;
- optional prerequisite skill IDs; and
- effective date or release reference.

A stable skill ID must not be reused for a different learning concept. A renamed skill keeps its ID. A materially changed concept receives a new ID or explicit taxonomy migration.

Example hierarchy:

    cpns
    └── tiu
        └── numerik
            └── percentage
                ├── percentage-increase
                ├── percentage-decrease
                └── reverse-percentage

Recommendations target the lowest level that has sufficient, reliable question inventory and evidence. If a leaf skill lacks reliable evidence, aggregation may roll up only through an explicit taxonomy relationship; the service must not infer relationships from labels.

### 5.2 Required question metadata

Every active learning question must have authoritative server-side metadata:

- stable question ID;
- source key;
- question revision/version;
- bank content version;
- target;
- category;
- optional subcategory;
- primary skill ID;
- optional prerequisite skill IDs;
- difficulty;
- question type;
- expected time when calibrated;
- Standard time limit;
- curriculum weight;
- Assessment eligibility;
- correct answer and explanation;
- optional hint;
- quality/calibration status;
- active state; and
- SME approval state.

The client must not submit target, category, skill, difficulty, version, expected time, curriculum weight, Assessment eligibility, correctness, score, or explanation as authoritative values.

### 5.3 Question versioning and snapshots

- Editing wording, options, answer, explanation, skill mapping, difficulty, or timing creates a new question revision.
- A Solo, PvP, or Assessment session snapshots the question revision and learning metadata it uses.
- The canonical attempt stores that snapshot reference so later content changes do not rewrite history.
- Derived analytics may exclude a revision that is later invalidated, but the raw attempt remains.
- A correction or invalidation must be auditable and trigger recalculation of affected learner state and quality metrics.

### 5.4 Safe question payload

Before resolution, the client may receive prompt, options, navigation metadata, timing policy, hint availability, and safe taxonomy labels.

Before resolution, the client must not receive:

- correct option;
- correctness;
- explanation;
- hint content before the hint endpoint is accepted;
- mastery or state result; or
- hidden Assessment blueprint answers.

---

## 6. Learner preferences

V2 adds a minimal learner-preference record. Preferences personalize delivery but do not override evidence safety.

    {
      "preferredMechanicMode": "focus",
      "preferredQuestionSelection": "recommended",
      "timedPracticeEnabled": true
    }

All fields are optional.

- Missing preferences use server policy defaults.
- A preferred mechanic is a preference, not a mastery claim.
- The recommendation engine may recommend Focus when accuracy is low even if Speed is preferred.
- A learner may manually choose Speed below the recommendation threshold, subject to the warning rules in Section 7.
- Exam date, weekly availability, self-reported weaknesses, and competition opt-in are deferred.

---

## 7. Solo experience

Solo configuration has three independent decisions:

1. **Learning objective** — why the session is being recommended.
2. **Mechanic mode** — how the learner answers.
3. **Question selection** — which questions the learner receives.
4. **Delivery policy** — how long the session continues.

The recommendation engine chooses the first three for the primary action. Delivery remains a separately versioned policy.

### 7.1 Default mobile structure

    Solo
    ├── Recommended Session
    │   └── objective + mechanic + question selection
    └── Customize
        ├── Mechanic: Focus | Standard | Speed
        └── Questions: Balanced | Recommended | Custom

The default screen should not require the learner to configure both axes before every session.

Indonesian example:

> **Sesi yang direkomendasikan**<br>
> Focus · Kenaikan Persentase<br>
> Akurasi mandiri kamu 5 dari 9. Latihan dilakukan tanpa batas waktu agar kamu dapat fokus pada pemahaman.

### 7.2 Focus

- No visible countdown.
- No automatic question timeout.
- Active response time is recorded silently.
- Hints and post-answer explanations are available.
- Primary decision metric: unseen independent accuracy.
- Recommended when accuracy or evidence confidence is low.
- Animations, content transitions, card selection, background time, and known disconnect time are excluded from valid pace evidence.

### 7.3 Standard

- Uses the authoritative Standard time limit from the question revision.
- Shows a visible countdown.
- The server owns opened time, deadline, and timeout resolution.
- Hints and post-answer explanations are available.
- Requesting a hint does not pause the timer.
- Primary metrics: accuracy, timeout rate, and completion within the Standard limit.

### 7.4 Speed

- Uses a personal pace target when enough comparable baseline evidence exists.
- Shows a visible countdown and uses reduced non-learning transition time.
- Hints and post-answer explanations remain available.
- Requesting a hint does not pause the timer.
- A hinted attempt is assisted evidence and is excluded from independent proficiency and fluency-baseline calculation.
- The recommendation engine may recommend Speed only when smoothed unseen independent accuracy is at least 85%, at least five valid comparable pace attempts exist, and the skill pace ratio is above 1.20.

**Proposed learning-v1 personal baseline:**

1. Select the latest ten valid, answered, no-hint, first-attempt Solo observations for the same skill and difficulty.
2. Require at least five observations.
3. Calculate their median effective response time.
4. Set the Speed deadline to 90% of that median, bounded so it never exceeds the authoritative Standard limit.
5. Snapshot the baseline, sample size, and mechanic-policy version in the session.

When a learner manually requests Speed without enough baseline evidence:

- resolve the effective mechanic to Standard;
- return an Indonesian warning;
- label the session as baseline collection;
- do not classify its attempts as Speed evidence.

Example warning:

> Data kecepatanmu belum cukup. Sesi ini menggunakan waktu Standard untuk membangun baseline sebelum latihan Speed dipersonalisasi.

When a learner manually requests Speed below the 85% accuracy gate:

- preserve learner control;
- return a warning that Focus is recommended first;
- never represent the choice as a system recommendation; and
- continue to classify hinted or repeated attempts honestly.

Example warning:

> Kami menyarankan Focus terlebih dahulu. Latihan Speed dapat memperkuat tebakan saat akurasi mandirimu masih berkembang.

### 7.5 Question-selection methods

**Balanced**

- Follows the SME-approved curriculum distribution.
- Prevents learners from selecting only familiar skills.
- Supports broad evidence collection and coverage maintenance.
- Must use stable curriculum weights, not equal random category selection.

**Recommended**

- Selects skills from learner state and the current objective.
- May target low accuracy, due review, missing evidence, slow but accurate performance, or an explicit prerequisite.
- Must not be labeled “Weak Topic” when evidence is insufficient.

**Custom**

- Lets the learner select one or more stable skill IDs.
- May present category/subcategory navigation, but sends stable skill IDs to the server.
- Does not convert a learner-selected skill into a system recommendation.
- Server validation rejects unknown, disabled, cross-target, or unavailable skills.

### 7.6 The 3 × 3 structure

| Mechanic | Balanced | Recommended | Custom |
|---|---|---|---|
| Focus | Calm broad evidence | Accuracy repair | Untimed learner-selected skills |
| Standard | Normal curriculum application | Consolidation or spaced review | Timed learner-selected skills |
| Speed | Broad fluency challenge when eligible | Accurate but slow skills | Learner-selected pace training |

Not every combination needs equal prominence. The primary recommendation returns one best combination; customization preserves learner control.

### 7.7 Question opening

The client calls the question-open operation after the question is fully rendered and before answer controls become active.

The server records:

- opened timestamp;
- requested and effective mechanic;
- timer visibility;
- time limit;
- deadline;
- session question identity; and
- open-operation idempotency key.

An answer is rejected until the question has been opened. A repeated open request with the same idempotency key returns the original result and never restarts a timer.

Solo timing is learning evidence, not a high-stakes anti-cheat guarantee. Assessment owns stricter independent validation. Solo anomaly checks must still reject impossible or inconsistent timing evidence.

### 7.8 Hint request

Hint content is returned only after a server-accepted hint request.

- The operation is idempotent.
- The server records requested time.
- Repeated retrieval does not create multiple hint events.
- Hint usage has no score penalty.
- Hint usage changes evidence classification from independent to assisted.
- The timer continues in Standard and effective Speed.

### 7.9 Server-authoritative timeout

For Standard and effective Speed:

- the deadline is server-owned;
- reaching the deadline creates one unanswered, incorrect, timed-out attempt;
- the timeout and a concurrently arriving answer compete through one atomic resolution guard;
- whichever authoritative resolution commits first wins;
- the losing operation returns the committed result and creates no second attempt; and
- a client timeout call is reconciliation only, not the source of truth.

Focus never produces an automatic timeout.

### 7.10 Session completion and product rewards

Future Solo session completion is defined by the active delivery policy, not a hardcoded question count.

Only completion reason **policy_completed** qualifies for:

- Daily Solo mission progress;
- streak activity;
- Hired Pass learning activity;
- a normal completed-session result; and
- the result-exit ad safe break defined by the approved PRD after adoption.

User-stopped, inventory-exhausted, and abandoned outcomes do not qualify. When a fixed-duration, mastery-evidence, adaptive, or other approved stopping rule is fully satisfied, the completion reason is policy_completed and a separate policyStopTrigger records the condition that stopped the session.

**Current compatibility:** The current five-question Practice flow continues to use the approved PRD completion and reward behavior until V2 delivery is approved and migrated.

---

## 8. Delivery-policy contract and decision debt

The analytics foundation operates per attempt and does not require a fixed session length.

V2 must represent delivery through a policy object:

    {
      "policyId": "policy-reference",
      "policyVersion": 1,
      "stoppingRule": "fixed_count",
      "minimumQuestions": 5,
      "maximumQuestions": 5,
      "resolvedQuestionCount": 5,
      "resolvedDurationMinutes": null
    }

The fields illustrate the contract only. They do not approve a five-question V2 default.

Every session must snapshot:

- delivery policy ID and version;
- stopping rule;
- any minimum/maximum bounds;
- any resolved count or duration;
- policy inputs relevant to audit;
- completion reason; and
- policy stop trigger when the policy completed; and
- whether the result qualifies as policy completion.

**Decision debt:** No V2 policy ID, default question count, default duration, adaptive stopping rule, or per-mechanic session length is approved.

The following decisions remain open:

- fixed count versus fixed duration;
- ideal length for each mechanic;
- whether learners may continue after policy completion;
- evidence required for an adaptive stop;
- within-session topic allocation;
- difficulty progression;
- maximum repetition and intentional-review repetition;
- insufficient-inventory behavior;
- unfinished-session resume behavior; and
- whether Speed sessions should normally be shorter than Focus sessions.

These decisions block the new V2 Solo session builder. They do not block taxonomy work, canonical attempts, backfill, evidence classification, learner-state calculations, compatibility APIs, or dashboard work based on current data.

---

## 9. Canonical learning-attempt ledger

### 9.1 Authority

The authoritative analytical evidence layer is an append-only learning_attempts table.

Solo, PvP, and Assessment may retain separate operational storage, but every accepted result must map exactly once into the canonical ledger. Derived analytics read the canonical ledger, not an ad hoc union assembled differently by each endpoint.

Raw ledger rows are immutable except for privacy-required anonymization. Corrections are represented through auditable correction/invalidation records and new derived classifications.

### 9.2 Exactly-once source identities

Each source must provide a unique source-attempt key:

| Source | Required uniqueness |
|---|---|
| Solo | Solo answer/source row ID |
| PvP | match ID + card instance ID + learner ID |
| Assessment | Assessment session item ID + learner ID |

The database enforces uniqueness on learning source plus source-attempt key.

- Replaying identical ingestion returns the existing attempt.
- Reusing a key for different source data fails with an idempotency conflict.
- A timed-out question and an answer cannot create separate attempts for one source item.
- A source transaction must commit its operational outcome and canonical ingestion atomically where practical.
- Where cross-service atomicity is impossible, the source uses a durable outbox and idempotent consumer.

### 9.3 Canonical attempt shape

    {
      "attemptId": "attempt_01JY7D71",
      "source": "solo",
      "sourceAttemptKey": "solo-answer-01JY7D71",
      "dataFidelity": "v2_complete",
      "userId": "user_123",
      "target": "cpns",
      "sessionId": "solo_01JY7CE4",
      "recommendationId": "rec_01JY7A2M",
      "learningObjective": "repair_accuracy",
      "requestedMechanicMode": "focus",
      "effectiveMechanicMode": "focus",
      "questionSelectionType": "recommended",
      "deliveryPolicyId": null,
      "questionId": "q_901",
      "questionVersion": 3,
      "contentVersion": "cpns-2026-08",
      "skillId": "cpns.tiu.numerik.percentage-increase",
      "difficulty": "medium",
      "selectedOptionIndex": 2,
      "isCorrect": true,
      "hintRequested": false,
      "timedOut": false,
      "firstAttempt": true,
      "seenBefore": false,
      "exposureCountBefore": 0,
      "openedAt": "2026-08-31T09:04:10.000Z",
      "answeredAt": "2026-08-31T09:04:29.000Z",
      "clientActiveResponseTimeMs": 18420,
      "serverElapsedTimeMs": 19110,
      "backgroundDurationMs": 0,
      "effectiveResponseTimeMs": 18420,
      "validForAccuracy": true,
      "validForPaceAnalytics": true,
      "validForFluencyBaseline": true,
      "classificationVersion": "evidence-v1",
      "calculationVersion": "learning-v1"
    }

The physical schema may normalize snapshots or use typed columns rather than one JSON document. The behavioral fields and provenance must remain queryable.

### 9.4 Required attempt dimensions

**Identity and provenance**

- attempt, user, session, source, source-attempt key;
- recommendation ID when applicable;
- ingestion time and source event time;
- data-fidelity level;
- evidence-classification version; and
- calculation version used for any stored derived snapshot.

**Activity context**

- learning objective for Solo;
- requested and effective mechanic for Solo;
- question-selection type for Solo;
- delivery-policy reference when available;
- Assessment blueprint/version for Assessment;
- match/mode reference for PvP; and
- session completion state.

**Question snapshot**

- question ID and revision;
- content version;
- target, category, subcategory, and skill;
- difficulty;
- expected-time/calibration reference;
- Standard time limit;
- curriculum weight; and
- question quality state at presentation.

**Learner action**

- selected option or null timeout;
- server-derived correctness;
- hint request;
- timeout;
- first-attempt/retry state;
- previous exposure state and count;
- optional perceived difficulty;
- explanation-viewed state when captured; and
- abandonment context when relevant.

**Timing**

- opened, answered, and deadline timestamps;
- client active time;
- server elapsed time;
- background/inactive duration;
- effective time;
- pace-validity flags; and
- explicit invalidity reason.

### 9.5 Legacy backfill

Legacy data must be backfilled without inventing evidence.

Allowed fidelity examples:

- v2_complete — all required V2 fields captured authoritatively;
- legacy_solo — legacy Practice answer with known correctness and limited timing/hint trust;
- legacy_pvp — persisted match log with known result but incomplete exposure or timing context;
- assessment_import — future Assessment result ingested through an approved adapter.

For missing historical fields:

- store null or an explicit unknown value;
- set data-fidelity and exclusion reasons;
- do not infer unseen status from a missing history table;
- do not convert client usedHint into authoritative hint evidence without a server event;
- do not claim question revision when it was not captured;
- do not treat missing background time as zero; and
- do not include lower-fidelity observations in metrics whose eligibility cannot be proven.

Legacy evidence may still support transparent broad activity counts where its correctness and ownership are reliable.

### 9.6 Corrections, invalid questions, and privacy

- Question invalidation never deletes the raw attempt solely to improve a metric.
- Derived state excludes invalidated question revisions from the next calculation and records the exclusion reason.
- Admin deactivation affects future selection; invalidation controls analytical eligibility.
- Recalculation identifies the affected users and skills rather than rebuilding every learner synchronously.
- Account deletion follows the approved PRD privacy rule: delete or irreversibly anonymize user-owned learning evidence while retaining only permitted aggregate or operational audit data.
- Operational logs must not expose unrevealed answers, access tokens, or unnecessary personal data.

---

## 10. Evidence classification

Classification runs before aggregation. One attempt may qualify for broad activity accuracy while being excluded from independent or pace metrics.

### 10.1 Valid accuracy evidence

An attempt is valid for activity accuracy only when:

- an answer or authoritative timeout was recorded;
- source ownership and session legitimacy are valid;
- the question ID and captured revision are known;
- the source item was not duplicated;
- the question revision is not analytically invalidated; and
- server-derived correctness is available.

### 10.2 First-attempt evidence

A first attempt is the first authoritative resolution of one presented session question.

- Network retries do not create additional attempts.
- Future deliberate retries must receive a distinct source item and attempt ordinal.
- A retry is learning activity but is not first-attempt proficiency evidence.

### 10.3 Independent evidence

An attempt is independent when:

    valid accuracy evidence
    AND firstAttempt = true
    AND hintRequested = false

An unseen independent attempt additionally requires:

    seenBefore = false

Unseen independent Solo attempts are the primary proficiency evidence used for Solo learner state.

### 10.4 Assisted evidence

When hintRequested is true:

- the attempt counts toward broad activity accuracy;
- the attempt counts toward assisted accuracy;
- the attempt does not count toward independent or unseen-independent accuracy;
- the attempt does not enter a fluency baseline; and
- the result must not increase independent proficiency.

### 10.5 Repeated-question evidence

When seenBefore is true:

- the attempt may count for activity, practice, and reinforcement;
- the attempt is excluded from unseen-independent accuracy;
- the attempt does not by itself validate retention;
- the exposure count remains available to the dashboard and quality analysis; and
- exact repetition must be intentional under the future delivery policy.

### 10.6 Pace evidence

**Focus**

Focus uses client active time only when it is plausibly consistent with server elapsed time.

    difference =
      absolute(client active time − server elapsed time)

Focus is valid for broad pace analytics when:

    background duration = 0
    AND known disconnect duration = 0
    AND difference <= maximum(2,000 ms, 15% of server elapsed time)

Otherwise the answer remains eligible for accuracy but validForPaceAnalytics is false.

**Standard and effective Speed**

The server controls the deadline.

    effective response time =
      minimum(server elapsed time, authoritative time limit)

A timed-out attempt may count as capped mode-pace evidence and always counts toward timeout rate. It does not enter the personal fluency baseline.

An attempt is excluded from the personal fluency baseline when it is:

- hinted;
- repeated;
- a retry;
- timed out;
- backgrounded;
- affected by a known disconnect or technical interruption; or
- missing a comparable skill/difficulty identity.

### 10.7 Retention evidence

Retention evidence must:

- occur after a scheduled delay;
- use a different, equivalent question;
- be unseen before the review;
- be a first attempt;
- be independent; and
- use a valid question revision.

Exact-question repetition is not strong retention evidence.

**Proposed learning-v1 policy:** The first delayed review becomes due seven days after strong, fresh Solo evidence.

### 10.8 Assessment evidence

Assessment evidence must identify:

- the Assessment session and blueprint version;
- standardized timing policy;
- held-out or unseen eligibility;
- absence of hints and explanations before resolution;
- skill/category mapping supported by the blueprint; and
- official or approved score calculation.

Assessment evidence remains separate even when it contributes an Assessment-gap signal to Solo recommendation ranking.

---

## 11. Aggregation windows and learner-state grain

### 11.1 Time scopes

| Purpose | Scope |
|---|---|
| Current Solo skill state | Latest 20 eligible unseen independent Solo attempts per user × target × skill |
| Learning trend | Latest 10 versus previous 10 from that state block |
| Dashboard activity | Rolling 30 days |
| Exposure history | Lifetime |
| Assessment progress | Assessment history, baseline, and latest valid result |
| Retention | Delayed equivalent attempts and due schedule |
| Recommendation history | Active and recent recommendation/event history |
| Content quality | Configurable reporting window with sample sizes |

The 30-day dashboard window must not erase old learning history or make lifetime exposure appear unseen.

### 11.2 Comparable blocks

State and trends compare evidence with the same:

- user and target;
- skill;
- learning source;
- proficiency evidence class;
- and, where pace is involved, mechanic and difficulty.

The service must not compare an assisted repeated Focus block directly with unseen independent Standard evidence and call the difference learning progress.

### 11.3 Recalculation boundaries

An accepted attempt identifies its affected user, target, skill, source, and mechanic. Recalculation updates only affected projections, plus any recommendation or coverage summary depending on them.

---

## 12. Proposed learning-v1 metrics

Every user-facing percentage must include:

- numerator/correct count where applicable;
- denominator/eligible attempt count;
- unique question count;
- evidence confidence;
- evidence window or as-of time; and
- null rather than zero when the metric has no eligible evidence.

### 12.1 Activity accuracy

    activity accuracy % =
      correct valid attempts
      ÷ all valid attempts
      × 100

This is descriptive activity, not mastery.

### 12.2 Independent accuracy

    independent accuracy % =
      correct valid no-hint first attempts
      ÷ all valid no-hint first attempts
      × 100

### 12.3 Unseen-independent accuracy

    unseen-independent accuracy % =
      correct valid unseen no-hint first attempts
      ÷ all valid unseen no-hint first attempts
      × 100

This is the raw user-facing proficiency metric used alongside sample size.

### 12.4 Assisted accuracy

    assisted accuracy % =
      correct valid hint-assisted attempts
      ÷ all valid hint-assisted attempts
      × 100

### 12.5 Hint rate

    hint rate % =
      Solo attempts with a server-accepted hint request
      ÷ all hint-eligible valid Solo attempts
      × 100

### 12.6 Independence gap

    independence gap =
      assisted accuracy − independent accuracy

A positive gap is described as assistance dependency evidence, not as a psychological cause.

### 12.7 Smoothed proficiency accuracy

    smoothed accuracy % =
      (correct unseen-independent attempts + 2)
      ÷ (unseen-independent attempts + 4)
      × 100

The +2/+4 neutral prior is a proposed, unvalidated learning-v1 policy.

Example:

    5 correct from 9 unseen-independent attempts

    raw accuracy      = 5 / 9 = 55.56%
    smoothed accuracy = 7 / 13 = 53.85%

Raw accuracy is shown to learners. Smoothed accuracy supports state and recommendation decisions.

### 12.8 Evidence confidence

Confidence is evaluated in order so every evidence set has exactly one result.

**High**

    eligible attempts >= 15
    AND unique questions >= 8
    AND difficulty levels represented >= 2
    AND latest eligible evidence <= 14 days old

**Medium**

    not High
    AND eligible attempts >= 5
    AND unique questions >= 3
    AND latest eligible evidence <= 30 days old

**Low**

    every evidence set that is neither High nor Medium

Low confidence displays:

> Data masih dikumpulkan.

It must not display:

> Topik ini lemah.

### 12.9 Median response time

    median response time =
      median of valid effective response times

Median replaces average because interruptions and long-tail timing distort a mean.

### 12.10 Pace ratio

When a calibrated expected time exists:

    attempt pace ratio =
      effective response time
      ÷ calibrated expected time

    skill pace ratio =
      median of comparable attempt pace ratios

Interpretation:

- 0.80 is approximately 20% faster than expected.
- 1.00 is around expected.
- 1.30 is approximately 30% slower than expected.

Until expected times are calibrated, the system uses a personal comparable baseline and labels the result as personal pace rather than a population benchmark.

### 12.11 Timeout rate

    timeout rate % =
      authoritative timed-out questions
      ÷ all valid Standard and effective-Speed questions
      × 100

Focus has no timeout rate.

### 12.12 Retention

    retention % =
      correct delayed unseen independent attempts
      ÷ all delayed unseen independent attempts
      × 100

**Proposed learning-v1 concern threshold:** retention below 75%.

### 12.13 Learning trend

    accuracy trend =
      raw unseen-independent accuracy of latest 10
      − raw unseen-independent accuracy of previous 10

Trend is null until both blocks contain ten eligible attempts. Trend is expressed in percentage points.

### 12.14 Curriculum coverage

    coverage % =
      required enabled skills with sufficient evidence
      ÷ all required enabled skills
      × 100

**Proposed learning-v1 sufficient coverage:** at least three unique eligible questions for a skill.

One attempt does not count as coverage.

### 12.15 Assessment score and improvement

Assessment follows its approved blueprint. Where a simple score is valid:

    Assessment score % =
      correct valid Assessment items
      ÷ all valid Assessment items
      × 100

Where categories are weighted:

    weighted Assessment score =
      sum(category score × blueprint weight)
      ÷ sum(blueprint weights)

    Assessment improvement =
      latest valid Assessment score
      − baseline valid Assessment score

Mobile must not display readiness or validated improvement without valid Assessment evidence.

### 12.16 Context gaps

    timed application gap =
      Focus unseen-independent accuracy
      − Standard unseen-independent accuracy

    Speed gap =
      Standard unseen-independent accuracy
      − Speed unseen-independent accuracy

    Competition gap =
      Solo Standard unseen-independent accuracy
      − PvP accuracy

    Assessment transfer gap =
      Solo unseen-independent accuracy
      − Assessment accuracy

Each gap is shown only when both sides meet their own minimum evidence rule. Both metrics and sample sizes remain visible.

### 12.17 Activity and consistency

The dashboard may show:

- active learning days;
- questions answered;
- active learning minutes;
- current streak; and
- recent sessions.

These are engagement indicators, not proficiency evidence.

---

## 13. Solo learner state and Assessment validation

### 13.1 Ordered Solo state

The following proposed learning-v1 rules are evaluated in order for each user × target × skill:

1. **collecting_data**
   - fewer than five eligible unseen independent attempts; or
   - fewer than three unique eligible questions.
2. **needs_repair**
   - smoothed unseen-independent accuracy below 70%.
3. **developing**
   - smoothed unseen-independent accuracy from 70% inclusive to below 85%.
4. **needs_review**
   - accuracy previously reached at least 85%; and
   - the seven-day review is due, retention is below 75%, or the latest strong evidence is older than 30 days.
5. **needs_fluency**
   - smoothed unseen-independent accuracy is at least 85%;
   - at least five valid comparable pace attempts exist; and
   - calibrated or personal comparable pace ratio is above 1.20.
6. **secure**
   - smoothed unseen-independent accuracy is at least 85%;
   - evidence confidence is Medium or High;
   - no review condition is due; and
   - no eligible fluency concern is present.

A skill may be secure from strong Solo evidence without Assessment. This status means secure in Solo evidence, not independently validated exam readiness.

### 13.2 Separate Assessment validation

Assessment validation is not encoded inside SoloSkillStatus.

| Validation state | Meaning |
|---|---|
| not_available | No approved Assessment source/result is available |
| insufficient_evidence | Assessment exists but cannot support a stable claim |
| baseline_recorded | A valid baseline exists without a comparable later result |
| validated | Valid latest evidence supports the approved validation rule |
| needs_revalidation | Previous validation is stale or later valid evidence no longer supports it |

The exact web Assessment validation rule is owned by its future approved blueprint.

### 13.3 Evidence-based language

Allowed:

- “Your independent accuracy is 5 of 9.”
- “Your performance drops in timed Solo sessions.”
- “You are accurate, but your current pace is slower than your baseline.”
- “Assessment has not yet validated this progress.”

Not allowed:

- “You are anxious.”
- “You will pass the exam.”
- “This topic is mastered” based on one short session.
- “Your overall learning score is 82” without a transparent multi-metric definition.

---

## 14. Solo recommendation engine

### 14.1 Output boundary

The primary recommendation always describes one Solo action.

It answers:

1. What learning objective?
2. Which skill?
3. Which mechanic?
4. Which question-selection method?
5. Why?
6. With what evidence and confidence?

Assessment and PvP never become the primary action. Interview recommendations belong to a separate feature track.

### 14.2 Recalculation triggers

Recalculate the current recommendation when:

- a Solo session completes;
- affected learner state changes after a canonical attempt;
- a seven-day review becomes due;
- valid Assessment evidence changes a skill gap;
- the current recommendation expires;
- a question invalidation removes material evidence; or
- an admin content action makes the planned inventory unavailable.

PvP may update Competition comparison but does not promote PvP to the primary action.

### 14.3 Inputs

- minimal learner preferences;
- current Solo learner states;
- separate Assessment skill evidence when available;
- current review schedule;
- curriculum weights and prerequisites;
- available active question inventory;
- recent recommendation history;
- recent skill and question exposure;
- question-quality state; and
- calculation and policy versions.

### 14.4 Ordered objective gates

The engine selects the first objective with at least one valid candidate:

1. **repair_accuracy**
   - at least one skill is needs_repair.
   - mechanic: Focus.
   - question selection: Recommended.
2. **spaced_review**
   - no repair candidate exists; and
   - at least one skill is needs_review or has a due review.
   - mechanic: Standard.
   - question selection: Recommended.
3. **collect_evidence**
   - no repair or due-review candidate exists; and
   - at least one required skill is collecting_data or below coverage.
   - mechanic: Standard, or Focus when timed practice is disabled.
   - question selection: Balanced or Recommended according to the missing-evidence scope.
4. **build_fluency**
   - no earlier candidate exists; and
   - at least one skill is needs_fluency.
   - mechanic: Speed.
   - question selection: Recommended.
5. **maintain_coverage**
   - used when no earlier objective is eligible.
   - mechanic: Standard unless a supported preference applies.
   - question selection: Balanced.

The system ranks skills only within the winning objective. Scores from different objective formulas are not compared as if they shared the same meaning.

### 14.5 Normalized components

All components are clamped to 0 through 1.

    accuracy gap =
      clamp((85 − smoothed accuracy) / 85, 0, 1)

    Assessment gap =
      1 − Assessment accuracy as a decimal

    hint dependency =
      hint rate as a decimal

    retention risk =
      1 − retention accuracy as a decimal

When retention evidence is missing:

    retention risk =
      minimum(days since last strong result / 7, 1)

    pace gap =
      clamp(pace ratio − 1, 0, 1)

    uncertainty =
      1 − minimum(eligible attempts / 15, 1)

    curriculum importance =
      skill curriculum weight
      ÷ maximum enabled skill curriculum weight

    repetition penalty =
      minimum(skill attempts in last 24 hours / 5, 1)

### 14.6 Repair ranking

    repair priority =
      0.40 × accuracy gap
      + 0.25 × Assessment gap
      + 0.15 × hint dependency
      + 0.20 × curriculum importance
      − 0.20 × repetition penalty

Assessment gap is included only when valid Assessment evidence exists for the same skill. When a positive component is unavailable, its positive weights are proportionally redistributed across available positive components before the penalty is applied.

Assessment and Solo accuracy remain separate input metrics; they are not averaged into a mastery score.

### 14.7 Review ranking

    review priority =
      0.50 × retention risk
      + 0.25 × curriculum importance
      + 0.15 × uncertainty
      − 0.20 × repetition penalty

### 14.8 Fluency ranking

Fluency candidates must already pass the 85% accuracy and five-pace-attempt gates.

    fluency priority =
      0.60 × pace gap
      + 0.25 × curriculum importance
      + 0.15 × timeout rate
      − 0.20 × repetition penalty

### 14.9 Evidence and coverage ranking

For collect_evidence:

1. fewer eligible attempts;
2. fewer unique questions;
3. higher curriculum importance;
4. fewer attempts in the last 24 hours;
5. older last-practiced time; and
6. ascending stable skill ID.

For maintain_coverage:

1. overdue review state;
2. older last-practiced time;
3. higher curriculum importance;
4. fewer recent attempts; and
5. ascending stable skill ID.

These rules avoid inventing a cross-objective global score and keep ties deterministic.

### 14.10 Candidate filtering

Before selection:

- remove candidates without sufficient valid active inventory;
- remove Speed candidates that fail accuracy or pace-evidence gates;
- remove invalidated or disabled skills/questions;
- apply recent-skill repetition penalties;
- validate target and taxonomy version;
- ensure any prerequisite relation is explicit; and
- ensure the proposed combination is supported by an approved mechanic and delivery policy.

**Decision debt:** Final behavior for insufficient inventory and within-session question distribution remains unresolved.

### 14.11 Recommendation response

    {
      "recommendationId": "rec_01JY7A2M",
      "generatedAt": "2026-08-31T09:00:00.000Z",
      "expiresAt": "2026-09-01T09:00:00.000Z",
      "calculationVersion": "learning-v1",
      "objective": "repair_accuracy",
      "mechanicMode": "focus",
      "questionSelection": {
        "type": "recommended",
        "skillIds": [
          "cpns.tiu.numerik.percentage-increase"
        ],
        "skillLabels": [
          "Kenaikan Persentase"
        ]
      },
      "deliveryPolicyId": null,
      "availability": {
        "runnable": false,
        "reason": "delivery_policy_unresolved"
      },
      "reason": {
        "headline": "Perkuat Kenaikan Persentase",
        "description": "Akurasi mandiri kamu masih 5 dari 9. Focus direkomendasikan agar kamu dapat memperbaiki pemahaman tanpa batas waktu.",
        "evidence": [
          {
            "metric": "unseenIndependentAccuracy",
            "value": 55.56,
            "correctCount": 5,
            "attemptCount": 9,
            "uniqueQuestionCount": 6,
            "confidence": "medium"
          }
        ]
      }
    }

When an approved delivery policy exists, deliveryPolicyId is required and availability.runnable is true. During compatibility migration, a legacy fixed-five adapter may make a current Practice action runnable, but it must be labeled compatibility behavior rather than the V2 delivery default.

### 14.12 Recommendation events

Track:

- shown;
- accepted;
- dismissed;
- session_started;
- session_completed;
- immediate_result_attached; and
- delayed_result_attached.

Shown, accepted, and dismissed may originate from the client. Session-started and session-completed are normally authoritative server events.

Dismissal reasons may include:

- prefer_another_skill;
- too_difficult;
- too_easy;
- not_enough_time;
- do_not_like_timed_mode; and
- other.

Dismissal changes product feedback data, not the learner's proficiency.

### 14.13 Recommendation effectiveness

    acceptance rate =
      accepted recommendations
      ÷ shown recommendations

    completion rate =
      completed recommended sessions
      ÷ started recommended sessions

    immediate change =
      post-session unseen-independent accuracy
      − pre-session unseen-independent accuracy

    delayed lift =
      delayed unseen-independent accuracy
      − pre-recommendation unseen-independent accuracy

Delayed lift is stronger than immediate change but remains observational. Causal claims require controlled experiments.

---

## 15. User-facing outputs

### 15.1 Home next action

Home shows one primary Solo action:

- objective;
- mechanic;
- target skill;
- question-selection type;
- evidence-based reason;
- sample size and confidence;
- estimated duration only when an approved delivery policy can provide one;
- availability/runnable state; and
- one start action plus a Customize alternative.

Home does not lead with leaderboard rank.

### 15.2 Learning dashboard

The mobile dashboard answers the five questions in Section 1 through:

1. **Next Solo action**
2. **Learning summary**
   - curriculum coverage;
   - unseen-independent Solo accuracy;
   - learning trend when available;
   - current pace compared with an appropriate baseline;
   - evidence confidence.
3. **Skill map**
   - skill label;
   - Solo status;
   - raw unseen-independent accuracy and counts;
   - median comparable pace;
   - confidence;
   - last practiced time;
   - recommended mechanic.
4. **Retention**
   - due review state;
   - delayed evidence count and result;
   - next review time.
5. **Assessment result**
   - validation state;
   - baseline and latest score when available;
   - change in percentage points;
   - date and supported category/skill breakdown.
6. **Activity**
   - active days;
   - answered questions;
   - active learning minutes;
   - recent Solo sessions.
7. **Competition**
   - clearly separate section for rating, tier, match record, PvP accuracy, and a qualified Solo-to-PvP comparison.

The dashboard window query controls visualization and activity history only. It does not rewrite learner state or lifetime exposure.

### 15.3 Skill map example

| Skill | Solo status | Unseen independent accuracy | Pace | Evidence | Next action |
|---|---|---:|---:|---|---|
| Percentage increase | Needs repair | 5/9 (55.56%) | 1.28× | Medium | Focus |
| Ratio | Developing | 13/17 (76.47%) | 1.10× | High | Standard |
| Arithmetic | Needs fluency | 18/20 (90%) | 1.35× | High | Speed |
| Analogy | Secure | 18/20 (90%) | 0.94× | High | Maintain |

Labels and icons accompany color. Color alone must not communicate status.

### 15.4 Trend and context visualizations

- Accuracy trend uses equivalent latest-10 and previous-10 blocks.
- Pace trend identifies the baseline and whether the value is personal or calibrated.
- Assessment scores use visually distinct markers from Solo evidence.
- Context comparisons expose sample size and suppress unsupported comparisons.
- The interface may use an accuracy-versus-pace view:
  - low accuracy + slow → Focus;
  - low accuracy + fast → possible rushing pattern, not a diagnosis;
  - high accuracy + slow → fluency work;
  - high accuracy + fast → secure when other state gates pass.

### 15.5 Empty and low-confidence states

Examples:

> YUDHA masih mengumpulkan data. Selesaikan beberapa soal dari keterampilan yang berbeda agar rekomendasi menjadi lebih akurat.

> Assessment belum tersedia. Kemajuan ini berasal dari bukti Solo dan belum divalidasi melalui Assessment.

The UI must not convert null into 0%, show a fake readiness percentage, or label a skill weak when confidence is Low.

### 15.6 After-session output

After a Solo session, show:

- objective and skills trained;
- answer and evidence summary;
- important error pattern supported by evidence;
- change from a comparable pre-session block when valid;
- current confidence;
- next review scheduling when applicable; and
- the next Solo recommendation.

Do not declare mastery from one session.

---

## 16. Internal content-quality dashboard

### 16.1 Surface and authorization

The content-quality dashboard is an authenticated admin web surface backed by the App Backend.

V2 uses one server-managed admin role. Only authenticated users with that role may:

- view item-level quality data;
- create and assign review cases;
- change triage state;
- resolve a review;
- record a review note; or
- deactivate/reactivate a question.

Mobile must not expose this admin surface. Client-supplied role claims are never authoritative.

### 16.2 Dashboard evidence

For each question revision, show:

- target, taxonomy path, difficulty, and content version;
- active, approval, quality, and review states;
- total valid attempt count;
- unseen-independent attempt count;
- activity and unseen-independent accuracy;
- median valid response time;
- timeout rate;
- hint rate;
- seen-versus-unseen gap;
- distractor selection counts and percentages;
- response distribution by comparable learner-state bands where safe;
- latest use time;
- current flags and case owner;
- related source link/reference; and
- exclusion or invalidation history.

For inventory, show:

- active question count by target and skill;
- difficulty coverage;
- Assessment-eligible inventory;
- skills below delivery minimums;
- missing explanations/hints/metadata;
- version and SME-approval status; and
- recently deactivated or invalidated revisions.

### 16.3 Quality signals

The dashboard supports signals for:

- suspiciously low or high accuracy;
- non-functioning distractors;
- unusually long response time;
- high timeout or hint rate;
- large repeated-versus-unseen performance gap;
- potential negative or weak discrimination;
- missing skill/difficulty coverage; and
- recommendation plans blocked by inventory.

**Decision debt:** Automatic flag thresholds, minimum sample sizes, and calibrated discrimination formulas are unresolved. Initial UI may expose sortable continuous metrics and manually created cases. It must not pretend unapproved thresholds are authoritative.

### 16.4 Triage workflow

Recommended case states:

    open → in_review → resolved
                     ↘ dismissed

Each case records:

- case ID;
- question and revision;
- signal or manual reason;
- evidence snapshot;
- admin owner;
- state;
- notes;
- created, updated, and resolved timestamps; and
- final disposition.

Possible dispositions:

- no_issue;
- revise_content;
- revise_answer_or_explanation;
- remap_skill_or_difficulty;
- invalidate_revision;
- deactivate_question;
- reactivate_question.

### 16.5 Controlled deactivation

- Metrics never deactivate a question automatically.
- An admin must explicitly submit the action and reason.
- Deactivation affects future selection immediately after commit.
- Deactivation is not the same as analytical invalidation.
- If the revision is also invalidated, affected learner state is recalculated while raw attempts remain.
- Every action is auditable.
- Repeated deactivation requests are idempotent.

---

## 17. Public and internal interface families

Examples define behavioral shape. The OpenAPI contract becomes authoritative only after PRD adoption and contract-file updates.

### 17.1 Common conventions

- External JSON uses camelCase.
- Timestamps are ISO 8601 UTC strings.
- Successful REST responses use a data envelope.
- Every mutation requires an idempotency key.
- Errors use the approved PRD error envelope and stable codes.
- User ownership is enforced by the App Backend and database policies.
- Clients never calculate correctness, deadlines, evidence class, learner state, recommendation priority, Assessment validation, or content-quality action authority.

### 17.2 Recommendation

    GET /learning/recommendations/current

Returns the single current Solo recommendation described in Section 14.

    POST /learning/recommendations/:recommendationId/events

Client-writable events are limited to shown, accepted, and dismissed. The server normally creates session_started and session_completed from authoritative Solo state.

### 17.3 Learning dashboard

    GET /learning/dashboard?window=30d

Top-level response:

    {
      "asOf": "2026-08-31T10:00:00.000Z",
      "calculationVersion": "learning-v1",
      "activityWindow": {
        "type": "rolling_days",
        "days": 30
      },
      "target": "cpns",
      "nextAction": {},
      "learningSummary": {},
      "skillStates": [],
      "learningTrend": [],
      "modeComparison": {},
      "retention": {},
      "assessment": {},
      "weeklyActivity": [],
      "recentSoloSessions": [],
      "competition": {}
    }

Every metric object with a percentage follows:

    {
      "value": 72.4,
      "correctCount": 42,
      "attemptCount": 58,
      "uniqueQuestionCount": 31,
      "confidence": "high",
      "asOf": "2026-08-31T10:00:00.000Z"
    }

### 17.4 Create Solo session

    POST /solo/sessions

Recommended request:

    {
      "idempotencyKey": "mobile-solo-session-01928",
      "mechanicMode": "focus",
      "questionSelection": {
        "type": "recommended"
      },
      "recommendationId": "rec_01JY7A2M"
    }

Custom request:

    {
      "idempotencyKey": "mobile-solo-session-01930",
      "mechanicMode": "standard",
      "questionSelection": {
        "type": "custom",
        "skillIds": [
          "cpns.tiu.numerik.percentage-increase",
          "cpns.tiu.numerik.percentage-decrease"
        ]
      }
    }

Validation:

- custom requires at least one stable skill ID;
- all skills must be enabled and match the learner's target;
- recommendationId is required when accepting a recommendation;
- the server determines resolved skills, inventory, mechanic, timing, and delivery;
- clients do not submit question count as a V2 invariant;
- requested Speed may resolve to Standard baseline collection; and
- a runnable V2 session requires an approved delivery policy.

Response shape:

    {
      "data": {
        "sessionId": "solo_01JY7CE4",
        "status": "active",
        "target": "cpns",
        "learningSource": "solo",
        "learningObjective": "repair_accuracy",
        "requestedMechanicMode": "focus",
        "effectiveMechanicMode": "focus",
        "questionSelection": {
          "requestedType": "recommended",
          "resolvedSkillIds": [
            "cpns.tiu.numerik.percentage-increase"
          ]
        },
        "deliveryPolicy": {
          "policyId": "approved-policy-id",
          "policyVersion": 1,
          "stoppingRule": "approved-rule",
          "minimumQuestions": null,
          "maximumQuestions": null,
          "resolvedQuestionCount": null,
          "resolvedDurationMinutes": null
        },
        "timerPolicy": {
          "timerVisible": false,
          "hardDeadline": false,
          "timeLimitMs": null,
          "responseTimeRecorded": true
        },
        "warnings": []
      }
    }

The placeholder values above must be replaced by an approved policy before the endpoint becomes the canonical V2 builder.

### 17.5 Read and resume boundary

    GET /solo/sessions/:sessionId

Returns the owned session, accepted attempts, current authoritative progress, effective policies, and any safe current question.

**Decision debt:** Whether an unfinished V2 session is resumable and how policy time behaves across resume is unresolved.

### 17.6 Open question

    POST /solo/sessions/:sessionId/questions/:sessionQuestionId/open

Request:

    {
      "idempotencyKey": "open-solo-01JY7CE4-q1"
    }

Timed response:

    {
      "data": {
        "sessionQuestionId": "sq_1001",
        "openedAt": "2026-08-31T09:04:10.000Z",
        "timerVisible": true,
        "hardDeadline": true,
        "timeLimitMs": 30000,
        "deadlineAt": "2026-08-31T09:04:40.000Z",
        "mechanicPolicyVersion": "standard-v1"
      }
    }

Focus returns null timeLimitMs and deadlineAt.

### 17.7 Request hint

    POST /solo/sessions/:sessionId/questions/:sessionQuestionId/hint

Request:

    {
      "idempotencyKey": "hint-solo-01JY7CE4-q1"
    }

Response:

    {
      "data": {
        "sessionQuestionId": "sq_1001",
        "hint": "Cari selisih nilai awal dan nilai akhir terlebih dahulu.",
        "requestedAt": "2026-08-31T09:04:22.000Z"
      }
    }

Hints are available in Focus, Standard, and effective Speed. The server event, not a client boolean, is authoritative.

### 17.8 Submit Solo answer

    POST /solo/sessions/:sessionId/answers

Request:

    {
      "idempotencyKey": "answer-solo-01JY7CE4-q1",
      "sessionQuestionId": "sq_1001",
      "selectedOptionIndex": 2,
      "clientActiveResponseTimeMs": 18420,
      "backgroundDurationMs": 0
    }

The client must not send correctness, score, skill, difficulty, question version, hint usage, deadline, or evidence-classification flags.

Response:

    {
      "data": {
        "attemptId": "attempt_01JY7D71",
        "sessionQuestionId": "sq_1001",
        "selectedOptionIndex": 2,
        "correctOptionIndex": 2,
        "isCorrect": true,
        "timedOut": false,
        "responseTime": {
          "clientActiveMs": 18420,
          "serverElapsedMs": 19110,
          "backgroundMs": 0,
          "effectiveMs": 18420,
          "validForPaceAnalytics": true,
          "validForFluencyBaseline": true
        },
        "assistance": {
          "hintRequested": false,
          "independent": true
        },
        "exposure": {
          "seenBefore": false,
          "exposureCountBefore": 0,
          "evidenceType": "unseen_first_attempt"
        },
        "learningEvidence": {
          "countedForActivityAccuracy": true,
          "countedForIndependentAccuracy": true,
          "countedForRetention": false
        },
        "feedback": {
          "explanation": "Persentase kenaikan dihitung dengan..."
        },
        "progress": {}
      }
    }

### 17.9 Timeout reconciliation

A timeout is created by the server deadline. A client may call the answer endpoint with selectedOptionIndex null only to reconcile state. The request returns the committed timeout and cannot create it twice.

### 17.10 Complete or stop Solo session

    POST /solo/sessions/:sessionId/finish

The final request/response semantics depend on the approved delivery policy. At minimum the response must expose:

- status;
- completion reason;
- policy stop trigger when applicable;
- whether policy completed;
- answered/correct counts;
- raw accuracy and evidence breakdown;
- median valid time;
- skill results;
- review scheduling;
- mission/streak/Hired Pass eligibility; and
- next recommendation.

The endpoint must not convert a user-stopped session into policy_completed.

### 17.11 Solo history

    GET /solo/history?skillId=&limit=&offset=

Returns paginated session summaries with requested/effective mechanic, selection type, objective, delivery-policy reference, completion reason, counts, timestamps, and evidence summary.

### 17.12 Admin content quality

Conceptual endpoint families:

    GET   /admin/content-quality/questions
    GET   /admin/content-quality/questions/:questionId
    GET   /admin/content-quality/review-cases
    POST  /admin/content-quality/review-cases
    PATCH /admin/content-quality/review-cases/:caseId
    POST  /admin/content-quality/questions/:questionId/deactivate
    POST  /admin/content-quality/questions/:questionId/reactivate

All require the server-managed admin role, stable errors, idempotency for mutations, action reasons, and audit logging.

### 17.13 Assessment boundary

No public Assessment session API is approved by this document.

The future web Assessment system must ingest canonical evidence through a server-owned adapter satisfying Sections 4, 9, and 10. Mobile consumes only Assessment summaries from /learning/dashboard.

### 17.14 Compatibility endpoints

During migration:

- /practice routes remain available to existing mobile consumers;
- /analytics continues to return its approved shape;
- Lobby may continue adapting the current recommendation shape;
- current Practice source rows are ingested/backfilled with honest fidelity;
- no compatibility adapter may fabricate V2 evidence; and
- deprecation is based on migration gates and observed consumer usage, not an arbitrary date.

---

## 18. Logical data and processing

### 18.1 Required logical entities

| Entity | Purpose |
|---|---|
| learner_preferences | Minimal optional Solo preferences |
| skill_taxonomy | Versioned SME-approved target/category/subcategory/skill catalog |
| question_skill_mappings | Primary and prerequisite skill mappings by question revision |
| solo_sessions | V2 operational Solo session and policy snapshots |
| solo_session_questions | Selected question revisions, order, purpose, and open/deadline state |
| solo_answers | Operational Solo resolution and idempotency |
| learning_attempts | Append-only canonical evidence ledger |
| learner_skill_state | Versioned derived Solo state and metrics |
| retention_schedule | Due review state and delayed-evidence link |
| learning_recommendations | Stored recommendation, inputs, explanation, and versions |
| recommendation_events | Shown-through-outcome lifecycle |
| assessment_evidence | Future Assessment source references and blueprint summaries |
| question_quality_metrics | Derived item and inventory metrics |
| question_review_cases | Admin triage workflow and evidence snapshot |
| question_quality_actions | Auditable invalidation/deactivation/reactivation history |

These are logical requirements. Physical migrations may extend or rename current tables, introduce new tables, or use compatibility views, provided the behavior and audit boundaries remain intact.

### 18.2 Source and projection ownership

- App Backend owns Solo, learning dashboard, recommendations, learner state, preferences, and admin APIs.
- Game Backend owns authoritative PvP resolution and emits idempotent source evidence.
- Future web Assessment owns Assessment UX but writes evidence through an approved server adapter.
- PostgreSQL owns durable attempts, projections, policies, review cases, and audit records.
- Mobile and web clients render server authority and never write derived state.

### 18.3 Prepared state, not dashboard-time recomputation

    canonical attempts
          ↓
    classify affected attempt
          ↓
    recalculate affected learner skill state
          ↓
    update due review and recommendation
          ↓
    dashboard reads prepared projections

Dashboard requests must not scan and recalculate the learner's entire history synchronously.

### 18.4 Recalculation timing

**On every accepted attempt**

- persist operational resolution;
- append or resolve canonical attempt exactly once;
- update exposure history;
- mark affected projections dirty or update them transactionally.

**On Solo policy completion**

- finalize session summary;
- recalculate affected skills, coverage, review schedule, and recommendation;
- apply eligible mission/streak/Hired Pass effects exactly once;
- attach recommendation outcome.

**On Assessment ingestion**

- update separate validation and transfer-gap projections;
- recalculate affected Solo ranking signal without overwriting Solo state;
- refresh dashboard summary.

**Scheduled/background**

- mark seven-day reviews due;
- expire recommendations;
- refresh content-quality metrics;
- process invalidation recalculations; and
- create coverage snapshots if required.

### 18.5 Calculation versions

Every derived state and recommendation records:

- calculationVersion;
- evidence-classification version;
- taxonomy version;
- input as-of time;
- attempt range or source watermark; and
- policy versions used for confidence, review, mechanic, and scoring.

Changing learning-v1 creates a new version and recalculates projections from raw evidence. It does not mutate old attempts.

### 18.6 Security and privacy

- JWT and ownership validation apply to all learner endpoints.
- Admin routes require the server-managed admin role.
- Service credentials remain server-side.
- Correct answers stay hidden until authoritative resolution.
- RLS or equivalent service boundaries prevent cross-user learning reads.
- Assessment results are private to the learner and authorized services.
- Logs use IDs needed for operations and exclude tokens and unrevealed answer keys.
- Account deletion follows the approved PRD anonymization/deletion rule.

---

## 19. Additive compatibility and migration

### 19.1 Migration principles

- New public and logical V2 contracts use Solo.
- Existing clients continue to receive current Practice and Analytics behavior until migrated.
- Compatibility is an adapter boundary, not a second source of learning truth.
- New V2 fields are additive until every active consumer supports them.
- A cutover gate requires contract tests, telemetry showing migrated consumers, and rollback instructions.
- No migration changes the approved PRD by implication.

### 19.2 Suggested sequence

1. Add skill/version metadata and canonical-attempt infrastructure.
2. Backfill existing Practice and PvP evidence with fidelity labels.
3. Build learner-state projections alongside current analytics.
4. Expose /learning reads without removing /analytics.
5. Add recommendation lifecycle tracking.
6. Close delivery debt and approve a V2 policy.
7. Add /solo mutations and migrate Mobile.
8. Move mission/streak/Hired Pass sources from legacy completion to policy completion.
9. Remove legacy reads/writes only after consumer and rollback gates pass.

### 19.3 Compatibility mapping

| Existing surface | Migration behavior |
|---|---|
| /practice/dashboard | Remains current; Mobile later moves to /learning/dashboard and Solo UI |
| /practice/sessions | Continues fixed-five current flow; never labeled V2 delivery |
| /practice/history | Remains until /solo/history migration |
| /analytics | Remains approved response; does not fabricate V2 confidence or unseen evidence |
| practice_* physical tables | Continue as operational/legacy sources or compatibility storage |
| current Lobby recommendation | Adapter until Lobby consumes current learning recommendation |
| current PvP socket events | Remain public contract; server maps results into canonical attempts |
| daily_practice source keys | Continue until a coordinated daily_solo compatibility migration |

### 19.4 Backward-compatibility exit criteria

A legacy surface may be retired only when:

- all supported clients use the replacement;
- contract and E2E tests pass;
- source evidence is reconciled;
- mission, streak, Pass, and ad behavior is equivalent or explicitly approved;
- monitoring shows no supported legacy traffic;
- rollback remains possible; and
- PRD and OpenAPI contracts approve the removal.

---

## 20. Dependency-ordered delivery gates

These are acceptance gates, not calendar estimates.

### Gate 1 — Taxonomy and policy approval

- Product adoption and ingestion into the PRD are complete.
- Skill-taxonomy schema and stable-ID rules are accepted.
- A versioned SME-owned skill catalog exists for each enabled target.
- Learning-v1 metric, confidence, state, and recommendation rules are approved or revised.
- Decision debt is assigned owners and exit evidence.

### Gate 2 — Canonical evidence and legacy backfill

- learning_attempts and source uniqueness are migrated.
- Solo/Practice and PvP ingestion are idempotent.
- Legacy fidelity rules and backfill reports are verified.
- Question revisions, skill mappings, exposure, and invalidation paths exist.
- Privacy, ownership, and anonymization tests pass.

### Gate 3 — Versioned learner-state analytics

- Evidence classification and all learning-v1 formula tests pass.
- learner_skill_state is rebuildable from canonical attempts.
- Latest-20 state, 10-versus-10 trends, confidence, coverage, and seven-day review work.
- Source lanes remain separate.
- /learning/dashboard supports empty, low-confidence, and migrated users.

### Gate 4 — Recommendations and dashboards

- Ordered objective gates and deterministic ties pass.
- Recommendation evidence, versions, shown-through-outcome events, and expiry work.
- Mobile shows one Solo action, skill map, retention, Assessment result when available, and separate Competition.
- Admin web dashboard supports authorized metrics and manual triage without automatic deactivation.

### Gate 5 — New Solo mechanics after delivery debt closes

- An approved delivery policy replaces placeholders.
- Focus, Standard, and personalized Speed timing pass.
- Hint events, question opening, timeout races, and session completion are authoritative and idempotent.
- Mission, streak, Hired Pass, and ad-safe-break behavior uses policy completion.
- Mobile migrates from Practice to Solo with compatibility and rollback evidence.

### Gate 6 — Assessment ingestion and content-quality operations

- An approved web Assessment blueprint and adapter produce canonical evidence.
- Mobile displays result/validation without implementing Assessment delivery.
- Assessment gaps influence Solo repair ranking only as specified.
- Admin deactivation, invalidation, recalculation, and audit behavior pass.
- Content/SME and QA approve quality workflows and calibrated thresholds when introduced.

---

## 21. Acceptance scenarios

### 21.1 Evidence classification

- Unseen, no-hint, first Solo answer counts for activity, independent, and unseen-independent accuracy.
- Hint request makes the result assisted even if the client later reports no hint.
- Repeated question counts for activity but not unseen-independent accuracy.
- Retry does not enter first-attempt proficiency.
- Invalidated question revision remains in the ledger but leaves affected projections.
- Lower-fidelity legacy evidence cannot enter a metric whose eligibility is unknown.

### 21.2 Formula boundaries

- 5 correct of 9 yields 55.56% raw and 53.85% smoothed.
- High confidence wins before Medium when all High conditions pass.
- A recent 15-attempt set with insufficient High diversity but at least three unique questions becomes Medium, not unclassified.
- Old or diverse-insufficient evidence becomes Low.
- Null evidence returns null, not zero.
- Every percentage includes counts and confidence.

### 21.3 Learner-state ordering

- Fewer than five eligible attempts is collecting_data.
- Smoothed 69.99% is needs_repair.
- Smoothed 70% through 84.99% is developing.
- Strong evidence with a due seven-day review is needs_review before fluency evaluation.
- At least 85%, five valid pace attempts, and ratio above 1.20 is needs_fluency.
- Secure requires Medium/High confidence and no review or fluency condition.
- Secure Solo and Assessment not_available can coexist.

### 21.4 Recommendation selection

- Any repair candidate prevents review, coverage, fluency, or maintenance from winning.
- Due review wins when no repair exists.
- Evidence collection wins before fluency when earlier gates are empty.
- Assessment gap changes repair ranking but never overwrites Solo accuracy.
- PvP never becomes the primary action.
- Candidate ties end with stable skill ID.
- Missing inventory removes a candidate rather than returning an unrunnable hidden plan.

### 21.5 Mechanic, hint, and timer behavior

- Focus has no deadline but records validated active time.
- Standard uses the question revision's authoritative limit.
- Speed uses 90% of a median with at least five comparable baseline attempts.
- No Speed baseline resolves to Standard and returns a warning.
- Manual low-accuracy Speed returns a warning and is not a recommendation.
- Hint is available in every mechanic and timed-mode countdown continues.
- Hinted attempts do not enter independent or fluency-baseline metrics.

### 21.6 Timeout and idempotency

- Server deadline creates exactly one timeout without a client message.
- Answer and timeout racing for one question create one committed attempt.
- Replayed open never restarts the deadline.
- Replayed hint creates one server hint event.
- Replayed answer returns the first committed result.
- Reused idempotency key with different input fails.
- Canonical source-attempt uniqueness prevents duplicate ingestion.

### 21.7 Dashboards

- New learner sees honest collection messaging and no weak labels.
- No Assessment shows not_available and no readiness percentage.
- Activity window changes do not change lifetime exposure or current latest-20 state.
- PvP information appears only in Competition and qualified context comparisons.
- After-session output does not declare mastery.
- Labels/icons remain understandable without color.

### 21.8 Admin content quality

- Non-admin users receive forbidden responses.
- Admin creates, assigns, resolves, and dismisses review cases.
- A metric cannot automatically deactivate a question.
- Explicit deactivation prevents future selection and records an audit action.
- Analytical invalidation recalculates affected states but preserves raw attempts.
- Replayed actions remain idempotent.

### 21.9 Compatibility

- Existing supported Mobile can complete the five-question Practice flow unchanged.
- /analytics remains schema-compatible during the additive phase.
- Compatibility adapters never synthesize unseen, hint, timing, or confidence evidence.
- New and legacy reads reconcile to their documented evidence scopes.
- Removing a legacy route fails the gate when supported traffic remains.

### 21.10 Privacy and deletion

- Learners cannot read another learner's attempts or Assessment result.
- Admin access is auditable and limited to the server-managed role.
- Account deletion deletes or irreversibly anonymizes learning identity according to the approved policy.
- Aggregate retention does not permit re-identification.
- Logs never reveal unreleased answers or credentials.

---

## 22. Decision-debt register

| ID | Decision debt | Blocked capability | Required exit evidence |
|---|---|---|---|
| D1 | Fixed count, duration, or another stopping rule | Canonical V2 Solo builder | Product decision supported by user research and prototype results |
| D2 | Default length by mechanic | Delivery-policy values and duration copy | Completion, abandonment, learning, and fatigue evidence |
| D3 | Continue-after-completion behavior | Session lifecycle and reward boundary | UX decision plus abuse/reward analysis |
| D4 | Adaptive/mastery stopping criteria | Adaptive policy | Validated evidence rule and deterministic tests |
| D5 | Within-session skill distribution | Recommended/Balanced/Custom builder | Curriculum and learning validation |
| D6 | Difficulty progression | Session question sequence | Content/SME policy and inventory analysis |
| D7 | Maximum repetition | Exposure controls | Retention/reinforcement study and content capacity |
| D8 | Insufficient-inventory fallback | Candidate selection and completion reason | Minimum inventory standard and UX decision |
| D9 | Resume/abandon behavior | GET/finish session semantics | Mobile lifecycle design, policy timing, and reward safety |
| D10 | Whether Speed sessions are shorter | Speed delivery policy | Pace-training prototype data |
| D11 | Final skill catalogs | Skill-level production analytics | Versioned SME approval for CPNS and BUMN |
| D12 | Detailed web Assessment product/API | Assessment creation and execution | Separate approved web Assessment contract and blueprint |
| D13 | Automated content-quality thresholds | Automatic quality flags | Minimum sample, false-positive, and SME calibration study |
| D14 | Population expected-time benchmarks | Population pace labels | Representative calibrated learner data |

No engineer may close a debt item by embedding an undocumented constant. Approved answers must update this document or its adopted PRD replacement, versioned policy/configuration, contracts, and tests together.

---

## 23. Source reconciliation

This document consolidates these workspace-local ignored notes:

- new-improve-analytics-blueprint.md
- new-api-docs.md
- new-analytics-flow.md
- new-question-delivery-debt.md

They may not exist in every clone because docs-archive is gitignored.

| Conflict or ambiguity | V2 resolution |
|---|---|
| Practice versus Solo | Solo is canonical; Practice is compatibility only |
| Checkpoint versus Assessment | Assessment is canonical and web-based |
| Assessment as a recommended action | Primary recommendation is Solo only |
| PvP as a recommended action | PvP remains separate Competition context |
| Five-question V2 session | Explicit decision debt; current fixed-five flow remains compatibility |
| View versus table for canonical attempts | Append-only canonical table |
| 30-day current state versus lifetime aggregate | Latest 20 eligible attempts for state; 30 days for activity; lifetime exposure |
| 80% versus 85% Speed eligibility | 85% plus five valid pace attempts |
| Needs speed versus needs fluency | needs_fluency is canonical |
| Speed hints disabled versus available | Hints available in all mechanics; hinted evidence is assisted |
| Client timeout versus server timeout | Server auto-resolves; client only reconciles |
| Secure requiring Assessment | Solo secure and Assessment validation are separate dimensions |
| Assessment blended into mastery | Separate signal may influence Solo repair ranking but is never averaged into Solo state |
| Generic priority versus objective-specific rules | Ordered objective gates, then within-objective ranking |
| 90-day aggregation versus recent behavior | Latest-20 state and 30-day activity summary |
| Five-question rewards | Future policy_completed; legacy fixed-five behavior continues until migration |
| Read-only versus operational content QA | Full admin web triage and controlled manual deactivation |
| Multiple reviewer roles versus one | One server-managed admin role |
| Smoothed 5/9 example reported as 61.54% in one source | Correct value is 53.85% |

---

## 24. Adoption record and implementation readiness

Product approval and ingestion into [PRD.md](PRD.md) are complete as of 2026-08-31. The remaining items are delivery-gate and implementation readiness requirements; they do not create a second source of product authority.

- Product approval of scope, terminology, learner-state language, recommendation behavior, and decision debts is complete.
- Content/SME approves taxonomy contracts, skill catalogs, curriculum weights, and question-quality responsibilities.
- App Backend approves REST, data ownership, calculation, projection, idempotency, and admin boundaries.
- Game Backend approves PvP canonical-ingestion behavior without incompatible socket changes.
- Mobile approves Solo migration, warnings, dashboard states, localization, accessibility, and compatibility.
- Web ownership approves the future Assessment boundary and admin dashboard surface.
- Data/Analytics approves formulas, confidence rules, versioning, and evaluation design.
- QA approves acceptance scenarios and migration gates.
- Security/Privacy approves admin access, evidence retention, and account-deletion handling.
- DevOps approves background jobs, outbox/retry behavior, observability, and rollback.
- Delivery-policy debts must be closed before Gate 5 can pass.
- Approved decisions are merged into [PRD.md](PRD.md).
- OpenAPI, shared types, database migrations, fixtures, and automated tests are updated in the same implementation change.
- Archived drafts remain historical and this record is marked adopted.

[PRD.md](PRD.md) wins regardless of implementation readiness status.

# LifeIndex — Improvement Roadmap

> Comprehensive analysis and improvement plan based on UI/UX review, product feedback, and codebase audit.
> Generated: January 28, 2026

---

## Table of Contents

1. [UX Issues — Score & Messaging](#1-ux-issues--score--messaging)
2. [Visual Consistency & Polish](#2-visual-consistency--polish)
3. [Weekly Charts — Missing Data](#3-weekly-charts--missing-data)
4. [Score Transparency](#4-score-transparency)
5. [Mood Tracking Integration](#5-mood-tracking-integration)
6. [Cross-Metric Correlations](#6-cross-metric-correlations)
7. [Revenue Model Analysis](#7-revenue-model-analysis)
8. [Product Positioning & Differentiators](#8-product-positioning--differentiators)
9. [Existing Backlog (from requirements.md)](#9-existing-backlog-from-requirementsmd)
10. [AI Prompt Engineering — Insights Quality](#10-ai-prompt-engineering--insights-quality)
11. [Food & Calorie Tracking](#11-food--calorie-tracking)
12. [Historical LifeIndex Scores (Today / Yesterday / Weekly)](#12-historical-lifeindex-scores-today--yesterday--weekly)

---

## 1. UX Issues — Score & Messaging

### Problem: Time-of-Day Insensitivity

**Current behavior:** The LifeIndex score at 8:28 AM shows "24 — Needs Attention" with red colors. This feels punishing for an early-morning check when the user simply hasn't had time to accumulate steps/calories/workouts yet.

**Root cause analysis:**
- `LifeIndexScoreEngine.calculateScore()` in `Core/Scoring/LifeIndexScoreEngine.swift` uses absolute targets (e.g., 8,000–12,000 steps, 300–600 calories) regardless of time of day
- Missing metrics are skipped (`continue` in the weight loop), but only metrics with *some* data contribute — if Garmin syncs partial data like heart rate but not steps, the score gets dragged down by the zero-value metrics that did sync
- The score label "Needs Attention" (20–39 range) and "Low" (0–19) use alarming language regardless of context

**Proposed solutions:**

#### Option A: Time-Aware Score Scaling (Recommended)
- Scale cumulative metric targets (steps, calories, workout minutes) by the proportion of the day elapsed
- At 8 AM (~33% of waking hours), the step target would scale from 8,000 → ~2,640
- Non-cumulative metrics (heart rate, HRV, blood oxygen, sleep) stay unscaled since they're point-in-time or overnight measurements
- **Files affected:** `LifeIndexScoreEngine.swift` (add `timeScaleFactor` parameter), `DashboardViewModel.swift` (pass current time)

```
Cumulative metrics to scale: steps, activeCalories, workoutMinutes, mindfulMinutes
Static metrics (no scaling): heartRate, restingHeartRate, HRV, bloodOxygen, sleepDuration
```

#### Option B: Context-Aware Labels
- Change score labels to be gentler in early hours:
  - Before noon: "Building Momentum" instead of "Needs Attention", "Just Getting Started" instead of "Low"
  - After 6 PM: Use the current labels since the day is mostly over
- **Files affected:** `LifeIndexScoreEngine.swift` (add time-aware `label(for:at:)` method)

#### Option C: Both A + B Combined
- Scale cumulative targets AND soften labels in the morning
- Most comprehensive but highest implementation effort

### Problem: "Needs Attention" Tone

**Current labels** (from `LifeIndexScoreEngine.label(for:)` line 79):
```
90-100: "Excellent"
75-89:  "Great"
60-74:  "Good"
40-59:  "Fair"
20-39:  "Needs Attention"  ← anxiety-inducing
0-19:   "Low"              ← feels like failure
```

**Proposed gentler alternatives:**
```
90-100: "Excellent"       (keep)
75-89:  "Great"           (keep)
60-74:  "Good"            (keep)
40-59:  "Fair"            → "Building Up"
20-39:  "Needs Attention" → "Room to Grow"
0-19:   "Low"             → "Just Starting"
```

**Also affects:** `explanationText(for:)` in `DashboardViewModel.swift` (lines 220–239) — the explanation strings like "Your body needs extra care today" should match the softer tone.

---

## 2. Visual Consistency & Polish

### Issue A: Activity Rings Contrast

**Current:** Activity rings use `color.opacity(0.2)` for the background track against the card background. On dark mode especially, the 0.2 opacity green/orange/pink rings are hard to see.

**Fix:** Increase background ring opacity to `0.3` and add a subtle shadow or inner glow to the foreground ring.

**Files affected:** `DashboardView.swift` — `ActivityRing` struct (line 259+)

### Issue B: Icon System Inconsistency

**Current state of section headers:**
| Section | Icon | Style |
|---------|------|-------|
| Insights | `lightbulb.fill` (via Label) | Yellow tint, uses `Label()` |
| Activity | None | Text-only "Activity" |
| Sleep | `bed.double.fill` | Icon + text manually composed |
| Heart Health | `heart.fill` | Icon + text manually composed |
| Recovery | `arrow.counterclockwise.circle.fill` | Icon + text manually composed |
| Recent Workouts | `flame.fill` | Text-only (icon is in workout rows) |
| Weekly Trends | None | Text-only "This Week" |
| Mindfulness | `brain.head.profile` | Icon + text manually composed |
| Score Breakdown | None | Text-only |

**Proposed fix:** Create a `SectionHeader` component that standardizes the pattern:

```swift
struct SectionHeader: View {
    let title: String
    let icon: String
    let color: Color
}
```

Apply consistently to ALL sections. Every section gets an icon + colored tint.

**Suggested section icons:**
| Section | Icon | Color |
|---------|------|-------|
| Insights | `lightbulb.fill` | `.yellow` |
| Activity | `flame.fill` | `Theme.activity` |
| Sleep | `bed.double.fill` | `Theme.sleep` |
| Heart Health | `heart.fill` | `Theme.heartRate` |
| Recovery | `arrow.counterclockwise.circle.fill` | `Theme.recovery` |
| Recent Workouts | `figure.run` | `Theme.calories` |
| Weekly Trends | `chart.bar.fill` | `Theme.accentColor` |
| Mindfulness | `brain.head.profile` | `Theme.mindfulness` |
| Score Breakdown | `chart.pie.fill` | `Theme.accentColor` |

**Files affected:** New `Shared/Components/SectionHeader.swift`, updates to `DashboardView.swift` (all section cards)

---

## 3. Weekly Charts — Missing Data

### Problem

When a day has no data (e.g., Friday's sleep bar is missing), the chart shows nothing — no bar, no indicator. This is ambiguous: does it mean 0 hours of sleep, or missing data?

**Current code** (lines 742–750 of `DashboardView.swift`):
```swift
Chart(data) { summary in
    let sleepHours = (summary.metrics[.sleepDuration] ?? 0) / 60.0
    BarMark(...)
}
```

The `?? 0` fallback means missing data renders identically to "0 hours of sleep."

### Proposed Fix

**Option A: Dashed Outline Bar (Recommended)**
- If `summary.metrics[.sleepDuration] == nil`, render a dashed-outline BarMark with "No data" annotation
- Use `.foregroundStyle(.clear)` with a `.border` or overlay for the dashed effect

**Option B: "No Data" Label**
- For days with nil metrics, show a small text label "—" at the x-axis position
- Simpler to implement, less visually elegant

**Option C: Gray Placeholder Bar**
- Render a low-opacity gray bar for missing days to visually distinguish from 0
- Quick implementation, clear visual signal

**Files affected:** `DashboardView.swift` — `WeeklyTrendsSection`

---

## 4. Score Transparency

### Problem

The LifeIndex score is a "black box." Users who care about health stats want to understand what drives their number.

**Current state:**
- Score Breakdown card exists (`ScoreBreakdownCard` in `DashboardView.swift`) showing per-metric scores
- But there's no explanation of the *algorithm* — how weights work, what "ideal range" means, why HRV matters more than mindfulness (15% vs 5%)

### Proposed: "How Your Score Works" Explainer

**Approach: Tappable info sheet**

Add an `(i)` button on the LifeIndex Score Card that opens a sheet explaining:

1. **Weight breakdown** — visual bar chart showing each metric's contribution
   ```
   Sleep         ████████████████████  20%
   Steps         ███████████████       15%
   HRV           ███████████████       15%
   Heart Rate    ██████████            10%
   Resting HR    ██████████            10%
   Blood O2      ██████████            10%
   Calories      ██████████            10%
   Mindfulness   █████                  5%
   Workout       █████                  5%
   ```

2. **Ideal ranges** — for each metric, show the target range and where the user currently sits
   ```
   Sleep: 7h 42m  ✅ (ideal: 7-9 hours)
   Steps: 3,200   ⚠️ (ideal: 8,000-12,000)
   ```

3. **How scoring works** — plain-English explanation:
   "Each metric is scored 0-100% based on how close you are to the ideal range. Metrics within the ideal range score 100%. The further away, the lower the score. Your LifeIndex is the weighted average of all available metrics."

**Files affected:**
- New `Features/Dashboard/ScoreExplainerSheet.swift`
- `LifeIndexScoreCard.swift` (add info button + sheet trigger)
- Expose `LifeIndexScoreEngine.weights` and `targets` as public (currently private)

---

## 5. Mood Tracking Integration

### Current State

- `MoodLog` Core Data entity exists (`Core/Persistence/Models/MoodLog.swift`) with: id, mood (Int16), note (String?), date
- No UI for mood logging currently visible on the dashboard
- `WellnessView` tab exists but implementation status is unclear

### Why This Matters (Product Perspective)

Apple Health doesn't do mood tracking well. Combining subjective mood with objective metrics is a genuine differentiator. The correlation engine ("You tend to feel better on days after 7+ hours of sleep") is the kind of insight that keeps people coming back.

### Proposed Implementation

#### Phase A: Quick Mood Check-In
- Add a floating "How are you feeling?" prompt on the dashboard (once per day, dismissible)
- 5-point emoji scale: 😫 😕 😐 🙂 😊
- Optional one-line note
- Save to Core Data `MoodLog`

#### Phase B: Mood in Insights
- After 7+ days of mood data, include mood-based insights:
  - "You rated your mood 4.2/5 on days with 7+ hours of sleep vs. 2.8/5 on days with <6 hours"
  - "Your best mood days correlate with 8k+ steps"
- Add mood to the weekly trends chart (overlay line)

#### Phase C: Mood Correlations Dashboard
- Dedicated "Mood & Wellness" section showing:
  - 7-day mood trend
  - Top 3 metrics most correlated with good mood days
  - Mood journal history

**Files affected:**
- New `Features/Dashboard/MoodCheckInCard.swift`
- `DashboardView.swift` (add mood prompt section)
- `DashboardViewModel.swift` (add mood data fetching + correlation logic)
- `Core/Persistence/Models/MoodLog.swift` (may need updates)
- `WellnessView.swift` (full mood history)

---

## 6. Cross-Metric Correlations

### Current State

The priority-based insights engine (`buildPriorityInsights()` in `DashboardViewModel.swift` lines 267–425) includes one compound insight: "poor sleep + elevated HR = priority 95." But there's no broader correlation engine.

### Proposed: Correlation Engine

After accumulating 14+ days of data, compute Pearson correlations between metrics:

```
Pairs to analyze:
- Sleep duration ↔ Resting HR next day
- Sleep duration ↔ Steps next day
- Sleep duration ↔ Recovery score
- Steps ↔ Sleep quality that night
- Workout intensity ↔ Resting HR next day
- Mood ↔ Sleep duration (once mood tracking is active)
- Mood ↔ Steps
- Mood ↔ Recovery score
```

Surface top correlations as insights:
- "Your resting HR drops 5 bpm on mornings after 8+ hours of sleep"
- "You tend to sleep 45min longer on days with 10k+ steps"

**Files affected:**
- New `Core/Scoring/CorrelationEngine.swift`
- `DashboardViewModel.swift` (add correlation-based insights to priority system)
- Requires persistent historical data (Core Data or weekly cache)

---

## 7. Revenue Model Analysis

### Context

- **Target audience:** iPhone users who care about health stats + mood + activity tracking
- **Value proposition:** Synthesis layer on top of Apple Health — turning raw data into a single score with human-readable insights
- **Data collection:** Mostly passive (HealthKit), low friction for retention
- **Key challenge:** Health apps have notoriously poor retention (2-3 week usage cliff)

### Option 1: Freemium + Subscription

| Tier | Features | Price |
|------|----------|-------|
| Free | Daily score, basic insights (top 2), activity rings, sleep/heart cards | $0 |
| Pro (monthly) | All insights, AI summaries, weekly trends, score breakdown, mood tracking, correlations, PDF reports | $4.99/mo |
| Pro (annual) | Same as monthly | $29.99/yr (~$2.50/mo) |

**Pros:**
- Recurring revenue, predictable income
- Free tier drives acquisition and word-of-mouth
- AI summary (Foundation Models) is a clear "premium" feature
- Aligns with health app market expectations (Strava, Oura, etc.)

**Cons:**
- Subscription fatigue — users increasingly resist another $5/mo
- Need to continuously prove value to prevent churn
- Free tier must be useful enough to hook users, limited enough to convert

**Retention hooks for Pro:**
- Weekly email digest with insights
- Mood correlations (need 7+ days of data — natural lock-in)
- Historical trend analysis (more data = more value = harder to leave)
- PDF health reports for doctor visits

### Option 2: One-Time Purchase

| Option | Features | Price |
|--------|----------|-------|
| Full app | Everything | $14.99–$24.99 |

**Pros:**
- Simple, user-friendly — no subscription anxiety
- Higher initial conversion rate
- Appeals to subscription-fatigued audience
- No ongoing pressure to justify recurring cost

**Cons:**
- One revenue event per user — need constant new user acquisition
- No recurring revenue for ongoing development costs
- AI features (Foundation Models) have compute cost but no recurring income to cover it
- Harder to fund continued feature development

### Option 3: Hybrid (Recommended for Launch)

**Phase 1 — Free launch:**
- Ship everything for free for the first 60 days
- Track retention: who stays past day 7? Day 30? Day 60?
- Track feature usage: which features do retained users actually use?
- Talk to retained users — ask what they'd pay for

**Phase 2 — Introduce tiers based on data:**
- Gate the features that retained users value most behind Pro
- Test both subscription and one-time pricing via A/B (using RevenueCat or StoreKit 2)
- Likely split:
  - Free: Score, basic insights, activity, sleep, heart cards
  - Pro: AI summaries, mood tracking, correlations, PDF reports, score explainer, advanced trends

**Phase 3 — Evaluate B2B2C:**
- Employer wellness programs (bulk licensing)
- Insurance partnerships (premium discounts for healthy behavior)
- Healthcare provider integrations (patient tracking between appointments)
- This is a longer road but potentially the larger opportunity

### Revenue Model Decision Framework

```
┌─────────────────────────────────────────────────┐
│ If runway is <6 months:                         │
│   → One-time purchase, ship fast, monetize now  │
│                                                 │
│ If runway is 6-12 months:                       │
│   → Free launch → subscription (Phase 1→2)      │
│                                                 │
│ If runway is 12+ months:                        │
│   → Free launch → data-driven pricing → B2B2C   │
│                                                 │
│ If this is a side project / learning exercise:  │
│   → Free launch, focus on retention metrics     │
│   → Monetize only after proven product-market   │
│     fit (>20% 60-day retention)                 │
└─────────────────────────────────────────────────┘
```

---

## 8. Product Positioning & Differentiators

### Core Value Proposition

"LifeIndex is the interpretation layer for your complete health picture — turning sleep, activity, nutrition, mood, and vitals into a single daily score with AI-powered insights that actually tell you something useful."

### Strategic Shift: Reader → Writer

With food/calorie tracking, LifeIndex transitions from a passive reader of Apple Health data to an active writer. This is strategically significant:
- **Passive (current):** Reads HealthKit data → interprets → displays. Any app can do this.
- **Active (with food logging):** Generates primary nutrition data that doesn't exist without user action in this app. Three months of food logs create real switching costs.
- **Synthesis (differentiator):** "You burned 400 cal at the gym but ate 600 extra at dinner, and you've been sleeping poorly, which increases cravings — focus on sleep first." No competitor connects all these dots.

### Key Differentiators vs. Apple Health

| Apple Health | LifeIndex |
|-------------|-----------|
| Shows raw data | Synthesizes into one score |
| No insights | Priority-based insights with actionable advice |
| Clinical tone | Encouraging, human-readable |
| No mood tracking | Mood + physical metric correlations |
| No AI summaries | On-device AI health summaries |
| No cross-metric analysis | Compound insights (sleep + HR patterns) |
| Overwhelming data | Curated daily dashboard |

### Key Differentiators vs. Competitors

| Competitor | Their Angle | LifeIndex Angle |
|-----------|------------|-----------------|
| Whoop | Hardware + recovery | Software-only, works with any device |
| Oura | Ring hardware + readiness | No hardware required |
| Strava | Social fitness | Private health synthesis |
| Apple Fitness+ | Workouts | Holistic health (sleep, mood, vitals) |
| MyFitnessPal | Food database (200M users) | AI photo estimation + full health integration |
| Lose It | Calorie tracking + barcode | Nutrition as one piece of the whole picture |
| Cronometer | Precise macro tracking | Simpler logging, score-driven synthesis |

### Positioning Risks

1. **"Why not just use Apple Health?"** — Need the synthesis + insights to be genuinely 10x better than raw data
2. **Apple could build this** — Apple adding a "Health Score" feature would be an existential threat. Mitigate by focusing on mood correlations and AI insights that Apple is unlikely to personalize as deeply
3. **Data privacy concerns** — All processing must stay on-device. Foundation Models being on-device is a feature, not a limitation

---

## 9. Existing Backlog (from requirements.md)

### Not Yet Implemented (from original requirements)

| Feature | Phase | Priority (suggested) | Notes |
|---------|-------|---------------------|-------|
| Training load (7-day/28-day) | Phase 2 | Medium | Useful for fitness-focused users |
| Strain vs. recovery visualization | Phase 2 | Medium | Requires training load |
| Mood logging UI | Phase 3 | **High** | Key differentiator (see section 5) |
| Stress indicators from HRV | Phase 3 | Medium | Enhances wellness section |
| Mood ↔ physical correlations | Phase 3 | **High** | Killer feature for retention |
| PDF report generation | Phase 4 | Low | Nice-to-have, Pro feature candidate |
| CSV export | Phase 4 | Low | Power user feature |
| Anomaly detection | Phase 4 | Medium | "Your resting HR spiked 15% this week" |
| Backend API | Phase 5 | Low (for now) | Not needed until multi-device/sync |
| Sign in with Apple | Phase 5 | Low (for now) | Only needed with backend |
| Cloud sync | Phase 5 | Low (for now) | Only needed with backend |
| Push notifications | Phase 5 | Medium | Reminders, anomaly alerts |
| Customizable widgets | Not phased | Medium | User picks which metrics to show |

### Recently Completed (this sprint)

- [x] Theme token system (spacing, icon sizes, icon frames)
- [x] UI consistency pass across all dashboard cards
- [x] Enhanced score card with dynamic explanation + contributors
- [x] Priority-based insights engine with compound insights
- [x] Section reordering for better readability
- [x] Apple HKActivityRingView integration with Garmin fallback
- [x] AI health summary via Foundation Models (iOS 26)
- [x] Short + detailed AI summary with expand/collapse
- [x] Tab navigation caching (prevent reload on tab switch)

---

## 10. AI Prompt Engineering — Insights Quality

### Problem: AI Summaries Read Like Generic AI Output

**Current behavior:** The "View More" detailed summary from Foundation Models is verbose, hedging, and generic. Phrases like "while commendable," "it's wonderful to see," and "every small step counts towards a healthier lifestyle!" feel like filler. Users will stop reading after the first few times.

**Current prompts** (from `DashboardViewModel.swift` lines 522–551):
- Short prompt: "Summarize this person's daily health in 2-3 short sentences..."
- Detailed prompt: "Provide a detailed daily health analysis in 5-8 sentences..."

Both prompts are too permissive — they let the LLM ramble and add motivational fluff.

### Root Causes

1. **Prompt gives too much freedom** — "5-8 sentences" is too long for a mobile card
2. **No anti-pattern instructions** — LLM defaults to verbose "helpful assistant" tone
3. **No time-of-day context** — Morning insights comment on low steps/calories which are meaningless at 8 AM
4. **No structure enforcement** — Prose paragraphs are harder to scan than structured bullets

### Proposed Fix: Rewritten Prompts

#### Short Summary (always visible)

```
Current time: {HH:mm}.
You are a concise health dashboard. Write exactly 2 sentences.
Sentence 1: State the score and the single biggest factor (positive or negative).
Sentence 2: One specific, actionable thing based on today's data.

Rules:
- No motivational filler ("great job", "keep it up", "every step counts")
- No hedging ("while", "however", "it's worth noting")
- Use the user's actual numbers
- If it's before noon, DO NOT comment negatively on low steps or active calories
- If it's morning, focus on sleep quality and recovery from last night

{metricsContext}
```

#### Detailed Summary (on "View More" tap)

```
Current time: {HH:mm}.
Write exactly 3 short sections. Use this format:

What's working: [1 sentence about the strongest metric and why it matters]
What needs attention: [1 sentence about the weakest area with a specific number]
One thing to try: [1 concrete, specific action — not generic advice]

Rules:
- Maximum 60 words total
- Use the user's actual numbers, not vague references
- No motivational language
- No phrases like "it's great to see" or "remember that"
- If before noon, frame activity metrics as "building" not "behind"
- Reference the user's own patterns when possible

{metricsContext}
```

### Alternative: Structured Output Instead of Prose

Instead of asking the LLM for free-form text, request structured JSON and render it in the app:

```json
{
  "working": "Sleep (7.2h) — in ideal range",
  "attention": "Steps (513) — 5% of daily goal",
  "action": "A 10-min walk after lunch — you're usually most active 12-2pm"
}
```

This gives the app full control over formatting and prevents LLM verbosity. The LLM fills in content, the app controls presentation.

### Time-of-Day Prompt Templates

Rather than one generic prompt, use 4 templates based on time:

| Time Window | Focus Areas | Avoid |
|-------------|-------------|-------|
| **Morning (6-10 AM)** | Sleep quality, recovery status, day intentions | Commenting on low steps/calories |
| **Midday (10 AM-2 PM)** | Activity progress, food logging nudge, momentum | N/A — all metrics fair game |
| **Afternoon (2-6 PM)** | Progress check, remaining goals, evening plans | N/A |
| **Evening (6 PM+)** | Day summary, wins, wind-down suggestions, sleep prep | Pushing for more activity |

**Files affected:** `DashboardViewModel.swift` — `buildShortPrompt()`, `buildDetailedPrompt()`, `buildMetricsContext()`

### Note on Local LLM Behavior

Apple Foundation Models (the ~3B on-device model) tends to be more verbose than cloud models to seem "helpful." Specific countermeasures:
- Explicit word/sentence limits in the prompt
- "Do NOT" instructions for common filler patterns
- Structured output format rather than free prose
- Post-processing: truncate at character limit if the model ignores constraints

---

## 11. Food & Calorie Tracking

### Strategic Significance

This feature changes LifeIndex from a **reader** of Apple Health data to a **writer**. Currently the app only interprets data that other apps/devices collect. Food logging creates primary data that doesn't exist without user action — this fundamentally increases switching costs and stickiness.

### Current State

- `LifeIndexScoreEngine` includes `activeCalories` (calories burned) with 10% weight
- No concept of calories consumed / nutritional intake
- Apple Health supports `HKQuantityType(.dietaryEnergyConsumed)` for writing food data

### Proposed Implementation

#### Phase A: Manual Food Logging

**Quick-log UI:**
- Floating "+" button or dedicated "Log Food" card on dashboard
- Simple entry: meal name (optional), calories, meal type (breakfast/lunch/dinner/snack)
- Save to HealthKit via `HKQuantityType(.dietaryEnergyConsumed)` — this makes it available to Apple Health and other apps
- Also save to Core Data for faster local queries

**Dashboard integration:**
- New "Nutrition" card showing: calories consumed / goal, net calories (consumed - burned)
- Traffic-light indicator: green (deficit), yellow (maintenance), red (significant surplus)

**Files affected:**
- New `Features/FoodLog/FoodLogView.swift` (logging sheet)
- New `Features/FoodLog/FoodLogViewModel.swift`
- New `Core/HealthKit/NutritionManager.swift` (write to HealthKit)
- `DashboardView.swift` (add nutrition card)
- `DashboardViewModel.swift` (fetch dietary data)
- `HealthKitManager.swift` (add `HKQuantityType(.dietaryEnergyConsumed)` to write types)

#### Phase B: AI Photo-Based Calorie Estimation

**How it works:**
1. User takes a photo of their meal (or picks from camera roll)
2. On-device Foundation Models (or Vision framework) analyzes the image
3. Returns: estimated food items, portion sizes, calorie range
4. User confirms or adjusts, then logs

**Key design decisions:**
- Show a **range** (e.g., "350-500 cal") rather than false precision — a salad can be 300 or 900 depending on dressing, cheese, protein amounts that aren't visually obvious
- Ask **one clarifying question** if ambiguous ("Did this have dressing?" or "What size portion?")
- Always allow manual override

**Technical approach (iOS 26):**
```swift
// Option 1: Foundation Models with image input
let session = LanguageModelSession()
let image = // UIImage from camera
let prompt = "Estimate calories for this meal. Return: items, estimated calories (range), macros."
let response = try await session.respond(to: prompt, with: [image])

// Option 2: Apple Vision framework for food detection + separate calorie lookup
// Less accurate but works on older iOS versions
```

**Competitive context:**
- MyFitnessPal has 200M users and a massive food database — can't compete on database size
- LifeIndex advantage: integration — calories in + calories burned + sleep + mood + activity in ONE score
- "You burned 400 cal at the gym but ate 600 extra cal at dinner, and you've been sleeping poorly, which research shows increases cravings — maybe tomorrow focus on sleep first"
- That synthesis is genuinely differentiated

#### Phase C: Nutrition in LifeIndex Score

**Add nutrition to the scoring engine:**

```
Updated weights (rebalanced):
- Sleep Duration:     18% (was 20%)
- Steps:              13% (was 15%)
- HRV:               12% (was 15%)
- Heart Rate:         8%  (was 10%)
- Resting Heart Rate: 8%  (was 10%)
- Blood Oxygen:       8%  (was 10%)
- Active Calories:    8%  (was 10%)
- Nutrition Balance: 12%  (NEW — net calorie target adherence)
- Mindful Minutes:    5%  (unchanged)
- Workout Minutes:    5%  (unchanged)
- Mood:               3%  (NEW — once mood tracking exists)
```

**Nutrition scoring:**
- Target: user-configurable daily calorie goal (default: 2,000 cal)
- Score 1.0: within 10% of goal
- Score decays exponentially for over/under eating
- Optional macro tracking (protein/carbs/fat) for future enhancement

**Files affected:**
- `LifeIndexScoreEngine.swift` (add `.dietaryCalories` metric type, rebalance weights)
- `HealthDataTypes.swift` (add new metric types)
- `DashboardView.swift` (nutrition card)
- New food logging views and services

#### Premium Tier Opportunity

| Free | Pro |
|------|-----|
| Manual calorie logging | AI photo-based estimation |
| Daily calorie total | Macro breakdown (protein/carbs/fat) |
| Basic nutrition card | Calorie trend charts |
| — | "Calorie balance vs. sleep quality" correlations |

This is a natural, clear-value premium feature that users understand.

---

## 12. Historical LifeIndex Scores (Today / Yesterday / Weekly)

### Problem

Currently the dashboard only shows today's (or yesterday's fallback) LifeIndex score. Users want to see their score trajectory over time.

### Proposed: Score Timeline View

#### On the Dashboard

Add a **mini score timeline** below the LifeIndex Score Card:

```
┌─────────────────────────────────────────────┐
│  Today's LifeIndex                          │
│         (83)                                │
│     ┌──────────┐                            │
│     │  Great   │                            │
│     └──────────┘                            │
│                                             │
│  ┌─── Score History ───────────────────┐    │
│  │  Mon  Tue  Wed  Thu  Fri  Sat  Sun  │    │
│  │  72   85   78   ──   91   83   ??   │    │
│  │  ●    ●    ●         ●    ●         │    │
│  │  Connected with a line chart        │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  Yesterday: 83 (Great)  |  7-day avg: 82   │
└─────────────────────────────────────────────┘
```

**Components:**
1. **Mini sparkline** — 7-day score trend as a small line chart (Swift Charts)
2. **Yesterday's score** — quick comparison label
3. **7-day average** — rolling average to smooth out daily variance

#### Data Requirements

**Current limitation:** LifeIndex score is calculated on-the-fly from today's/yesterday's metrics only. There's no persistent score history.

**Solution:** Calculate and store daily scores in Core Data:

```swift
// New Core Data entity
entity DailyScore {
    date: Date (unique, indexed)
    score: Int16
    label: String
    breakdown: Data // JSON-encoded per-metric scores
}
```

**Calculation strategy:**
- On each `loadData()`, calculate today's score (already done)
- Also calculate scores for each day in `weeklyData` (we already have the weekly summaries)
- Store/update in Core Data
- On next load, read from Core Data for the sparkline

**Files affected:**
- New Core Data entity `DailyScore` in `LifeIndex.xcdatamodeld`
- New `Core/Persistence/Models/DailyScore.swift`
- `DashboardViewModel.swift` — calculate + persist weekly scores, expose `weeklyScores: [DailyScore]`
- `DashboardView.swift` — new `ScoreHistoryMiniChart` component below the score card
- `LifeIndexScoreCard.swift` — optionally embed the sparkline, or keep as separate component

#### Future Extension: Monthly / Yearly View

Once daily scores are persisted, a dedicated "Score History" screen becomes straightforward:
- Monthly calendar heatmap (green/yellow/orange/red per day)
- 30-day / 90-day / 1-year trend line
- Personal records ("Your best week was Nov 12-18: avg 91")
- This is a natural Pro/premium feature

---

## Suggested Implementation Priority

### Immediate (Next Sprint) — UX Fixes & Core Polish

1. **Time-aware score scaling** — Fixes the biggest UX problem (alarming morning scores)
2. **Gentler score labels** — Quick win, improves emotional tone
3. **AI prompt rewrite** — Time-of-day templates, structured output, anti-verbosity rules
4. **Historical LifeIndex scores** — Today + yesterday + 7-day sparkline on dashboard
5. **Section header consistency** — Visual polish, small effort
6. **Weekly chart missing data indicators** — Fixes confusing blank bars

### Short-Term (2-4 Weeks) — Differentiators

7. **Score transparency sheet** — "How your score works" explainer with weights and ideal ranges
8. **Mood check-in UI** — Start collecting mood data (needs time to accumulate for correlations)
9. **Manual food/calorie logging** — Write to HealthKit, add nutrition card to dashboard
10. **Activity rings contrast fix** — Visual improvement

### Medium-Term (1-2 Months) — Intelligence Layer

11. **AI photo-based calorie estimation** — Foundation Models image analysis for food photos
12. **Nutrition in LifeIndex score** — Rebalance weights to include calorie balance
13. **Mood-based insights** — Once 7+ days of mood data exists
14. **Cross-metric correlation engine** — Needs 14+ days of historical data
15. **Anomaly detection** — "Your resting HR is 20% above your 30-day average"
16. **Monthly/yearly score history** — Calendar heatmap, trend lines, personal records

### Long-Term (3+ Months) — Growth & Revenue

17. **Revenue model implementation** — Based on retention data from free launch
18. **Premium features gating** — AI photo calories, correlations, PDF reports behind Pro
19. **PDF/CSV health reports** — Doctor-friendly format
20. **Training load + strain** — For fitness-focused segment
21. **Backend + sync** — Only when product-market fit is proven
22. **B2B2C exploration** — Employer wellness, insurance partnerships

---

## Technical Debt Notes

- `LifeIndexScoreEngine.weights` and `targets` are `private static` — need to be exposed (at least `internal`) for the score explainer sheet
- `buildScoreBreakdown()` in `DashboardViewModel` duplicates the `targets` dict from `LifeIndexScoreEngine` — should reference the engine's targets instead
- Mood logging Core Data model exists but has no associated ViewModel or View
- Weekly chart data uses `?? 0` for missing values, making "no data" indistinguishable from "zero"
- No persistent score history — LifeIndex score is computed on-the-fly each session; need Core Data entity for daily scores
- AI prompts lack time-of-day context — `buildShortPrompt()` and `buildDetailedPrompt()` don't pass current hour to the LLM
- `HealthKitManager` only has read types — food logging will require adding write types (`HKQuantityType(.dietaryEnergyConsumed)`)
- Score engine weights will need rebalancing when nutrition and mood metrics are added (currently totals 1.0 across 9 metrics)
- No `HealthMetricType` cases for nutrition-related data yet

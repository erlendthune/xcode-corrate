# Fartlek Audio Coach - Build Plan

## 1) Goal
Build a new standalone iOS app (App Store name: Fartlek Audio Coach) that keeps Corrate stable for existing users while enabling a cleaner architecture and focused fartlek experience.

App Store metadata direction:
- Name: Fartlek Audio Coach
- Subtitle: Heart Rate Interval Running

Primary outcomes:
- Preprogrammed fartlek sessions available out of the box.
- Users can create, edit, save, duplicate, and delete custom sessions.
- Audio coaching for interval transitions and heart-rate zone compliance.
- Settings moved to a dedicated settings view.
- Max/rest heart-rate configuration with optional auto-update when new extremes are observed.

## 2) Product Scope (MVP)
### In scope
- Connect to BLE heart-rate monitor.
- Run structured fartlek sessions with multiple blocks/segments.
- Segment format supports your pyramid use case (for example 6x 70-80%, 3x 75-85%, 1x 85-95%, then back down).
- Spoken cues:
  - Segment start/end.
  - Too high / too low guidance.
  - Optional periodic heart-rate announcement.
- Session library:
  - Built-in templates.
  - User-defined sessions.
  - Save and reuse.
  - Free and premium session tiers.
- Settings screen:
  - Audio on/off.
  - Voice speed.
  - Spoken interval cadence.
  - Heart-rate display mode (BPM / % max).
  - Rest/max baseline settings.
  - Auto-update policy for rest/max.

### Out of scope for first release
- Apple Watch app.
- Cloud sync.
- Social sharing.
- Advanced analytics dashboards.

## 2.1) Monetization Model (Confirmed)
- Purchase type: one-time purchase (non-consumable unlock).
- Keep Corrate purchase separate from new app purchase.
- Avoid recurring voice nagging as primary conversion mechanism.
- Use feature-based premium unlock, not crippled core behavior.

Free tier:
- Core BLE device connectivity.
- Run basic built-in sessions.
- Basic voice cues and pacing feedback.

Premium tier:
- Create/edit/save unlimited custom sessions.
- Advanced templates (pyramid, threshold progressions, custom blocks).
- Advanced audio coach controls and interval tuning.

Upgrade prompt strategy:
- Show contextual prompts after value moments (for example session completion or when user tries premium feature).
- No frequent interruption prompts during active training.

## 3) Proposed App Structure
Create a new app folder/workspace inside this repo to isolate it from Corrate.

Suggested top-level structure:
- FartlekAudioCoach/
  - App/
  - Features/
    - SessionLibrary/
    - SessionRunner/
    - Settings/
    - Devices/
  - Domain/
    - Models/
    - UseCases/
  - Services/
    - Bluetooth/
    - AudioCoach/
    - Persistence/
  - Resources/
  - Tests/

Rationale:
- Separation of concerns from day one.
- Keeps session logic testable and independent from UI.
- Reduces risk of another monolithic controller.

## 4) Data Model Proposal
### SessionTemplate
- id
- name
- description
- blocks: [SessionBlock]
- createdAt / updatedAt
- isBuiltin

### SessionBlock
- id
- repetitions
- lowerTargetPercent
- upperTargetPercent
- optionalWarmupSeconds
- optionalCooldownSeconds

### AppSettings
- audioEnabled
- voiceIdentifier
- voiceRate
- heartRateSpeakIntervalSeconds
- displayMode (BPM or Percent)
- restHeartRate
- maxHeartRate
- autoUpdateRestHeartRate (bool)
- autoUpdateMaxHeartRate (bool)

### TrainingSample (optional in MVP, useful soon)
- timestamp
- bpm
- percent
- segmentIndex

Persistence choice for MVP:
- Use Core Data or SQLite-backed lightweight store.
- If speed is critical, start with Codable + file store, but migrate early if history/analytics grow.

## 5) Core Behavior Rules
### Session progression
- Segment transitions must trigger immediately when threshold is reached.
- Use inclusive boundaries for target checks unless user chooses strict mode.
- Debounce transitions to avoid jitter from noisy readings.
- Confirmed default: require 2 consecutive qualifying beats before transition.
- Confirmed default: apply a 3-second transition cooldown after each transition.

### Heart-rate baseline updates
- Rest heart rate:
  - Only update if new measured value is lower and data confidence is high.
- Max heart rate:
  - Only update if new measured value is higher and confidence is high.
- Always allow manual override in settings.
- Keep audit metadata (last auto-update date/value).

### Audio priorities
- Safety and control cues first (too high/too low, segment change).
- Periodic readout second.
- Never delay a transition cue behind the periodic interval timer.

## 6) UI Plan
### Primary tabs/views
- Sessions
  - Built-in + custom session list.
  - Start, edit, duplicate, delete.
- Run
  - Current segment, repetition count, target zone, current HR, progress.
  - Prominent start/pause/stop.
- Settings
  - Audio settings.
  - Heart-rate baseline settings.
  - Device behavior preferences.

### Session Editor
- Name + notes.
- Block list with add/remove/reorder.
- Per-block repetitions and lower/upper percent.
- Live validation (for example lower < upper).

## 7) Technical Plan by Phase
### Phase 0 - Discovery and decisions (1-2 days)
- Finalize data model and persistence strategy.
- Confirm supported iOS version and SDK baseline.
- Confirm BLE device compatibility matrix.

### Phase 1 - Foundation (2-4 days)
- Scaffold new app target/folder.
- Implement domain models and persistence.
- Implement settings store.

### Phase 2 - Device + audio engine (3-5 days)
- BLE heart-rate input pipeline.
- Audio coach engine and message priority queue.
- Unit tests for boundary transitions.

### Phase 3 - Session library + editor (4-6 days)
- Built-in templates.
- CRUD for custom sessions.
- Pyramid session preset example.

### Phase 4 - Session runner (4-6 days)
- Real-time runner UI.
- Segment transition logic and immediate announcements.
- Pause/resume/stop behavior.

### Phase 5 - Hardening and release prep (3-5 days)
- Device testing and edge-case fixes.
- App Store metadata, privacy checks, test pass.

## 8) Test Strategy
### Unit tests
- Session transition conditions.
- Inclusive boundary checks.
- Repetition counting and completion.
- Auto-update rest/max rule logic.

### Integration tests
- BLE input to runner state transitions.
- Audio cue scheduling and priority.
- Persistence load/save for custom sessions.

### Manual tests
- Fresh install.
- No-device behavior.
- Interruption handling (phone call, background/foreground).
- Long run session (45-60 min) stability.

## 9) Migration and Coexistence Strategy
- Keep Corrate unchanged.
- New app has separate bundle identifier, assets, and App Store listing.
- Reuse proven BLE logic by extraction into a shared module used by both apps where practical.
- Avoid direct copy of monolithic controller structure; prefer service-oriented Swift modules.

## 9.1) Code Reuse Strategy From Corrate (Confirmed)
Goal: reuse tested heart-rate discovery and communication behavior while avoiding architecture carryover.

Step 1:
- Define Swift protocol interfaces in new app first (for example HeartRateService, DeviceDiscoveryService).

Step 2:
- Port behavior from Corrate HRMViewController BLE flow into isolated Swift infrastructure service(s):
  - scan/discover
  - connect/reconnect
  - characteristic subscription
  - heart-rate parsing
  - connection status events

Step 3:
- Add characterization tests around known behavior before optimizing internals.

Step 4:
- Keep session logic and UI independent from BLE implementation details.

## 10) Risks and Mitigations
- Risk: BLE variability across devices.
  - Mitigation: test matrix with at least 2-3 strap vendors.
- Risk: noisy heart-rate readings causing rapid cue churn.
  - Mitigation: transition debounce and cue cooldown windows.
- Risk: scope creep via analytics and social features.
  - Mitigation: strict MVP scope gate.

## 11) Critical Open Questions
1. Do we include haptic-only cue mode in MVP, or voice-only initially?
2. Should custom sessions support import/export (JSON) in MVP, or defer?
3. Should duration-per-block sessions be supported in MVP, or only repetition and HR target transitions?

## 12) Immediate Next Step
After answers to the open questions above, create the new app folder and scaffold the new target/workspace with the finalized architecture.

## 13) Confirmed Decisions (2026-08-14)
- Platform support: iPhone and iPad.
- UI approach: programmatic UI (no storyboard dependency for new screens).
- Session targeting: percentage and BPM only.
- Rest/max auto-update: opt-in only.
- If new higher/lower values are detected: show suggestion in settings and let user confirm before applying.
- Minimum iOS target: 26.
- Transition confirmation strategy: require 2 consecutive qualifying beats and apply 3-second post-transition cooldown.
- Monetization: one-time purchase with premium feature unlocks and contextual upgrade prompts.

No blocker decisions remain for scaffolding.
# Workout and Monitoring Architecture — Design Draft

**Date:** 2026-11-18  
**Status:** Proposed design; no production implementation authorized by this document.  
**Scope:** The active Swift app under `fartlekaudiocoach/`. `HeartMonitor/` is architectural history; `FartlekAudioCoachOld/` is an earlier Swift iteration, not the current implementation.

## 1. Problem definition and objective

The app has two overlapping representations of workouts, two persistence paths, and two editing paths. Monitoring and workout orchestration are attached to a screen-owned view model even though they must continue when that screen is not visible. Ownership rules and execution state are not enforced consistently across those paths.

The objective is to establish:

1. One canonical workout definition for standard and custom workouts.
2. Immutable standard workouts, with an explicit way to create editable custom copies.
3. One centrally enforced rule preventing workout changes during an active session.
4. A clear distinction between monitoring the sensor and executing a workout.
5. App-owned monitoring/coaching that supports locked-screen use within iOS constraints.
6. A clean cutover to one workout store without legacy-data migration.

This is not a wholesale rewrite, a framework migration, or a request to replace every delegate and dispatch queue. Preserve tested behavior and change ownership boundaries incrementally. The app is unpublished: existing development data does not require migration, legacy-format compatibility, or recovery. A reset of development workout data is acceptable at cutover.

### 1.1 Confirmed product requirements

| Requirement | Meaning |
|---|---|
| Standard workouts cannot be changed | Users can run them or create a new workout based on them; the original stays unchanged. |
| User-created workouts can be changed | Changes persist to that custom workout when no session is active. |
| No session editing after starting | The active workout definition cannot be edited while executing. |
| Completion ends the workout | Monitoring and normal heart-rate announcements continue afterward. |
| Monitoring continues outside the screen | Locking the phone or switching apps must not intentionally stop monitoring. |
| Sensor loss does not pause the session | Elapsed time continues; measurement-dependent progression waits for fresh data. |

### 1.2 Proposed policies requiring explicit sign-off

- Apply the editing lock to **all workout creation, copying, editing, saving, deletion, and selection**, not just the running workout. Browsing remains allowed. This is intentionally stricter than only freezing the active definition.
- Preserve the existing restriction against deleting the selected workout, even when idle. Selecting another workout makes deletion available.
- Permit audio, voice rate, announcement interval, and display-unit changes during a run. Freeze the maximum-heart-rate baseline for that run; changes to maximum HR apply to the next run. This differs from current behavior and must be approved.
- Do not add process-termination recovery in the initial change. A later recovery feature would require a separate persisted execution checkpoint, not just a saved workout definition.
- Do not change purchase products or introduce new premium restrictions as part of this refactor.

### 1.3 Non-goals

Apple Watch execution, cloud sync, workout history, new interval algorithms, artificial background activity, and changes to the Objective-C application are out of scope. Migration of development workout data or Objective-C-era settings and purchases is not required.

## 2. Current architecture and its Objective-C ancestry

### 2.1 Responsibility mapping

| Responsibility | Original Objective-C | Current Swift | Proposed boundary |
|---|---|---|---|
| Startup and service ownership | `HRMAppDelegate`, storyboard controller lifecycle | SwiftUI app → `RootTabView` → `AppEnvironment` | App entry owns one environment; environment owns long-lived coordinator and services. |
| Bluetooth | `HRMViewController` implements central/peripheral delegates and parses samples | `CoreBluetoothHeartRateService` implements delegates behind `HeartRateService` | Keep adapter; coordinator is its single application consumer. |
| Workout progression | Controller properties and `HRMFartlekState` | `DefaultSessionEngine` emits typed cues | Keep deterministic state machine; expose explicit execution status separately from presentation text. |
| Audio | Controller speech synthesis plus app-delegate audio setup | `AVSpeechAudioCoach` owns synthesizer, audio session, interruptions, recovery | Keep platform adapter; coordinator decides what to request and when. |
| Editing | `HRMFartlekViewController` reads inputs and calls the main controller | Modern pyramid editor plus legacy `SessionDetailView` | One draft-based custom editor and a read-only standard-workout detail screen. |
| Persistence | Flat `NSUserDefaults` settings, including one fartlek configuration | Settings store plus `workouts.json` and `sessions.json` | Settings stay separate; one versioned custom-workout store. |
| UI updates | Outlets and imperative controller mutation | SwiftUI, `ObservableObject`, `@Published`; UIKit heart animation bridge | Views present shared state; they do not own monitoring lifetime or enforce policy alone. |
| Purchases | `IAPHelper` / `HRMAPHelper` | StoreKit 2 `PurchaseManager` | Preserve existing entitlement/reminder behavior. |

Modern Swift here means explicit ownership, value models, validated operations, and isolated mutable state—not merely replacing Objective-C syntax with Swift or replacing every callback with an async stream.

### 2.2 Verified current behavior and gaps

- `PyramidWorkout` / `HeartRateInterval` serve the modern editor and `WorkoutStorageManager`. `SessionTemplate` / `SessionBlock` serve execution and the legacy file/editor path.
- `PyramidWorkout.asSessionTemplate()` preserves workout/block identity and percentages, but cannot represent the other model's notes, premium metadata, or warmup repetitions in reverse.
- Standard workouts exist in both `PyramidWorkout.standardTemplates` and `BuiltinSessions.all`, with different catalogs. Modern template UUIDs are generated rather than stable across launches.
- The modern editor already creates a custom copy when saving a built-in. The storage API itself still accepts arbitrary ID-based updates. The legacy detail screen can replace a built-in entry directly.
- `WorkoutStorageManager` seeds standard templates into user storage, while selection screens also expose the code-defined catalog. Its main-actor synchronous file I/O also blocks UI work.
- `RunnerHomeView` creates `RunnerViewModel` as a `StateObject`. The model subscribes to Bluetooth callbacks, holds timers, watches lifecycle notifications, formats speech, saves settings, protects deletion, and runs the engine.
- The engine snapshots the selected session at start, but the selected session remains mutable afterward. The UI can therefore describe something other than the executing workout.
- `.sessionCompleted` is spoken without clearing `RunnerViewModel.isRunning`. Reusing manual stop is not a correct completion fix: it announces a stop and deactivates coaching.
- Speech cadence is already driven by fresh samples and an injected uptime clock. Countdown timers are display-only. Preserve this distinction.
- Warmup uses sample dates; data freshness uses receipt-time dates. `SessionBlock.warmupRepetitions` exists but is not consumed by the current engine.
- Current Bluetooth and audio adapters are implemented, not stubs. `AppInfo.plist` declares both `audio` and `bluetooth-central` background modes.

## 3. Proposed domain and ownership model

### 3.1 Canonical workout

Introduce `Workout` and `WorkoutBlock` value types, usable by catalog, editor, persistence, and engine. The run snapshot is the same definition plus execution-specific context—not another independently authored workout schema.

Workout fields:

- Stable workout ID, name, notes, exact warmup duration in seconds, and ordered blocks.
- Explicit origin: catalog-owned or custom. A catalog ID must be reserved and cannot be written through custom storage.
- Creation metadata for custom workouts and an optional source-template ID for provenance.
- Entitlement decisions remain outside the editable workout definition; no legacy premium metadata needs to be carried forward.

Block fields:

- Stable block ID, repetitions, lower target percent, and upper target percent.
- No legacy warmup-repetition field: the current engine does not implement that behavior.

Store one warmup duration, not mutable minutes plus mutable seconds. Minutes are display/input formatting. Percentages are canonical; display-mode changes must never change progression.

Validation applies at construction/decoding and before persistence/execution: nonblank name, nonnegative duration, nonempty blocks, positive repetitions, valid percentage ranges, and lower target below upper target. Apply bounded numeric decoding so malformed values cannot overflow conversions or create invalid SwiftUI ranges.

Keep the six-block limit for canonical workouts initially. Legacy development sessions, including oversized sessions and configurations with warmup repetitions, do not need to be imported or supported.

### 3.2 Standard catalog and custom storage

`StandardWorkoutCatalog` owns the four modern standard workouts with fixed IDs checked into source. Catalog content is not persisted as editable user data. App updates may revise catalog content; running snapshots remain unaffected.

Custom-workout persistence holds only custom definitions. Favorites are user preferences associated with workout identity, not changes to catalog content. Initially retain the existing custom-favorite feature; making standard workouts favoritable is not required for this work.

Copy rules:

- **Create a Copy** opens an unsaved custom draft, named “<original name> — Copy”. Duplicate names are allowed; identity never depends on names.
- Assign a fresh workout ID and fresh block IDs once when the draft is created. Retry uses those IDs to prevent duplicate saves.
- A copy has custom ownership and a new creation date; retain source-template provenance when applicable.
- A copy starts unfavorited. This is a proposed change from the editor's current favorite inheritance.
- Canceling a draft does not write anything. Saving updates the draft's saved baseline only after persistence succeeds.
- Saving edits to an existing custom workout preserves its identity. **Save as New** follows copy rules.

Catalog ownership is enforced by the application command boundary and checked defensively by persistence; it must not rely on hiding an Edit button or trusting an editable Boolean.

### 3.3 Session state and monitoring state are separate

Define execution states: **idle**, **running**, **completed**, and **stopped**. Running carries a run ID, immutable workout snapshot, fixed maximum-HR baseline, and start-time context. Internal engine phases remain warmup/speedup/slowdown/etc.

Connection and freshness are separate state dimensions. A running session can be disconnected or missing data without becoming paused or stopped.

| Event | Workout result | Monitoring result |
|---|---|---|
| Start | Validate selection and fresh data; snapshot definition and baseline; enter running | Continue existing connection and monitoring. |
| Sensor loss | Remain running; elapsed time continues | Clear stale display, warn when possible, request reconnect. |
| Complete | Enter completed exactly once; release workout lock; preserve final cue | Continue pulse announcements, connection, and recovery. |
| Manual stop | Enter stopped; release lock; announce stop once | Continue monitoring; do not treat this as disconnect. |
| View disappears / screen locks | No execution transition | Continue supported background operation. |
| Process terminates | In-memory execution ends | No promise of continued execution. |

The engine should expose execution status/progress as structured data. A completion cue is an event; a localized string is not an authoritative state signal. After a terminal transition, do not feed subsequent samples into that run.

## 4. Application ownership and UI behavior

### 4.1 App-owned coordinator

Create a main-actor `MonitoringCoordinator`, constructed once by `AppEnvironment`, owning:

- The single subscription to heart-rate service callbacks.
- Connection/freshness state, announcement policy, sample normalization, and warning scheduling.
- The session engine and active-run state.
- App lifecycle hooks and finite background assertions needed for missing-data detection.
- Explicit start, stop, and select operations.

`RunnerViewModel` becomes a presentation adapter rather than the owner of hardware or execution lifetime. `RunnerHomeView` receives shared dependencies; reconstructing a screen must not replace subscriptions or reset a running session.

The app entry point owns the environment as a `StateObject` and passes it into `RootTabView`. Root splash visibility must not control service initialization or claim readiness after an arbitrary delay. Use explicit loading/ready/error state for preferences and library loading. Retain the muted-before-preferences-loaded guarantee.

Do not move the existing monolith unchanged into a renamed coordinator: storage, editor drafts, and audio-session implementation remain separate responsibilities.

### 4.2 Authoritative edit lock

Create a main-actor `WorkoutLibrary` application facade that combines catalog display, custom-store state, selection policy, and mutation commands. It consults the coordinator's execution state without a circular ownership dependency; the environment wires a read-only state provider.

- Running sessions reject mutation and selection commands with a typed `sessionRunning` error.
- Views show the same capability state and explain “Stop the session to edit workouts.”
- A draft already open when a run starts stays visible but becomes read-only; do not discard unsaved work.
- Starting while an editor has unsaved work requires saving/discarding or closing that editor first. The command boundary still handles stale UI and concurrent requests safely.
- Completion or manual stop restores capabilities without reopening screens.
- Consolidate duplicate picker behavior into one list/detail flow. A standard detail offers **Use Workout** and **Create a Copy**; it never presents mutable standard fields.
- Replace competing Boolean sheet states with a typed presentation destination where this flow is touched; avoid an unrelated navigation rewrite.

## 5. Timing, sensor gaps, and background execution

### 5.1 Time semantics

Use an injected elapsed-time clock based on `ContinuousClock` (including device sleep) for warmup, sample receipt freshness, speech cadence, and reminders. Keep `Date` for wall-clock metadata only. The existing uptime injection remains a compatibility seam while tests move to a shared clock abstraction.

Warmup starts when the validated Start command succeeds, not on the next sensor callback. Sensor gaps count toward elapsed warmup time. If no execution opportunity occurs at the deadline, reconcile on the next wake/sample; do not claim that a timer must fire while suspended.

After reconnection, skip obsolete minute announcements. Use the first fresh sample to evaluate the current phase, without manufacturing historical threshold crossings or completing multiple repetitions from a single reading. Preserve the current iteration algorithm unless separately approved; changing sample-to-phase sequencing requires explicit test updates.

Preserve the current 3-second display freshness threshold and approximately 9.5-second warning cadence initially. Fresh transport connection alone does not clear a missing-data warning; a positive fresh reading does. Zero readings do not refresh availability.

### 5.2 Limits of “always running”

The user intent is continuous monitoring until quitting. iOS does not provide an unconditional continuously executing process. The system can suspend, terminate, deny Bluetooth access, or interrupt audio. A foreground app can also lose its sensor.

The supported contract is: **do not intentionally stop monitoring because of navigation, locking, backgrounding, workout completion, or manual workout stop; use legitimate Bluetooth/audio execution opportunities and reconcile after suspension.**

- Retain the declared audio and Bluetooth-central background modes.
- Do not play silent audio, spin timers, or repeatedly renew background tasks to evade suspension.
- A missing-sensor warning in the background is best-effort once finite background time expires. Never present it as a guaranteed safety alarm.
- Bluetooth state restoration can be evaluated separately. It is not a substitute for restoring application execution state and does not guarantee recovery after user force-quit.
- Existing explicit monitor-disconnect functionality needs product clarification: recommended meaning is “stop this connection and automatic reconnect,” not “shut down the app.” If monitoring must have no user stop control at all, its UI must be reconsidered explicitly.

## 6. Concurrency and threading strategy

### 6.1 Isolation boundaries

| Work | Execution/isolation |
|---|---|
| Observable state, command policy, coordinator, small engine transitions | Main actor; synchronous state transitions. |
| Workout JSON reads/writes | Dedicated repository actor with serialized operations. |
| Settings persistence | Actor-isolated store; preserve save ordering. |
| CoreBluetooth delegate delivery | Preserve configured main-queue adapter; bridge callback isolation deliberately. |
| Blocking `AVAudioSession` activation/deactivation | Preserve existing dedicated serial GCD queue. |
| Speech callbacks / notification delivery | Hop once to owning main-actor adapter before mutating state. |

The project enables `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and approachable concurrency with Swift language mode 5.0. Explicitly audit model/Codable/helper isolation and `Sendable` conformance before crossing to repository actors. Use toolchain-supported nonisolated declarations where needed; do not globally change language mode or silence issues with new `@unchecked Sendable` declarations.

`async` does not mean background execution. Wrapping synchronous file I/O in `Task { @MainActor in ... }` still blocks the UI. Likewise, replacing a dispatch queue with a task does not make blocking audio-session calls nonblocking. GCD remains appropriate for that serialized platform work; async/await is appropriate for application workflows and actor-based storage.

### 6.2 Preventing mutation/start races

Actor isolation alone does not make workflows atomic across `await`.

1. A mutation validates capability and reserves a library-mutation token on the main actor before awaiting persistence.
2. Start rejects while that reservation exists. A mutation rejects while a run exists. These checks occur before either operation suspends.
3. Repository writes are serialized; reject a second editor's stale revision rather than silently overwriting newer content.
4. Publish committed state after durable success, then release the reservation on every exit path.
5. Deletion also reserves the operation; selection cannot change underneath its selected-workout check.

Keep reservations minimal and visible as a busy state. A run need not wait for unrelated preference saves. Do not let a canceled view task release a reservation while an underlying write is still committing: once a repository commit starts, resolve its outcome before unlocking. UI dismissal may stop waiting for presentation, not undo a durable transaction.

Retain request/generation IDs for late Bluetooth/audio completions. Preserve weak observer captures, explicit timer cancellation, finite background-task expiration handling, and one lifecycle-registration owner. Avoid one unstructured task per sample when callbacks can be processed synchronously on the main actor.

## 7. Persistence, compatibility, and error handling

### 7.1 Versioned custom library

Introduce `Documents/workout-library.json` with an explicit schema version, custom workouts, and revisions. A missing file means an empty custom library; an empty file collection is not a request to seed standards. Standards are always supplied independently by the catalog, including when custom storage is unreadable.

### 7.2 Clean development-data cutover

The app is unpublished, so no migration from `workouts.json`, `sessions.json`, or the Objective-C app is required. The new repository reads only `workout-library.json`. Existing development workout files may be ignored; resetting development workout data at cutover is acceptable.

Do not implement compatibility decoders, legacy backups, import mappings, deduplication, migration metadata, or a legacy-data recovery UI. Remove obsolete models and storage paths after their live callers and tests have moved to the canonical model. Do not dual-write.

Normal error handling still applies to the new store. Unknown future schema versions must not be overwritten. Offer an explanatory error, preserve the file, keep the catalog usable, and disable custom writes until the storage error is resolved.

### 7.3 Errors and recovery

- Use typed application errors: `sessionRunning`, `libraryBusy`, `standardWorkoutReadOnly`, `selectedWorkout`, `validationFailed`, `staleRevision`, and storage errors carrying underlying causes.
- Show validation errors next to the relevant field. Keep drafts and dirty state after save failure; do not dismiss or select an unsaved result.
- For read/decode errors, retain last known-good in-memory state, publish an actionable error, and offer retry/export. Never replace unreadable data with an empty list and then save over it.
- Perform writes with atomic replacement. Surface disk-full, file-protection, and permission errors; retry after unlock where appropriate without promising a save occurred.
- Treat Bluetooth permission denial, radio-off, connecting, and connected-but-not-receiving as distinct user-facing conditions. Peripheral connection is not proof of notification readiness.
- Log audio failures and preserve non-audio monitoring. Drop stale automatic pulses rather than queueing them for later; retain existing instruction-over-pulse priority and no catch-up reminder behavior.
- Avoid swallowing persistence failures with `try?` and displaying an apparently empty successful library.

## 8. Exact file impact

Paths below are repository-relative. `A` means `fartlekaudiocoach/fartlekaudiocoach/`; `T` means `fartlekaudiocoach/fartlekaudiocoachTests/`; `U` means `fartlekaudiocoach/fartlekaudiocoachUITests/`. These are planned changes, not changes made by this document.

### 8.1 Existing production files to change

| Exact path | Planned change |
|---|---|
| `A/fartlekaudiocoachApp.swift` | Own and inject one app-lifetime environment. |
| `A/AppEnvironment.swift` | Compose coordinator, workout library, actor repository, catalog, clock, and existing adapters; remove duplicate selected-session state. |
| `A/RootTabView.swift` | Receive environment; replace timer-based readiness with observable startup state. |
| `A/Domain/Models/PyramidWorkout.swift` | Move model/catalog responsibilities to canonical files; remove once callers and tests are updated. |
| `A/Domain/Models/HeartRateInterval.swift` | Replace with `WorkoutBlock`; remove once callers and tests are updated. |
| `A/Domain/Models/SessionTemplate.swift` | Replace with the canonical workout model; remove once callers and tests are updated. |
| `A/Domain/Models/HeartRateSample.swift` | Separate raw measurement/date metadata from derived percent and receipt-time freshness semantics; make transfer isolation explicit. |
| `A/Domain/Services/SessionEngine.swift` | Accept canonical workout/run context and elapsed time; expose structured status/progress. |
| `A/Domain/Services/SessionStore.swift` | Remove after callers use the canonical repository. |
| `A/Domain/Services/SettingsStore.swift` | Align actor-safe settings transfer contracts and preserve ordering. |
| `A/Domain/UseCases/DefaultSessionEngine.swift` | Consume canonical definition and elapsed durations; explicit terminal status; preserve interval algorithm. |
| `A/Features/Runner/RunnerViewModel.swift` | Move lifecycle/execution ownership to coordinator; retain presentation formatting and commands routed to shared owners. |
| `A/Features/Runner/RunnerHomeView.swift` | Observe shared state; remove legacy editor conversion/picker duplication; enforce capabilities and unified destinations. |
| `A/Features/Runner/AppMenuView.swift` | Route workout screens through shared library/coordinator instead of separate stores. |
| `A/Features/HeartRateMonitor/HeartRateMonitorView.swift` | Observe shared monitoring state and route connection commands without owning subscriptions. |
| `A/Features/Sessions/PyramidWorkoutEditorModel.swift` | Use canonical drafts; route validated async commands through library; preserve draft on errors/locks. Keep filename initially to avoid rename-only churn. |
| `A/Features/Sessions/PyramidWorkoutEditorView.swift` | Custom editing only; explicit save/copy semantics, busy/locked UI, and notes. |
| `A/Features/Sessions/SessionDetailView.swift` | Replace legacy mutable session editor with unified read-only detail and explicit custom-edit/copy actions. |
| `A/Features/Sessions/SessionsHomeView.swift` | Use unified library and visible load/error state; remove legacy storage path. |
| `A/Features/Sessions/WorkoutTemplateSelectionView.swift` | Become shared catalog/custom picker; capabilities, stable IDs, and standard read-only detail. |
| `A/Features/Settings/SettingsHomeView.swift` | Explain maximum-HR next-run policy if approved; keep allowed audio/display settings live. |
| `A/Infrastructure/Persistence/WorkoutStorageManager.swift` | Replace callers with library/repository operations, then remove the obsolete store; no compatibility facade is required. |
| `A/Infrastructure/Persistence/FileSessionStore.swift` | Remove after callers use the canonical repository; do not retain a legacy import path. |
| `A/Infrastructure/Settings/UserDefaultsSettingsStore.swift` | Replace unchecked shared-state assumptions with isolated persistence; preserve existing preference/device keys. |
| `A/Infrastructure/Bluetooth/CoreBluetoothHeartRateService.swift` | Emit raw BPM without deriving percent from default max HR; preserve delegate/reconnect behavior and audit readiness/error publication. |

### 8.2 New production files

| Exact path | Responsibility |
|---|---|
| `A/Domain/Models/Workout.swift` | Canonical workout and block value types, origin, and validation. |
| `A/Domain/Models/WorkoutRun.swift` | Immutable run snapshot, run identity, execution status and fixed physiological baseline. |
| `A/Domain/Models/StandardWorkoutCatalog.swift` | Single standard catalog with permanent IDs. |
| `A/Domain/Services/WorkoutRepository.swift` | Async typed repository operations and revision/error contracts. |
| `A/Domain/Services/ElapsedTimeClock.swift` | Injectable elapsed-time abstraction and deterministic test seam. |
| `A/Application/MonitoringCoordinator.swift` | App-owned monitoring/execution/lifecycle orchestration. |
| `A/Application/WorkoutLibrary.swift` | Observable catalog/custom state and authoritative workout command policy. |
| `A/Infrastructure/Persistence/FileWorkoutRepository.swift` | Actor-isolated versioned storage, atomic commits, serialized revisions. |
| `A/Infrastructure/Time/ContinuousElapsedTimeClock.swift` | Production continuous-clock implementation. |

### 8.3 Existing tests to update

| Exact path | Coverage changes |
|---|---|
| `T/fartlekaudiocoachTests.swift` | Shared clock/coordinator seam; completion and monitoring independence; retain speech/freshness/priority guarantees. |
| `T/PyramidWorkoutTests.swift` | Canonical invariants, fixed catalog identity, copy identity, and bounded decoding. |
| `T/PyramidWorkoutEditorTests.swift` | Explicit custom drafts, copy defaults, async save failures, stale revisions and edit locks. |
| `T/PyramidWorkoutEditorUITests.swift` | Not present here; UI tests are under `U` below. Do not create a duplicate unit-test file. |
| `T/ActiveWorkoutDeletionTests.swift` | Global running lock plus existing idle selected-workout protection. |
| `T/WorkoutStorageManagerTests.swift` | Empty custom storage independent of catalog; async atomic persistence and recovery. |
| `T/UnsavedWorkoutChangesTests.swift` | Read-only transition retains draft; failed save/dismissal rules. |
| `U/PyramidWorkoutEditorUITests.swift` | Read-only standard detail, explicit copy, custom editing, running-state restrictions. |

Add `T/WorkoutLibraryTests.swift`, `T/MonitoringCoordinatorTests.swift`, and `T/SessionLifecycleTests.swift` for the acceptance criteria below. No migration tests are required. Keep UI injection deterministic; do not require a physical BLE device for UI edit-lock tests.

### 8.4 Reviewed boundaries with no planned production edits

- `A/Infrastructure/Audio/AVSpeechAudioCoach.swift`: retain the dedicated audio-session queue, interruption recovery, stale-pulse dropping, and finite speech assertions. The coordinator must use its existing API correctly; adapter changes require a demonstrated gap, not architectural fashion.
- `A/Infrastructure/Purchases/PurchaseManager.swift`: preserve product and entitlement behavior; entitlement checks remain separate from workout definitions.
- `A/Features/Sessions/WorkoutDismissalGuard.swift`: reuse existing dismissal protection unless tests expose an async-save integration gap.
- `A/ContentView.swift`, `A/Features/Runner/AppMenuSheet.swift`, `A/Features/Runner/HeartRateZonesContent.swift`, and `T/HeartRateZoneTests.swift`: no intended behavior change.
- `fartlekaudiocoach/AppInfo.plist`: already declares the required background modes; verify the built app's merged plist rather than adding redundant entries.
- `fartlekaudiocoach/fartlekaudiocoach.xcodeproj/project.pbxproj`: uses file-system-synchronized groups. New Swift files should be discovered automatically; change only if actual target membership/build verification requires it. No language-version/deployment-target change is proposed.
- No changes to `HeartMonitor/`, `HeartMonitor.xcodeproj/`, or `FartlekAudioCoachOld/`.

## 9. Edge cases and acceptance criteria

1. A standard workout cannot be updated/deleted through either UI or direct library/repository commands. Its fixed ID remains identical across launches.
2. Copying produces an independent custom identity. Editing/saving the copy never changes its source. Retry does not create duplicates; cancel writes nothing.
3. A custom workout can be edited while idle. All proposed workout mutations and selection reject while running, including commands from an editor opened earlier.
4. A save/delete already committing prevents start; a started run prevents commit admission. Errors and cancellation cannot leave the app permanently busy.
5. Completion and manual stop each transition once, release locks, and leave monitoring active. Completion does not announce a manual stop or deactivate required audio.
6. Rebuilding/navigating away from the runner screen cannot recreate the coordinator, overwrite service callbacks, or reset the active run. Multiple scenes, if enabled, share one run and cannot start competing engines.
7. Warmup crosses its deadline during sensor loss; recovery uses current elapsed time and a fresh reading. There is no replay of missed minute messages or invented interval crossings.
8. Changing wall-clock time cannot change elapsed warmup/freshness/cadence. Test sleep/suspension semantics with a controllable clock, not real sleeps.
9. Preserve existing behavior: zero sample rejection, warning persists through reconnect until fresh data, 3-second display expiry independent of speech interval, interval-zero sample-driven speech, busy-pulse drops consuming an interval, instruction priority, and silent startup until preferences load.
10. The new store handles missing files, intentional empty collections, corrupt JSON, invalid values, duplicate names, identity conflicts, notes, and exact-second warmups. Legacy development files are not loaded, and missing custom storage never seeds editable standards.
11. Disk full, locked-device file protection, canceled presentation, and future schema versions cannot overwrite the last committed library or falsely report success.
12. Audio setting changes remain live. If the proposed frozen-max-HR policy is approved, revise the existing mid-run max-HR test explicitly; display-unit toggles remain lossless and never speak an extra instruction.

### Device validation (not replaceable by unit tests)

Run with a real BLE monitor: locked-screen workout, background music mixing, out-of-range return, radio off/on, headphones disconnect, call interruption, long sensor gap, and return after OS suspension. Record observed warning limitations and energy behavior. Separately test system termination and user force-quit; neither should be described as supported uninterrupted execution. Validate with audio both enabled and muted.

## 10. Implementation sequence and outstanding decisions

1. Approve policies in section 1.2 and explicit-disconnect behavior. No legacy-data migration or imported-workout policy is needed.
2. Add characterization tests and canonical value/catalog/clock definitions without switching live persistence.
3. Implement and test the versioned repository, validation, revisions, atomic writes, and storage failures. Use a clean custom library without reading legacy development files.
4. Introduce app-owned coordinator and terminal session handling; keep engine progression behavior stable.
5. Route every workout operation through the authoritative library lock; migrate picker/detail/editor paths together so no writable legacy back door remains.
6. Switch to canonical execution and continuous elapsed time; intentionally update affected tests and validate on device.
7. Remove obsolete models, stores, and editor dependencies after successful cutover. No compatibility decoders, migration backups, or temporary storage facades are required.

The highest-priority unresolved questions are not class names: they are whether the edit lock is global, whether max HR is frozen per run, and what explicit disconnect means. Do not let these become accidental behavior during implementation. Legacy-data migration is explicitly out of scope because the app is unpublished.

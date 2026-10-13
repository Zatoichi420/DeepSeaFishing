# My Fishing Game

New iOS app: a sensor-driven, accessibility-first **deep sea fishing** game. VoiceOver
users and sighted users play the exact same core loop — no separate "accessibility mode."

## Concept

**Arcade style**: you're competing to catch the single largest fish you can. You're out
on a boat in open ocean, targeting big game fish — marlin, swordfish, tuna — not casual
pond/dock fishing. The differentiator from the browser-game inspiration below is the
*fight*: these species are known for long, violent fights (runs, jumps, dives), so the
reel-in struggle is the centerpiece, not a quick tap sequence.

Rough species behavior ideas (to prototype against, not final):
- **Marlin** — long fast runs, dramatic tailwalk/jump haptic bursts mid-fight.
- **Swordfish** — deep dives, heavy sustained tension, thrashing near the boat.
- **Tuna** — raw sustained pull strength, tests stamina/timing more than technique.

Each species should feel mechanically distinct through haptics + audio + timing, not
just a different name/sprite.

### Arcade run structure

- A run = a fixed number of casts (currently 4). Land the biggest fish you can before
  you're out of casts.
- Local high score only (no Game Center/leaderboard) — persisted on-device via
  `UserDefaults` (heaviest fish ever landed, by weight + species).
- Before each cast: **pick a target species, then pick your gear.** Real offshore
  tackle differs a lot by species (see below) — picking the *wrong* kit for the fish
  you're targeting makes the fight measurably harder (more frequent/stronger runs,
  weaker reel-in progress per action), rather than just being flavor text. This is
  deliberate: the game teaches real gear-to-species matchups through the difficulty
  curve, not just a tooltip.

### Real-world gear per species (researched 2026-08-12)

Grounded in actual offshore/big-game tackle conventions:

- **Tuna — Trolling Outfit**: 50–80 lb class trolling rod, lever-drag conventional
  reel (e.g. Shimano Tiagra / Penn International 50), 50–80 lb mono topshot over
  braided backing, skirted trolling lure or rigged ballyhoo on a circle hook.
- **Marlin — Heavy Trolling Outfit**: 50–130 lb class stand-up or bent-butt rod,
  large-capacity lever-drag reel (600–900m line capacity), straight braid/mono
  backing with a long wind-on mono leader, large skirted lure spread or rigged
  ballyhoo.
- **Swordfish — Daytime Deep-Drop Outfit**: swordfish sit 1,500–2,000 ft down during
  the day, too deep to hand-crank — so this is the one species that *requires* a
  fundamentally different tool: an **electric reel** (e.g. Lindgren-Pitman,
  Hooker Electric), 80–100 lb class rod with a soft tip and bent butt, 80 lb braid
  with a 100–150 ft fluorocarbon leader, rigged squid/bonito strip bait with glow
  lights on the leader.

Source research: fishingbooker.com, marlinmag.com, tackledirect.com,
saltwatersportsman.com (see chat for full query trail if needed).

## Origin / inspiration

Inspired by a concept described in a forum post about a browser game called
*Bites & Baits* (AudioGames.net, posted by Haramir, 2026-07-16). That project is
someone else's original work — this project does **not** decompile, copy, or reuse
its code. We're building our own native iOS implementation from scratch, taking only
the high-level *ideas* as a jumping-off point, then diverging with our own mechanics,
art direction, and feature set.

Ideas worth drawing on (concepts only, not code):
- Tilt-based control: tilt forward to cast, tilt back to reel, shake to set the hook.
- Distinct haptic patterns per game state (bite, line tension, line snap).
- Procedurally generated audio (water, reel, bite, snap) instead of sound files.
- Native screen reader as the narrator, driven by live announcement regions.

## Platform / stack (native iOS, our own build)

- Swift + SwiftUI (or UIKit if VoiceOver control ends up needing finer-grained focus
  management — decide once we're into the UI).
- **CoreMotion** for tilt/gyroscope input (cast/reel/hook).
- **CoreHaptics** for state-based vibration feedback (bite, tension, snap).
- **AVAudioEngine** for procedural sound synthesis (no audio file assets).
- VoiceOver-first: accessibility announcements drive game state changes, matching
  the "native screen reader as narrator" idea, but built as a first-class iOS
  accessibility experience (`UIAccessibility.post(notification:)`, proper
  `accessibilityLabel`/`accessibilityValue` on live elements) rather than a web
  `aria-live` region.

## Status

- 2026-08-12: Project created, concept locked (arcade deep sea / big game fishing:
  marlin, swordfish, tuna, racing for the biggest single catch). Xcode project
  scaffolded via XcodeGen (`project.yml`, target `DeepSeaFishing`, bundle id
  `com.orlandojohnson.DeepSeaFishing`).
- 2026-08-12: First playable arcade loop implemented and confirmed building for iOS
  Simulator: idle → choose species → choose gear (real-world kits, mismatch makes
  the fight harder) → cast → fight (Reel In / Ease Line vs. a tension + progress
  meter, with per-species run behavior) → result → run summary after 4 casts, with
  a persisted local best-catch record.
- 2026-08-12: Added CoreMotion tilt control and CoreHaptics feedback (see below).
  Buttons still work alongside tilt — needed for Simulator (no CoreMotion there)
  and as a fallback/preference. Procedural audio (AVAudioEngine) still not started.
- 2026-08-13: Confirmed building and installing on a physical device (iPhone 15)
  via `xcodebuild -destination 'platform=iOS,name=iPhone'` + `xcrun devicectl`.
  Fixed a `UIRequiresFullScreen` warning (portrait-only orientations needed it).
- 2026-08-13: Added a 6-step onboarding tutorial (`OnboardingView.swift`), shown
  automatically on first launch and replayable anytime via a "How to Play" button
  on the home screen. Each step moves VoiceOver accessibility focus to the new
  step's title automatically so screen reader users don't have to swipe back to
  the top after Next/Back. Completion persisted via `UserDefaults`.
- 2026-08-13: Added real reference imagery for sighted players (see "Visual assets"
  below). Confirmed rendering correctly on iOS Simulator via screenshot (the wave
  hero image on the onboarding welcome step: clean crop, correct aspect fill,
  readable text below it — same code pattern is reused on the other 3 placements).
  **Not yet pushed to the physical iPhone** — Orlando is away from the Mac (at
  work), and mid-session the device dropped from `connected` to `unavailable` in
  `devicectl list devices`, almost certainly because the phone left with him, not
  a build/pairing problem. Xcode project builds clean; next session, plug the
  iPhone back in and re-run the device install/launch steps (see Build & Run
  below) — no code changes needed first.
- 2026-08-13: Added procedural game audio via `AudioManager.swift` (see "Audio"
  below) — a looping ocean ambience plus one-shot synthesized sounds for reel
  clicks, easing line, bites, species-specific runs, landing, and snapped lines.
  Unlike CoreMotion/CoreHaptics, `AVAudioEngine` runs on Simulator, so this was
  installed and launched on the Simulator to confirm `engine.start()` doesn't
  throw and the app doesn't crash (it doesn't — verified via screenshot + a
  running-process check). **Sound quality/balance is completely unverified by
  ear** — Claude has no way to hear the output, only to confirm it doesn't crash.
  Needs real listening feedback next time Orlando is at the phone.
- 2026-08-20: **Accessibility audit + fixes** (3 parallel agents covering UI
  code, sensory/gameplay mechanics, and design-intent-vs-code gaps), after
  Orlando confirmed tilt control and haptics both genuinely work on-device —
  this closed out the top open item from 2026-08-13. Fixes: focus management
  added to every screen transition (`@AccessibilityFocusState`, matching the
  pattern `OnboardingView` already had); a real unfair-timing bug fixed in
  `GameViewModel.tick()` where a fish's run could spike tension to the snap
  threshold in the same tick its haptic/audio cue started (0ms reaction time);
  a new sonar-style audio "progress pulse" (`AudioManager.playProgressPulse`)
  giving a blind player a real-time channel for line-to-shore progress, not
  just tension; a magic-tap (`GameViewModel.announceCurrentState`) to recover
  missed/talked-over state on demand; the gear-mismatch warning and new
  personal-best catches now get proper announcements; `playLanded()` and
  swordfish's run haptics were differentiated (they read as near-identical
  before); mid-run state (casts remaining, best catch so far) now persists
  across an app kill via `UserDefaults`. Built, installed, and launched clean
  on-device — this was never recorded in this file before today, only in
  chat/session memory, which is why this entry is dated after the fact.
- 2026-09-13: **Project became a real git repo and pushed to GitHub**
  (`github.com/Zatoichi420/DeepSeaFishing`, public), after 23+ days untouched.
  Two Explore agents reviewed the project fresh: one confirmed all 7 fixes from
  the 2026-08-20 audit above are genuinely present in the code (not just
  claimed), then surveyed for new accessibility gaps; the other did this
  project's first-ever correctness/code-quality pass (no automated test suite
  exists here, unlike the sister Dungeon Speaker project). Three real
  silent-failure bugs fixed: `MotionManager`'s tilt calibration locked onto a
  single, possibly-noisy sample with no recalibration path (now averages ~6
  samples, plus a new "Recalibrate Tilt" button in `FightView` for mid-fight
  drift); `AudioManager` had no `AVAudioSession.interruptionNotification`
  handling at all, so a phone call could silently and permanently kill all
  game audio for the rest of the session (now recovers on `.ended`);
  `HapticsManager.isAvailable` only checked hardware capability, not whether
  the engine actually started, so it could report "available" after a silent
  failure. Four new accessibility gaps also closed: the gear-mismatch warning
  now gets announced when it changes; `IdleView` (the only screen missing it)
  now gets focus management on entry; `MeterView`'s duplicate title read
  ("Line to shore" then "Line to shore, 45 percent") is fixed; the onboarding
  Skip button's touch target was likely under 44pt and now isn't. **Still
  needs Orlando's own hands**: the tilt-recalibration and audio-interruption-
  recovery fixes specifically, since they can only really be confirmed by
  feel/ear on a real device, not by a clean build.

### Motion + haptics (added 2026-08-12)

- **`MotionManager.swift`** — wraps `CMMotionManager`, calibrates a "neutral" pitch
  the moment a fight starts (whatever angle the player happens to be holding the
  phone at), then classifies tilt as `.reeling` (tilted back past ~14°) /
  `.easing` (tilted forward past ~14°) / `.neutral`. Polled once per fight tick
  (0.5s) in `GameViewModel`, applied at half the strength of a deliberate button
  tap so continuous tilt doesn't dominate. **Untested on a physical device** — the
  sign of "tilt back = reeling" is a best guess (Simulator can't produce device
  motion), so if it feels backwards on-device, flip the comparison in
  `MotionManager.handle(_:)`.
- **`HapticsManager.swift`** — wraps `CHHapticEngine`. Distinct patterns per event:
  a bite thump on hookup, a continuous background hum whose intensity tracks live
  line tension (so you can feel how close to snapping without looking — the core
  accessibility idea from the original inspiration), species-specific run patterns
  (marlin = sharp staccato bursts for a tailwalk, swordfish = long low-sharpness
  rumble for a dive, tuna = one steady strong pull), a triumphant multi-tap on
  landing, and a long buzz on a snapped line. All calls are guarded/no-op on
  hardware without a Taptic Engine (older iPhones, Simulator) — checked via
  `CHHapticEngine.capabilitiesForHardware().supportsHaptics`.
- Neither CoreMotion nor CoreHaptics needs an entitlement or portal step. The
  existing `NSMotionUsageDescription` in `Info.plist` is technically for the
  activity/pedometer APIs (`CMMotionActivityManager`) which this doesn't use —
  harmless to leave in place, not required for `CMMotionManager.deviceMotion`.

### Audio (added 2026-08-13)

- **`AudioManager.swift`** — wraps `AVAudioEngine`. Everything is synthesized
  sample-by-sample at 44.1kHz, no bundled audio files, matching the original
  inspiration's "procedural Web Audio, nothing pre-recorded" approach:
  - A looping brown-noise ocean ambience (leaky-integrated white noise with a
    slow amplitude swell) plays continuously and quietly (volume 0.18) for the
    entire time the app is open — home screen, menus, mid-fight, all of it —
    per Orlando's request to hear ocean sound while fishing.
  - One-shot effects: a reel ratchet click (per Reel In tap/tilt tick), a line
    whoosh (per Ease Line), a bite thump on hookup, species-specific run sounds
    that mirror the haptic patterns (marlin = 3 rising pings, swordfish = long
    descending rumble, tuna = one steady pull), an ascending 3-note major
    arpeggio on landing, and a harsh noise+twang burst on a snapped line.
  - A pool of 4 round-robin player nodes (`effectVoices`) handles overlapping
    one-shot sounds so a reel click doesn't get queued behind a run sound.
  - `AVAudioSession` category is `.ambient` with `.mixWithOthers` — won't
    interrupt music, respects the silent switch, and (per iOS convention)
    should duck rather than fight VoiceOver speech.
- Started once in `GameViewModel.init()`. Failures are swallowed (audio is a
  supplementary channel, same posture as haptics) — if `engine.start()` throws
  the game just stays silent rather than crashing.
- **Known rough edge**: the ambience loop point isn't seamless (fresh noise
  each 4-second loop), which may be an audible click/discontinuity — noise
  texture should mostly mask it, but worth listening for.
- **Completely unverified by ear** — confirmed only that it builds and runs
  without crashing on Simulator (screenshot + process-alive check). Claude has
  no way to actually hear output. This is the top thing to sanity-check next
  time Orlando is at the phone: is the ambience volume right, are the effect
  sounds recognizable/distinct, does anything clip or sound harsh.

### Visual assets (added 2026-08-13)

Orlando can't personally verify visuals (VoiceOver-only), so scope was intentionally
kept small and legally unambiguous rather than guessed at: 4 real reference images,
all **public domain** (U.S. federal government work — NOAA/USFWS — or explicitly
released public domain by the artist), so **no attribution is required anywhere in
the app**. Sourced from Wikimedia Commons, verified license on each file's page
before downloading:

- **Marlin** — `MarlinImage` — blue marlin illustration by Duane Raver (USFWS),
  public domain by the artist's own release.
- **Swordfish** — `SwordfishImage` — real NOAA photo of a swordfish at 701m depth
  (Southeast Deep Coral Initiative expedition, NOAA Ship Nancy Foster, 2017) —
  fittingly matches the deep-drop gear description already in the game.
- **Tuna** — `TunaImage` — real NOAA/FAO photo of a school of Atlantic bluefin tuna
  swimming (Danilo Cedrone).
- **Ocean hero/background** — `OceanWaveImage` — NOAA breaking-wave photo, used as
  a rounded hero banner on the home screen and onboarding welcome step.

No matching Duane Raver illustration exists for bluefin tuna specifically (checked;
only a Blackfin tuna illustration by him exists, a different species), and no
freely-licensed marlin *action/jump* shot could be found — hence the mixed
illustration + real-photo styling for now. All four are `.imageset`s in
`Assets.xcassets` with a single "universal, 1x" entry (no @2x/@3x variants yet —
fine for real photos, less fine if these get used as small precision icons later).
`FishSpecies.imageName` (`GameModels.swift`) maps each species to its asset name.
Used as: home screen hero, species-picker card thumbnails, gear-picker header,
fight-screen banner, and the "Landed!" result screen. All marked
`.accessibilityHidden(true)` since adjoining text already carries the same
information for VoiceOver.

**Not done**: no custom app icon yet (still an empty `AppIcon.appiconset` slot).

## Project layout

- `project.yml` — XcodeGen spec. Edit this (not the `.xcodeproj` directly) and
  re-run `xcodegen generate` to regenerate the project after adding files.
- `DeepSeaFishing/` — app sources, `Assets.xcassets`, `Info.plist` (generated).
  - `GameModels.swift` — `FishSpecies`, `Fish` (species + randomized weight).
  - `EquipmentModels.swift` — `EquipmentKit` (real-world rod/reel/line/bait per
    species) + `FishSpecies.recommendedKit`/`blurb`.
  - `GameViewModel.swift` — `@Observable` run/fight state machine (`GamePhase`),
    timer-driven fight tick, gear-match difficulty modifiers, `UserDefaults`
    high-score persistence.
  - `ContentView.swift` — root phase switch + idle/home screen.
  - `SelectionViews.swift` — species picker + gear picker screens.
  - `FightView.swift` — tension/progress meters + Reel In / Ease Line controls
    (plus a tilt hint when motion is available).
  - `ResultViews.swift` — per-catch result screen + end-of-run summary.
  - `MotionManager.swift` — CoreMotion tilt-to-reel/ease.
  - `HapticsManager.swift` — CoreHaptics bite/run/tension/land/snap feedback.
  - `AudioManager.swift` — procedural AVAudioEngine ambience + one-shot sounds.
  - `OnboardingView.swift` — first-launch tutorial, replayable from home screen.
- `DeepSeaFishing.xcodeproj` — generated, not hand-edited.

## Build & run (physical iPhone)

Device used so far: **iPhone 15**, hostname `iPhone.coredevice.local`, UUID
`63E1F6CA-EF93-57B9-A68B-F954BC77824D` (from `xcrun devicectl list devices` —
re-check this UUID if a different iPhone is plugged in later). Must use the stable
`Xcode.app`, not `Xcode-beta.app` (see global CLAUDE.md notes).

```
cd "/Users/orlandojohnson/Desktop/My Fishing Game"
xcodegen generate   # only needed after adding/removing source files

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project DeepSeaFishing.xcodeproj -scheme DeepSeaFishing \
  -destination 'platform=iOS,name=iPhone' -allowProvisioningUpdates build

APP_PATH="/Users/orlandojohnson/Library/Developer/Xcode/DerivedData/DeepSeaFishing-*/Build/Products/Debug-iphoneos/DeepSeaFishing.app"

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun devicectl device install app --device 63E1F6CA-EF93-57B9-A68B-F954BC77824D "$APP_PATH"

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun devicectl device process launch --device 63E1F6CA-EF93-57B9-A68B-F954BC77824D \
  com.orlandojohnson.DeepSeaFishing
```

If `xcrun devicectl list devices` shows the iPhone as `unavailable` rather than
`connected`, it's a physical/pairing issue (unlocked? cable seated? "Trust This
Computer" prompt on the phone?), not a build problem — check that before re-running
the build.

## Open design questions

- SwiftUI vs UIKit for VoiceOver control precision — current build is SwiftUI;
  revisit only if VoiceOver focus during the fight loop turns out to need finer
  control than standard button/ProgressView accessibility gives us.
- **Resolved 2026-08-20**: tilt direction and haptic feel were confirmed
  correct on-device by Orlando. **Still open**: the ocean ambience volume and
  one-shot sound effect balance have never been confirmed by ear at all, and
  two brand-new 2026-09-13 fixes specifically need a real-device check —
  whether "Recalibrate Tilt" (`FightView`) actually fixes a fight where tilt
  feels backwards/stuck, and whether game audio genuinely recovers after a
  real interruption (a phone call or Siri) instead of staying silent.
- Possible future addition: a "shake to set the hook" moment right after casting
  (matches the original inspiration's cast → wait → shake idea) — deliberately left
  out of the current motion pass to keep scope to reel/ease control.
- Fight balance is a first guess (reel/ease deltas, tick cadence, aggression per
  species) — needs actual playtesting on-device to tune.
- Should mismatched-gear runs still count toward the all-time best catch, or should
  the record only track "legit" (correct-gear) catches?

## Career mode, tackle trees, leveling (2026-10-12)

Orlando asked for the same treatment Dungeon Speaker got: a story, deeper items and inventory, and leveling.

**Career mode** (new; the original 4-cast game is still here as **Quick Run**, with identical fight numbers):
- **Story:** you inherit your grandfather Elias's sportfisher, the Marisol, in Port Salvage. There are 5 chapters and an epilogue (`StoryBeats` in `Career.swift`):
  1. Earn $1,200 to repair the boat.
  2. Land Old Scarback, a 980 lb bluefin at the Canyon Edge.
  3. Win the Harbor Tournament by landing a blue marlin over 520 lb in the Gulf Stream, beating rival captain Dax Ferro.
  4. Land the Gray Ghost, a swordfish in the Deep Trench.
  5. Land Ironjaw, the 1,420 lb marlin carrying Elias's 1979 hook. You release him.
- **Fishing grounds:** 4 grounds, unlocked by the story, with fuel costs and their own species pools.
- **Species:** 5 new ones (mahi-mahi, wahoo, yellowfin, sailfish, mako), 8 total. Run haptics and sounds are keyed by fight style (burst, deep, steady), so every species reads by feel.
- **Tackle:** 4 outfits; light tackle is new. Each upgrades Stock, Pro, Tournament, Custom Grander for faster reeling, less tension, and softer runs. Live bait packs. Four boat upgrades: fuel tank (+1 cast), fish finder (bigger fish), outriggers (legends bite more), fighting chair (less tension).
- **Money:** fish sell by the pound at the dock. Billfish are tagged and released for a fee. Three rotating charter contracts pay bonuses. Legends carry bounties.
- **Leveling:** angler experience to level 10, with a skill point per level. Five skills of 5 ranks each: Strength, Finesse, Instinct, Fish Sense, Salesmanship.
- **Logbook** of every species and legend.
- **Saving:** the career autosaves as JSON in Application Support (`CareerStore`).

**Architecture:**
- The fight is now a pure `FightEngine` struct, driven by the view model's timer.
- `Career` is pure and `Codable`.
- `GameRandom` is seedable.
- There's a new `DeepSeaFishingTests` target: 17 tests, all passing.
- A human-like fight bot reads tension with noise and sometimes over-reels. Results:
  - Ordinary fish on the right gear: 91–99% landed.
  - Wrong gear is clearly worse.
  - Legends need upgraded tackle. Ironjaw is under 15% on stock gear and over 85% on tournament gear.
- Simulated careers finish in 9–18 trips (median 12).

**Not verified:** none of it has been played on the phone. New species reuse the nearest relative's image (mahi and mako show the ocean photo) until real public-domain art is sourced.

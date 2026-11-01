# bloom for iOS

Native iOS app built with SwiftUI and SwiftData. It needs iOS 26 or newer.

## Setup

Requirements: Xcode 26+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
make project   # generate Bloom.xcodeproj from project.yml
make open      # open in Xcode
```

The `.xcodeproj` is generated and not checked in. After adding, removing or
moving files, run `make project` again.

To run on a device, copy `Config/Local.xcconfig.example` to
`Config/Local.xcconfig` and set your own `DEVELOPMENT_TEAM` and
`BLOOM_BUNDLE_ID`. The file is git-ignored.

## Tests

```bash
make test-kit   # BloomKit tests via SwiftPM (macOS or Linux)
make test       # app tests in the iOS Simulator
```

CI runs both on every change in `ios/` (see `.github/workflows/ios.yml`).

## Structure

```
ios/
├── project.yml               XcodeGen spec (targets, settings, schemes)
├── Config/                   Shared and local build settings
├── Packages/BloomKit/        Platform-independent domain logic (Foundation only)
│   ├── Model/                CalendarDay, DayLog, flow, symptoms, discharge, sex
│   └── Prediction/           Period detection, learning, forecast
├── Bloom/                    The SwiftUI app
│   ├── App/                  App entry, root tabs, derived CycleState
│   ├── Model/                SwiftData schema, DayLogStore, export, preview data
│   ├── Features/             Today, Calendar, DayLog, History, Settings, Onboarding
│   ├── DesignSystem/         Colors, components, formatting
│   └── Resources/            Assets, String Catalog (en, de), privacy manifest
└── BloomTests/               App-level tests (persistence, mapping, export)
```

**BloomKit** contains everything that is not UI: the domain model and the
prediction engine. It has no dependency on SwiftUI or SwiftData. That keeps it
fast to test and lets the Kotlin app later follow the same rules.

## Data model

- One `DayEntry` per calendar day. A day is stored as an ISO string
  (`2026-11-01`), not as a `Date`, so entries don't shift across time zones.
- Enum values (flow, symptoms, discharge) are stored as raw strings. Unknown
  values from newer app versions are ignored instead of breaking decoding.
- The schema is versioned (`BloomSchemaV1`) and has a migration plan from day one.
- Storage is local only: no CloudKit, no app group, no network.

## Prediction model

1. **Periods** are detected from logged bleeding days. Spotting is ignored, gaps
   of up to 2 days are merged, and bleeding less than 15 days after a period
   start does not count as a new period.
2. **Cycle length** is a recency-weighted mean of the last 12 cycles (weight 0.8
   per cycle back). Implausible lengths (outside 15–60 days) and outliers
   (median absolute deviation) are ignored.
3. **Priors** (28/5/14 days, or the values from onboarding/settings) act like
   pseudo-cycles that are older than any real one. They dominate without data
   and fade as history grows.
4. **Ovulation** = next period − luteal phase. The luteal phase is learned from
   logged egg-white discharge. If egg-white discharge is logged in the current
   cycle, the next period is predicted from it.
5. **Fertile window** = ovulation − 5 days … ovulation + 1 day.
6. **Uncertainty** (± days) comes from the cycle variability and grows for
   cycles further in the future. Confidence is low, medium or high depending on
   the number of cycles and their variability.

bloom is not a contraceptive. The fertile window is an estimate.

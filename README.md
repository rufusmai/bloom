# bloom

**bloom** is an open source, privacy-first cycle tracker.

Log your period, symptoms, discharge and sexual activity in a calendar. bloom
learns from your own history to predict your next periods, your ovulation and
your fertile window.

> [!IMPORTANT]
> bloom is **not a contraceptive** and does not provide medical advice.
> Predictions are estimates based on your logged data and can be wrong.

## Privacy promise

Cycle data is some of the most sensitive data there is. bloom is built around a few rules:

- **Local-first.** Your data stays on your device. No account, no cloud, no server.
- **No tracking.** No analytics, no ads, no third-party SDKs.
- **No dependencies.** The iOS app uses only Apple frameworks.
- **Open source.** Every line is auditable, licensed under GPL-3.0.

## Repository layout

This is a monorepo:

| Folder | What | Status |
| --- | --- | --- |
| [`ios/`](ios) | Native iOS app (SwiftUI, SwiftData) and `BloomKit`, the platform-independent prediction engine | In development |
| [`android/`](android) | Native Android app (Kotlin) | Planned |
| [`web/`](web) | Marketing landing page for [bloom.rufusmai.com](https://bloom.rufusmai.com) | Planned |

## Getting started (iOS)

Requirements: macOS with Xcode 26 or newer, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
cd ios
make project   # generates Bloom.xcodeproj from project.yml
make open      # opens it in Xcode
```

See [`ios/README.md`](ios/README.md) for details on the architecture, tests and the prediction model.

## How predictions work

bloom does not use a fixed 28-day rule. `BloomKit` detects your periods from
logged bleeding days and computes your cycle lengths. It then estimates your
personal cycle with a recency-weighted average. Newer cycles count more, and
implausible outliers (for example a forgotten log) are ignored. With little
data, the estimate leans on sensible defaults. The more cycles you log, the
more the estimate is based on your own history.

Ovulation is estimated from the predicted next period minus your luteal phase
(14 days by default). If you log egg-white discharge, bloom learns your
personal luteal phase from it.

## Contributing

Issues and pull requests are welcome. Please keep the privacy promise in mind:
no network calls, no analytics and no third-party dependencies in the apps.

## License

[GPL-3.0](LICENSE) © Rufus Maiwald

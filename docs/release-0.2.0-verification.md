# OpenRight 0.2.0 verification

Release: https://github.com/MaxTheTurtle0/OpenRight/releases/tag/v0.2.0

Source revision: `95487ecab5b5a291b08da420d2f10be06d0d3cde`. The cloud archive records this revision and its build-input fingerprint.

Verified on macOS 27.0.1, Apple Silicon:

- 52 Swift tests passed with compiler warnings treated as errors.
- Three Python release-version tests passed, including unchanged/older build rejection.
- The app and Sparkle helper code have valid Developer ID signatures.
- The exported app has a valid stapled Apple notarization ticket. Gatekeeper reports `accepted`, `source=Notarized Developer ID`.
- The executable contains both arm64 and x86_64 slices.
- The public DMG was downloaded again over HTTPS. Its checksum, enclosed app signature, notarization ticket, and Gatekeeper acceptance were verified.
- The hosted appcast points to the immutable v0.2.0 ZIP with the expected build, byte length, and Ed25519 signature. The downloaded ZIP verifies.
- A signed update archive verifies before modification; verification fails after its bytes are changed.
- An isolated updater-enabled 0.1.9/build 1 test app discovered the hosted 0.2.0 release, was replaced by the Developer ID-signed build 2, and relaunched from its test location. Its notarization ticket still validates. A subsequent check reports that 0.2.0 is the newest version.
- The normal installed copy was upgraded to the same signed, notarized app.

The older-version update host was a development-signed test copy, not a previously published notarized release. A notarized-to-notarized upgrade should also be exercised for the next public release. Intel hardware and older macOS versions were not available locally.

The DMG is an unsigned container for the signed, notarized app. Sparkle updates use the separately Ed25519-signed ZIP.

Public artifact SHA-256 values:

```text
f72b27484ae03dcadee28627d46158ff7cebb004ab088d2b8c4afcf25ca6ff43  OpenRight.dmg
f5114b6ef97e9c4af834d9a79d8b8cf55f6221b318d7b7929d5ebccc9fa17078  OpenRight-0.2.0-universal.zip
```

The source revision's [main CI run](https://github.com/MaxTheTurtle0/OpenRight/actions/runs/40915041246) also passed.

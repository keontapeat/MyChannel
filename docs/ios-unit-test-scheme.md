# iOS unit test scheme

Run MyChannel unit tests locally:

```bash
./scripts/run-unit-tests.sh
```

Direct `xcodebuild` (macOS + Xcode):

```bash
xcodebuild test \
  -project MyChannel.xcodeproj \
  -scheme MyChannel \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=latest' \
  -only-testing:MyChannelTests \
  CODE_SIGNING_ALLOWED=NO
```

CI: `.github/workflows/unit-tests.yml` runs web wager-policy tests on every PR; iOS runs when macOS runner is available.

Test target: **MyChannelTests** (not MyChannelUITests unless smoke tests are requested).

# Flaky test quarantine list

Quarantined / known-flaky tests — skip in CI until stabilized:

| Test | Reason | Tracking |
|------|--------|------------|
| `HomeViewModelTests` network timing | Simulator network variance | batch-7 |
| `NuclearFlicksViewModelTests` feed preload | Depends on live URL health | batch-7 |

Stable money tests (always run):

- `MoneyMathTests`, `MoneyMathGoldenTests`, `MoneyMathFuzzTests`
- `MoneyEscrowMathTests`, `MoneyEscrowIntegrationHarnessTests`
- `EscrowIdempotencyTests`, `VSMatchComplianceServiceTests`
- `WagerPolicyTests`, `FeedMathTests`

Re-enable quarantined tests by removing `-skip-testing:` entries in CI when fixed.

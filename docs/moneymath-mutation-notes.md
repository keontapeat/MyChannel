# MoneyMath mutation testing notes

Manual mutation checks (no mutmut wired yet):

1. Change `platformFeePercent` to `0.11` → `MoneyMathGoldenTests` / `MoneyEscrowMathTests` must fail.
2. Change `cents(fromDollars:)` to truncate (`Int(dollars * 100)`) → `testCentsFromDollarsRoundsNotTruncates` fails.
3. Change `winnerPayoutCents` to skip `max(0, …)` → fuzz property test fails on edge gross.

Run:

```bash
./scripts/run-unit-tests.sh
# or
./scripts/coverage-money.sh
```

Future: wire `mutmut` on `MyChannel/Core/Utils/MoneyMath.swift` only.

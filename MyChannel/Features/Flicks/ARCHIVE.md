# Flicks Archive Notes

## EnhancedFlicksViewModel (archived)

**Status:** Deprecated, unwired from production UI.

**Canonical ViewModel:** `NuclearFlicksViewModel` (used by `FlicksView`).

`EnhancedFlicksViewModel.swift` is kept for reference only. It was an earlier feed/pagination
implementation that duplicated NuclearFlicksViewModel responsibilities. Do not instantiate
from production UI — merge any useful logic into `NuclearFlicksViewModel` instead.

**Batch 6:** Confirmed archive; FlicksView uses `@StateObject private var viewModel = NuclearFlicksViewModel()`.

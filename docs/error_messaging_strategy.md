# User-visible Error Messaging Strategy

PantryPilot now routes recoverable UI errors through `UserErrorMessagingService`.

## Principles
- Prefer short action-oriented copy ("Try again", "Check connection").
- Keep raw error output out of primary UX unless needed for beta diagnostics.
- Pair user messaging with crash/error reporting context for developer triage.

## Current implementation
- `UserErrorMessagingService.map(...)` normalizes common connectivity failures.
- `UserErrorMessagingService.show(...)` presents consistent snackbars.
- Capture and shopping flows use this service and also report errors through `CrashReportingService`.

## Next step
- Replace simple mapper with typed domain errors and localized message catalog.

# PantryPilot App Store Readiness Pack

## 1) Screenshot Checklist (placeholder matrix)
Capture both light/dark where practical and include the bread-plane brand motif in final art.

- [ ] Onboarding hero + first-run education cards.
- [ ] Home with pantry seeded and filters visible.
- [ ] Results tabs: Exact, Almost There, Pantry Freestyle.
- [ ] Recipe detail with substitution + shopping handoff CTA.
- [ ] Cook mode active step with timer controls.
- [ ] Shopping handoff screen with provider link status.
- [ ] Empty-state examples (no pantry, no results, no shopping list).
- [ ] Settings / Privacy / Terms entry points.

## 2) Privacy Nutrition Checklist (placeholder)
Fill this with counsel/legal review before submission.

### Data collection declaration
- [ ] Contact info collection declared (if enabled).
- [ ] User content declared (pantry inputs, photos).
- [ ] Identifiers declared (account ID, install ID).
- [ ] Usage data declared (analytics events).
- [ ] Diagnostics declared (crash reports).

### Data usage mapping
- [ ] App functionality.
- [ ] Personalization.
- [ ] Analytics.
- [ ] Fraud/security.
- [ ] Advertising (if monetization enabled).

### Controls
- [ ] In-app privacy entrypoint verified.
- [ ] Deletion/export workflow documented.
- [ ] Consent copy reviewed for plain language.

## 3) Release Metadata Checklist
- [ ] App subtitle and promotional text use PantryPilot naming.
- [ ] Description includes Pantry Freestyle explanation.
- [ ] What’s New notes include practical user-facing value.
- [ ] Keyword set validated (family cooking, pantry, meal planning).
- [ ] Support URL and privacy URL valid.
- [ ] Age rating questionnaire completed.

## 4) Test Account + Demo Flow Notes
Use this for reviewers and internal QA.

- Demo account label: `pantrypilot_reviewer_demo@placeholder.local`.
- Build flag recommendation for stable review: `USE_MOCKS=true`.
- Demo script flow:
  1. Open onboarding and tap **Run polished demo script**.
  2. Confirm seeded pantry and open recipe generation.
  3. Review Exact vs Almost There vs Pantry Freestyle.
  4. Open recipe detail, add missing items to shopping handoff.
  5. Start cook mode and complete one timer step.
- Include known limitations note if external providers are mocked.

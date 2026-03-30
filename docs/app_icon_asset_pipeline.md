# PantryPilot App Icon + Brand Asset Pipeline (placeholders)

## Brand direction
- Product name: **PantryPilot**.
- Tone: warm, approachable kitchen co-pilot.
- Creative mode naming: **Pantry Freestyle**.
- Visual direction: bread-plane motif.

## Icon placeholders to integrate
Expected source assets (design handoff):
- `branding/icon/master/pantrypilot_app_icon_1024.png`
- `branding/icon/master/pantrypilot_app_icon_round_1024.png`
- `branding/icon/foreground/bread_plane_foreground.png`
- `branding/icon/background/bread_plane_bg.png`

## Flutter integration notes
1. Place final icon files under `branding/icon/...` (or agreed asset folder).
2. Generate platform icons with your chosen pipeline tool (e.g. flutter_launcher_icons).
3. Verify:
   - iOS AppIcon set includes 1024 marketing icon.
   - Android adaptive icon foreground/background align with bread-plane silhouette.
   - Notification icon legibility at small sizes.
4. Re-run after each icon revision and attach before/after screenshots to PR.

## Illustration slots in app UI
These placeholders are intentionally wired in UI to swap with final art:
- onboarding hero
- home empty pantry state
- results loading + empty tabs
- recipe detail hero fallback
- cook mode no-recipe state
- shopping handoff empty state

When art is delivered, replace placeholder text and wire to image assets with semantic labels.

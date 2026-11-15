# Final submission — PacePilot + Gut Train

We built a Garmin companion to help people stay active consistently. PacePilot offers manageable run/walk sessions, wrist-based effort feedback, an animated avatar and weekly progress. Gut Train is a separate app for longer-session fueling and gut-comfort feedback. One dashboard brings plans, preferences and live activity together.

Repository: https://github.com/mmjahromi/Hackaton_Garmin/tree/dashboard-and-recovery
Live dashboard: https://gut-train-web.vercel.app
Deployment shortcut: from the repository root, run `sh deploy-dashboard.sh` (Node.js/npm and a Vercel account required). The script installs dependencies, tests, builds and deploys the web app. For persistent data, configure Redis as described in gut-train-web/README.md. This does not install watch apps.
Watch installation/build instructions: pacepilot-app/README.md and gut-train-app/README.md. Prebuilt PRGs are in their release folders.

## Why it fits the challenge

The challenge asks us to improve our own health and wellness using Garmin. Our focus is the difficulty of staying active consistently. We turn workout evidence and user feedback into a manageable next-session offer, while keeping the user in control. Heart rate, movement/GPS and pressure context have concrete uses in coaching rather than merely appearing as numbers.

## Strongest feature

The connected feedback loop: choose a manageable activity, receive understandable wrist feedback, see activity on the dashboard, record how it felt, and use that history to choose the next session. Missing readings and simulated data are clearly distinguished.

## Honest scope and future work

Recommendations currently use explainable rules, not AI/ML. Automatic sleep-based adaptation is not implemented. Health benefits have not been demonstrated in a user study. Physical-device acceptance remains outstanding, and the current shared demo is not private multi-user health storage.

Next: sleep/recovery inputs with verified data access, consistent duration limits across devices, private accounts/device pairing, richer personal baselines, and validated goal-specific plans. AI could later help explain patterns, but should not silently replace explicit workout rules or user confirmation.

Demo: open Today → View demo; inspect history and the suggested workout. Switch to Your data → User settings to configure preferences and plan sharing. On an installed watch app, enable live sharing and start a LIVE workout to demonstrate telemetry; prerecorded/simulated demonstrations must be labeled.

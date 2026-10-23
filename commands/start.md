---
description: Start Stickshift in this project, or resume manual mode after a pause
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/init.sh)
---

## Setup

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/init.sh`

## Your task

Use the stickshift skill from now on.

- No profile yet: run onboarding from the skill's onboarding.md.
- Profile exists but this project's language isn't in it: ask only for their level in it.
- Created a new project: ask what they're building and start `.stickshift/map.md`.
- Resumed: one or two lines on where they left off (from the journal) and how many open questions
  and unconfirmed concepts there are. Then ask what they want to work on.

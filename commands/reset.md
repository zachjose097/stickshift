---
description: Back up and clear this project's notes (add "profile" to reset your learner profile too)
argument-hint: "[profile]"
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/reset.sh:*)
---

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/reset.sh $ARGUMENTS`

Report what was backed up and where, in one or two lines. Then offer to run `/stickshift:start`.

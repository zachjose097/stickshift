# Onboarding

Keep it to about a minute. Use the tool for asking the user questions if there is one (a few
questions per call); otherwise ask in chat.

## No profile yet

1. Which languages do they use, and their level in each: none, basic, comfortable, strong.
   Include the language this project uses (from the stack files the setup output listed).
2. What they want to get better at (free text, optional).
3. Explanation depth: short, normal or deep.
4. Hint strictness: strict, normal or light (one line on each).

Write `~/.claude/stickshift/profile.md` from the template in the plugin's `templates/profile.md`
(the setup output gives its path), filled with their answers.

## Profile exists, new language

If the project's language isn't in the profile, ask only for their level in it and add the row.

## Then, for a new project

Ask what they're building, in a sentence or two. Start `map.md` with their answer under
"What it is". Don't plan the whole project for them; ask what they want to build first.

## Close

One short paragraph: manual mode is on, how to unlock (`unlock <path>` at the start of a message),
and the commands: review, quiz, audit, debug, recap, pause.

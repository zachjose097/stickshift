# Onboarding

Keep it to about a minute. Free-text answers are asked in chat, as a plain question the user types
a reply to. Use the tool for asking the user questions (if there is one) only for fixed choices,
a few per call; without it, ask those in chat too. Never put a free-text question in the tool:
its "Other" box doesn't tell the user they're meant to type.

## No profile yet

1. In chat: which languages do they use? If the setup output found no stack files, also ask what
   this project will be written in.
2. Their level in each language they named, plus the project's language: none, basic,
   comfortable, strong (one tool question per language).
3. Explanation depth: short, normal or deep.
4. Hint strictness: strict, normal or light (one line on each).
5. In chat: what they want to get better at (optional, they can skip).

Write `~/.claude/stickshift/profile.md` from the template in the plugin's `templates/profile.md`
(the setup output gives its path), filled with their answers.

## Profile exists

If the setup output found no stack files, ask in chat what this project will be written in. If the
project's language isn't in the profile, ask only for their level in it and add the row.

## Then, for a new project

Ask in chat what they're building, in a sentence or two. Start `map.md` with their answer under
"What it is". Don't plan the whole project for them; ask what they want to build first.

## Close

One short paragraph: manual mode is on, how to unlock (`unlock <path>` at the start of a message,
for one request), that when planning a feature you'll suggest which boilerplate files they could
hand you with `delegate <paths>`, and the commands: review, quiz, audit, debug, recap, pause.

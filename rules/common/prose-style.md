# Prose Style

## Scope

This file governs the user-facing prose that you write: documentation, READMEs, tickets, review findings, commit messages, and conversation replies. Text inside code is out of scope here, and this does not narrow the reach of `./language.md` over identifiers and comments. See `./language.md` for the spelling, emoji, dash, and inclusive-terminology conventions. These rules bind only the prose that you write. Existing text around your edits follows the consistency rule in `./coding-style.md`, so this file licenses no restyling of stable documents.

## Verbatim Material

You **MUST** reproduce verbatim material exactly: code, identifiers, commands, file paths, quoted errors, quoted logs, product names, and quoted text of any origin. An identifier, a backticked command, or a quoted string counts as one word in the sentence limits below.

## Modal Verbs

Write `must` for a requirement, not `should`. Write `can` for possibility or permission, not `may`, `might`, or `could`. Restructure a hypothetical `would` as a conditional sentence. Capitalised `MUST`, `SHOULD`, and `MAY` in a normative document keep their form. You **MUST NOT** rewrite a normative `SHOULD` as `MUST`, because that changes the obligation.

## Sentences

An imperative sentence has at most 20 words. Any other sentence has at most 25 words. You **MUST NOT** join clauses with a semicolon: write two sentences.

## Voice and Order

Use the active voice and the simple tenses. In an instruction, the condition or the warning stands before the command: `If the build fails, read the log.` Keep the articles and the conjunction `that`. You **MUST NOT** compress a sentence into telegraph style: write `Make sure that the file exists`, not `Ensure file exists`.

## Vocabulary

Within one document, use one name for one thing and one verb for one action. Pick one term from a set such as `check`/`verify`/`confirm`, `config`/`settings`, or `error`/`failure`, and hold it. Write `use` not `leverage`, `to` not `in order to`, `before` not `prior to`, and `because` not `due to the fact that`. Write `if` not `in the event that`, `you can` not `enables you to`, `by default` not `out of the box`, and `internally` not `under the hood`. Write `for example` not `e.g.`, `that is` not `i.e.`, and `many` not `plethora`. Name the items instead of `etc.`. Delete filler and intensifiers such as `simply`, `robust`, `seamlessly`, and `it is worth noting that`, or state the measurable property.

## Technical Language

Prefer plain language wherever it carries the intent. Where only a technical term states the meaning precisely, use it. Explain each technical term at its first use. Expand each acronym at its first use: `continuous integration (CI)`.

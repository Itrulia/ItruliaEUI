## Text

- Dont use `--` in generated texts. Prefer commas or full stops.

## Code Style

Source code formatting should follow the existing conventions in the codebase.

- Always use `then`/`end`, even for single statements.
- Never add comments **unless** they are needed to avoid bugs down the line.
- Avoid 1 character variable names
- Variable names are always camelCase unless it's a modules name

## Code Rules

- Prefer using `PixelUtil` for sizing and positioning unless that would cause bugs. Like multiple bars chained together that would lead to inconsistent spacing.

## Commit Rules

- Never commit yourself or add yourself as an author. Always let the user commit themselves
- When asked to resolve merge conflicts, never `git add` those files yourself. This rule does not apply when asked to rebase a branch on top of another.


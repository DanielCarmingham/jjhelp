# jjp Command Palette Design

## Goal

Build an intent-first terminal command palette for common jj workflows.

The current `jjhelp` chart is useful as a reference, but it still asks the user
to memorize abbreviations like `cl`, `tug`, `jjgp`, and `jjdmsg`. The new tool
should let the user search for what they mean in plain English, inspect what a
workflow will do, fill in any required parameters, and insert the resulting
command into the shell prompt for review.

## Non-Goals

- Do not replace `jjhelp`; keep the static chart for quick lookup.
- Do not auto-run generated commands in the first version.
- Do not implement a custom fuzzy matcher or full-screen TUI.
- Do not require users to understand the abbreviation layer before using the
  palette.

## Commands

Expose two user-facing entry points:

- `jjhelp`: existing static reference.
- `jjp`: interactive command palette.

`jjp` is a zsh wrapper around a Rust binary:

```zsh
jjp() {
  local cmd
  cmd="$(jjp-bin "$@")" || return
  print -z "$cmd"
}
```

The wrapper exists because a child process cannot mutate the parent shell's
editing buffer. The Rust binary prints the final command; zsh inserts it into
the prompt with `print -z`.

## Architecture

### Rust Binary

`jjp-bin` owns:

- the action registry,
- candidate formatting for fzf,
- preview text generation,
- parameter resolution,
- command template rendering,
- shell quoting for generated commands.

It shells out to external tools for live repository data:

- `fzf` for interactive filtering,
- `jj` for bookmarks, revisions, files, remotes, and config aliases,
- `fd` if available for path selection, falling back to `find`.

### fzf

fzf is the first screen. It receives tab-delimited candidate rows from Rust and
returns the selected action id.

Candidate rows should include fields for:

- action id,
- title,
- tags,
- shortcut commands,
- expanded commands,
- description.

fzf should display the human-facing fields and hide the internal id. Matching
should cover all fields so searches like `push main`, `bookmark advance`,
`publish`, or `done` can find the same action.

The preview pane should teach the action:

```text
land current work on main

Why:
  Make main point at your current jj change and push main to origin.

Steps:
  1. jj sync
     jj git fetch --all-remotes

  2. jj evolve
     jj rebase --skip-emptied -o trunk()

  3. jj tug main
     jj bookmark advance main

  4. jjgp --bookmark main
     jj git push --bookmark main

Will insert:
  jj sync && jj evolve && jj tug main && jjgp --bookmark main
```

## Parameter Model

Parameters are typed. Each type has a resolver.

### Defaults

Some parameters should not prompt by default:

- bookmark: `main`,
- revision: `@`,
- base: `trunk()`.

Actions can opt into prompting even when a default exists.

### fzf Pickers

Use fzf when the value can be listed:

- bookmarks from `jj bookmark list`,
- revisions from `jj log`,
- files from `jj diff --name-only` or `jj file list`,
- remotes from `jj git remote list`.

The picker preview should explain what the selected value means when useful.
Revision pickers can show the commit description and change id. File pickers can
show `jj diff <file>`.

### Free Text

Use a prompt for values that are not naturally enumerable:

- change description message,
- new bookmark name,
- arbitrary revset.

Free-text values must be shell-quoted before rendering into commands.

## Action Schema

Start hardcoded in Rust until the UX stabilizes. Move to TOML later only if
editing actions without recompilation becomes important.

Conceptual shape:

```rust
Action {
    id: "land-main",
    title: "land current work on main",
    description: "Move main to the current change and push main to origin.",
    tags: ["push", "publish", "done", "main", "bookmark"],
    steps: [
        Step::Static("jj sync"),
        Step::Static("jj evolve"),
        Step::Template("jj tug {bookmark}"),
        Step::Template("jjgp --bookmark {bookmark}"),
    ],
    params: [
        Param::Bookmark {
            name: "bookmark",
            default: "main",
            prompt: false,
        },
    ],
}
```

Each step should carry both a shortcut command and, when known, an expanded
command. Expanded commands can come from the same alias-resolution logic used by
`jjhelp -F`.

## Initial Actions

Ship a small first set:

- land current work on main,
- catch up with remote main,
- describe current change,
- split current change,
- undo last jj operation,
- inspect current change,
- move bookmark to current change,
- push bookmark.

Avoid adding PR-oriented actions to the first screen. They can be added later as
optional actions if needed.

## Command Output

The first version prints one command line suitable for `print -z`.

For multi-step actions, join steps with `&&` only when later steps should not run
after an earlier failure:

```sh
jj sync && jj evolve && jj tug main && jjgp --bookmark main
```

Actions that need user editing should still insert the command, not execute it.
This makes the palette safe while the command set is still being tuned.

## Error Handling

- If `fzf` is missing, print a clear install message and exit non-zero.
- If `jj` is missing, print a clear install message and exit non-zero.
- If a parameter resolver fails, show the failed command and preserve the action
  context.
- If the user cancels fzf, exit non-zero without printing a command.

The zsh wrapper should only call `print -z` when `jjp-bin` exits successfully and
prints a non-empty command.

## Testing

Rust tests:

- action search row generation includes title, tags, shortcut commands,
  expanded commands, and description,
- command templates render with defaults,
- shell quoting handles spaces and quotes,
- cancelled resolver returns no command,
- multi-step commands join with `&&`.

Shell/integration tests:

- fake `fzf` returns a selected action id,
- fake `jj` supplies bookmarks/revisions/files/remotes,
- `jjp-bin` prints the expected command,
- zsh wrapper inserts only on success.

Manual checks:

- fzf search can find actions by intent words and expanded command words,
- preview panes explain the workflow clearly,
- generated commands are readable before pressing Enter.

## First-Version Decisions

- Binary name: `jjp-bin` for the implementation, `jjp` for the shell function.
- No direct execution mode. The first version is insert-only.
- Keep actions hardcoded in Rust.
- Keep alias expansion separate from `jjhelp -F` initially. Reuse behavior and
  tests, but do not block the first version on extracting a shared library.

# jjhelp

A quick-reference chart for [jj](https://github.com/jj-vcs/jj) (Jujutsu), for your shell.

`jj` is easy to learn and hard to remember. jjhelp prints what you actually have
installed — read from your live shell aliases and your live `jj config`, so the chart
can't drift from reality the way a hand-maintained cheatsheet does.

```
── bookmarks ─────────────────────────────────────
  jjb   jj bookmark
  jjba  jj bookmark advance
  jjbc  jj bookmark create
  ...

── changes ───────────────────────────────────────
  jjnt    jj new "trunk()"        — start a new change on top of trunk()
  jjrbm   jj rebase -d "trunk()"  — rebase onto trunk()
  ...

── flows ───────────────────────────────────────
  land on main  jj sync                      — fetch FIRST — skipping this gets the push rejected as "stale info"
                jj evolve                    — rebase onto the new trunk(); this is the "merge", history stays linear
                jj tug main                  — name it — bare tug advances every closest bookmark, not just main
                jj git push --bookmark main  — name it — a bare `jj git push` often finds nothing to push

  ! don't mix flows on one change: after `cl`, tug stops advancing main

60 shortcuts · 7 extras, see jjhelp -p
```

## Usage

| Command        | Shows                                                            |
| -------------- | ---------------------------------------------------------------- |
| `jjhelp`       | the alias chart, plus the flows                                  |
| `jjhelp -f`    | just the flows — recipes where the *ordering* is the point       |
| `jjhelp -g`    | a git → jj translation table, with the foot-guns marked          |
| `jjhelp -p`    | also list optional extras worth stealing                          |
| `jjhelp push`  | only rows whose name, body, or description matches `push`        |

The `-g` table is the one to read first if you're coming from git. Every `!` note in it
is something a scratch repo actually produced, not a remembered rule.

## Install

```sh
git clone https://github.com/DanielCarmingham/jjhelp
cd jjhelp
./install.sh
```

Then restart your shell and run `jjhelp`. Re-run `./install.sh` any time to update;
it's idempotent. `./install.sh --uninstall` removes it.

The installer places two files and adds one line to your `.zshrc`:

| File                                 | What it is                                  |
| ------------------------------------ | ------------------------------------------- |
| `~/.config/zsh/jjhelp.zsh`           | the chart itself                            |
| `~/.config/jj/conf.d/50-jjhelp.toml` | the jj aliases the chart documents          |

### Requirements

- **zsh.** jjhelp uses zsh-specific parameter expansion throughout; there's no bash port.
- **jj**, obviously. Without it the chart still renders, just without the config rows.
- **The oh-my-zsh `jj` plugin** is optional but strongly recommended — it supplies about
  38 of the chart's rows. Add `jj` to your `plugins=(...)` line.

### Why it's sourced instead of a script on `PATH`

Because it reads `alias`, which is shell state a child process can't see. A
`~/.local/bin/jjhelp` would render the entire shell-alias section empty — and it would
do it *silently*, since every other section would still work fine.

For the same reason, the source line has to come **after** whatever defines your `jj*`
aliases. The installer checks this and warns if it can tell you've got it backwards.

## What the conf.d file adds

jjhelp's flows tell you to run `jj cl`, `jj evolve`, `jj tug`, `jj sync`. Those aren't
stock jj — they're aliases, which is why they ship alongside the chart rather than the
chart describing commands you don't have.

The file lands in `~/.config/jj/conf.d/`, which jj loads *in addition to* your
`config.toml` — so installing it doesn't rewrite a config you already have. If you'd
rather not take the aliases, skip that file; the chart reads your config either way and
will simply show whatever you do have.

The highlights:

| Alias      | Does                                                              |
| ---------- | ----------------------------------------------------------------- |
| `jj sync`  | fetch every remote — always safe, fetching never merges in jj     |
| `jj evolve`| rebase onto the new `trunk()`, dropping changes that landed upstream |
| `jj tug`   | advance the closest bookmark to your working copy                 |
| `jj cl`    | push the latest described, non-empty change, inventing the bookmark |

`tug` and `cl` also depend on the two `[revsets]` entries in that file — without them
they disagree about which change is "the" one, so don't cherry-pick just the `[aliases]`
table.

## Customizing

Edit `~/.config/zsh/jjhelp.zsh` directly — the glosses, flows, and git→jj table are
plain arrays at the top of the file, written to be edited. The chart reads your aliases
live, so anything you add to your own config shows up without touching jjhelp at all.

The bookmark name shown for `jj cl` is resolved from your
`templates.git_push_bookmark` at runtime, so it reflects whatever prefix you actually
use.

## Credits

The optional extras in `jjhelp -p` are borrowed from
[jj-vcs/jj discussion #8484](https://github.com/jj-vcs/jj/discussions/8484) and
[zerowidth.com/2025/jj-tips-and-tricks](https://zerowidth.com/2025/jj-tips-and-tricks/).

## License

MIT

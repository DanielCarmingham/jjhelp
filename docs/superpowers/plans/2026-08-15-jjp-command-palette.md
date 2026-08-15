# jjp Command Palette Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `jjp`, an intent-first fzf command palette for jj workflows that inserts generated commands into the zsh prompt.

**Architecture:** Add a small Rust binary named `jjp-bin` that owns action definitions, fzf selection, parameter resolution, preview generation, shell quoting, and command rendering. Add a zsh wrapper function named `jjp` that calls `jjp-bin` and inserts successful output into the prompt with `print -z`; keep `jjhelp` as the static reference.

**Tech Stack:** Rust standard library, Cargo, zsh, fzf CLI, jj CLI, existing shell tests.

**Spec:** `docs/superpowers/specs/2026-08-15-jjp-command-palette-design.md`

## Global Constraints

- Keep `jjhelp`; do not replace the static chart.
- First version is insert-only; no generated command should auto-run.
- Do not implement a custom fuzzy matcher or full-screen TUI.
- `fzf` is the terminal UI and matching engine.
- `jjp-bin` owns command generation and prints exactly one shell command on success.
- `jjp` zsh wrapper inserts successful `jjp-bin` output with `print -z`.
- Actions are hardcoded in Rust for the first version.
- Keep alias expansion separate from `jjhelp -F` initially.
- Avoid PR-oriented actions in the first-screen action set.
- Use Unix LF line endings for shell scripts.

---

## File Structure

- Create `Cargo.toml`: Cargo package metadata with one binary target, `jjp-bin`.
- Create `src/main.rs`: CLI entry point, argument parsing, process exit mapping.
- Create `src/actions.rs`: action structs, initial action registry, candidate rows, previews.
- Create `src/render.rs`: template rendering, parameter substitution, shell quoting, command joining.
- Create `src/fzf.rs`: fzf process adapter for action and value selection.
- Create `src/params.rs`: typed parameter definitions and resolvers for bookmark, revision, file, remote, and free text.
- Modify `jjhelp.zsh`: add `jjp` wrapper while preserving existing `jjhelp`.
- Modify `install.sh`: install `jjp-bin` and keep sourcing `jjhelp.zsh`.
- Modify `README.md`: document `jjp`, dependencies, insert-only behavior, and examples.
- Create `tests/jjp-bin.zsh`: integration tests with fake `fzf` and fake `jj`.
- Keep `tests/jjhelp-flows-expanded.zsh`: existing flow regression test.

---

### Task 1: Rust Scaffold And Core Action Registry

**Files:**
- Create: `Cargo.toml`
- Create: `src/main.rs`
- Create: `src/actions.rs`

**Interfaces:**
- Produces: `actions::Action`, `actions::Step`, `actions::ParamSpec`, `actions::actions() -> Vec<Action>`.
- Produces: `Action::candidate_row(&self) -> String`.
- Produces: `Action::preview(&self) -> String`.

- [ ] **Step 1: Write failing tests for action registry and searchable rows**

Add unit tests in `src/actions.rs`:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn action_registry_contains_first_version_actions() {
        let ids: Vec<&str> = actions().iter().map(|a| a.id).collect();
        assert_eq!(
            ids,
            vec![
                "land-main",
                "catch-up",
                "describe-change",
                "split-change",
                "undo-last-operation",
                "inspect-change",
                "move-bookmark",
                "push-bookmark",
            ]
        );
    }

    #[test]
    fn candidate_row_contains_id_title_tags_shortcuts_expansions_and_description() {
        let action = actions()
            .into_iter()
            .find(|a| a.id == "land-main")
            .expect("land-main action");

        let row = action.candidate_row();

        assert!(row.contains("land-main"));
        assert!(row.contains("land current work on main"));
        assert!(row.contains("push publish done main bookmark"));
        assert!(row.contains("jj tug {bookmark}"));
        assert!(row.contains("jj bookmark advance {bookmark}"));
        assert!(row.contains("Move main to the current change"));
    }

    #[test]
    fn preview_teaches_shortcuts_and_expanded_commands() {
        let action = actions()
            .into_iter()
            .find(|a| a.id == "land-main")
            .expect("land-main action");

        let preview = action.preview();

        assert!(preview.contains("Why:"));
        assert!(preview.contains("jj sync"));
        assert!(preview.contains("jj git fetch --all-remotes"));
        assert!(preview.contains("jj tug {bookmark}"));
        assert!(preview.contains("jj bookmark advance {bookmark}"));
        assert!(preview.contains("Will insert:"));
    }
}
```

- [ ] **Step 2: Run tests and verify they fail because the crate does not exist**

Run: `cargo test`

Expected: FAIL because `Cargo.toml` and `src/actions.rs` do not exist.

- [ ] **Step 3: Add minimal Cargo scaffold**

Create `Cargo.toml`:

```toml
[package]
name = "jjhelp"
version = "0.1.0"
edition = "2021"

[[bin]]
name = "jjp-bin"
path = "src/main.rs"
```

Create `src/main.rs`:

```rust
mod actions;

fn main() {
    eprintln!("jjp-bin is not implemented yet");
    std::process::exit(2);
}
```

- [ ] **Step 4: Implement `src/actions.rs` minimally**

Define:

```rust
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ParamSpec {
    Bookmark { name: &'static str, default: Option<&'static str>, prompt: bool },
    Revision { name: &'static str, default: Option<&'static str>, prompt: bool },
    File { name: &'static str },
    Remote { name: &'static str },
    Text { name: &'static str, prompt: &'static str },
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Step {
    pub shortcut: &'static str,
    pub expanded: Option<&'static str>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Action {
    pub id: &'static str,
    pub title: &'static str,
    pub description: &'static str,
    pub tags: &'static [&'static str],
    pub params: &'static [ParamSpec],
    pub steps: &'static [Step],
}
```

Implement `actions()`, `candidate_row()`, and `preview()`.

Initial action details:

- `land-main`: `jj sync`, `jj evolve`, `jj tug {bookmark}`, `jjgp --bookmark {bookmark}`; bookmark default `main`.
- `catch-up`: `jj sync`, `jj evolve`; no params.
- `describe-change`: `jjdmsg {message}`; text param `message`.
- `split-change`: `jjsp`; no params.
- `undo-last-operation`: `jj op log`, `jj undo`; no params.
- `inspect-change`: `jjst`, `jj mdiff`, `jj ls`; no params.
- `move-bookmark`: `jj tug {bookmark}`; bookmark param prompted.
- `push-bookmark`: `jjgp --bookmark {bookmark}`; bookmark param prompted.

- [ ] **Step 5: Run tests and verify they pass**

Run: `cargo test`

Expected: PASS for action registry tests.

---

### Task 2: Command Rendering And Shell Quoting

**Files:**
- Modify: `src/render.rs`
- Modify: `src/main.rs`
- Modify: `src/actions.rs`

**Interfaces:**
- Produces: `render::shell_quote(value: &str) -> String`.
- Produces: `render::render_template(template: &str, values: &HashMap<String, String>) -> String`.
- Produces: `render::render_action(action: &Action, values: &HashMap<String, String>) -> String`.

- [ ] **Step 1: Write failing render tests**

Create `src/render.rs` with tests:

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use crate::actions::actions;
    use std::collections::HashMap;

    #[test]
    fn shell_quote_leaves_safe_words_unquoted() {
        assert_eq!(shell_quote("main"), "main");
        assert_eq!(shell_quote("@"), "@");
        assert_eq!(shell_quote("trunk()"), "'trunk()'");
    }

    #[test]
    fn shell_quote_handles_spaces_and_single_quotes() {
        assert_eq!(shell_quote("hello world"), "'hello world'");
        assert_eq!(shell_quote("don't"), "'don'\\''t'");
    }

    #[test]
    fn render_template_replaces_named_parameters() {
        let mut values = HashMap::new();
        values.insert("bookmark".to_string(), "main".to_string());

        assert_eq!(
            render_template("jjgp --bookmark {bookmark}", &values),
            "jjgp --bookmark main"
        );
    }

    #[test]
    fn render_action_joins_steps_with_and_and() {
        let action = actions()
            .into_iter()
            .find(|a| a.id == "land-main")
            .expect("land-main action");
        let mut values = HashMap::new();
        values.insert("bookmark".to_string(), "main".to_string());

        assert_eq!(
            render_action(&action, &values),
            "jj sync && jj evolve && jj tug main && jjgp --bookmark main"
        );
    }
}
```

- [ ] **Step 2: Run tests and verify failure**

Run: `cargo test`

Expected: FAIL because `render` functions are undefined.

- [ ] **Step 3: Implement `src/render.rs`**

Implement safe word detection for ASCII alphanumerics plus `@`, `_`, `-`, `.`, `/`.
Single-quote anything else using POSIX shell quoting:

```text
abc        -> abc
hello you  -> 'hello you'
don't      -> 'don'\''t'
```

Template rendering should replace `{name}` with `shell_quote(values[name])`.
If a value is missing, leave the placeholder unchanged.

- [ ] **Step 4: Wire module**

Add `mod render;` to `src/main.rs`.

- [ ] **Step 5: Run tests and verify pass**

Run: `cargo test`

Expected: PASS.

---

### Task 3: Non-Interactive CLI Modes

**Files:**
- Modify: `src/main.rs`
- Modify: `src/actions.rs`
- Modify: `src/render.rs`

**Interfaces:**
- Produces: `jjp-bin --list`.
- Produces: `jjp-bin --preview <action-id>`.
- Produces: `jjp-bin --print <action-id> [name=value ...]`.

- [ ] **Step 1: Write failing integration tests with `cargo run`**

Add tests in `src/main.rs`:

```rust
#[cfg(test)]
mod tests {
    use crate::actions::find_action;
    use crate::render::render_action_with_defaults;

    #[test]
    fn render_land_main_with_defaults() {
        let action = find_action("land-main").expect("land-main");
        assert_eq!(
            render_action_with_defaults(action),
            "jj sync && jj evolve && jj tug main && jjgp --bookmark main"
        );
    }
}
```

Also add shell integration checks to `tests/jjp-bin.zsh`:

```zsh
#!/usr/bin/env zsh
set -eu

repo=${0:A:h:h}

cargo run --quiet --bin jjp-bin -- --list | grep -q 'land-main'
cargo run --quiet --bin jjp-bin -- --preview land-main | grep -q 'jj bookmark advance'
cmd=$(cargo run --quiet --bin jjp-bin -- --print land-main)
[[ $cmd == 'jj sync && jj evolve && jj tug main && jjgp --bookmark main' ]]
cmd=$(cargo run --quiet --bin jjp-bin -- --print push-bookmark bookmark=release)
[[ $cmd == 'jjgp --bookmark release' ]]
```

- [ ] **Step 2: Run tests and verify failure**

Run: `cargo test && zsh tests/jjp-bin.zsh`

Expected: FAIL because CLI modes are not implemented.

- [ ] **Step 3: Implement action lookup and defaults**

Add `actions::find_action(id: &str) -> Option<&'static Action>`.
Add `render::default_values(action: &Action) -> HashMap<String, String>`.
Add `render::render_action_with_defaults(action: &Action) -> String`.

- [ ] **Step 4: Implement CLI argument parsing in `main`**

Supported flags:

- `--list`: print candidate rows.
- `--preview <id>`: print action preview.
- `--print <id> [name=value ...]`: render command with defaults plus overrides.
- unknown action: print `unknown action: <id>` to stderr and exit 2.
- unknown flag: print usage and exit 2.

- [ ] **Step 5: Run tests and verify pass**

Run: `cargo test && zsh tests/jjp-bin.zsh`

Expected: PASS.

---

### Task 4: fzf Action Selection

**Files:**
- Create: `src/fzf.rs`
- Modify: `src/main.rs`
- Modify: `tests/jjp-bin.zsh`

**Interfaces:**
- Produces: `fzf::select_action(query: Option<&str>) -> Result<Option<String>, String>`.
- Produces: default `jjp-bin [query]` interactive path.

- [ ] **Step 1: Extend failing shell tests with fake fzf**

Update `tests/jjp-bin.zsh`:

```zsh
tmp=${TMPDIR:-/tmp}/jjp-bin.$$
mkdir -p "$tmp/bin"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/bin/fzf" <<'FZF'
#!/bin/sh
cat >/dev/null
printf 'land-main\tland current work on main\n'
FZF
chmod +x "$tmp/bin/fzf"

PATH="$tmp/bin:$PATH" cargo run --quiet --bin jjp-bin -- > "$tmp/out"
[[ "$(cat "$tmp/out")" == 'jj sync && jj evolve && jj tug main && jjgp --bookmark main' ]]
```

- [ ] **Step 2: Run test and verify failure**

Run: `zsh tests/jjp-bin.zsh`

Expected: FAIL because default interactive fzf path is not implemented.

- [ ] **Step 3: Implement fzf adapter**

Spawn:

```text
fzf --delimiter \t --with-nth 2.. --preview 'jjp-bin --preview {1}'
```

Write `actions().candidate_row()` to fzf stdin.
Read stdout.
Return the first tab-delimited field as the action id.
If fzf exits with code 130 or returns empty stdout, return `Ok(None)`.

- [ ] **Step 4: Implement default CLI behavior**

When no flag is passed, call `select_action(None)`, render selected action with defaults, print command, and exit 0.
When positional query words are passed, pass the joined query to fzf using `--query <query>`.

- [ ] **Step 5: Run tests and verify pass**

Run: `cargo test && zsh tests/jjp-bin.zsh`

Expected: PASS.

---

### Task 5: Parameter Resolvers

**Files:**
- Create: `src/params.rs`
- Modify: `src/main.rs`
- Modify: `src/fzf.rs`
- Modify: `src/render.rs`
- Modify: `tests/jjp-bin.zsh`

**Interfaces:**
- Produces: `params::resolve_params(action: &Action) -> Result<Option<HashMap<String, String>>, String>`.
- Produces: `fzf::select_value(prompt: &str, rows: &[String]) -> Result<Option<String>, String>`.

- [ ] **Step 1: Write failing tests for prompted bookmark action**

Update fake `fzf` in `tests/jjp-bin.zsh` to select different rows by prompt:

```sh
case "$*" in
  *'--prompt action>'*)
    cat >/dev/null
    printf 'push-bookmark\tpush bookmark\n'
    ;;
  *'--prompt bookmark>'*)
    cat >/dev/null
    printf 'release\n'
    ;;
esac
```

Run:

```zsh
PATH="$tmp/bin:$PATH" cargo run --quiet --bin jjp-bin -- > "$tmp/out"
[[ "$(cat "$tmp/out")" == 'jjgp --bookmark release' ]]
```

- [ ] **Step 2: Run test and verify failure**

Run: `zsh tests/jjp-bin.zsh`

Expected: FAIL because parameter resolution is not implemented.

- [ ] **Step 3: Implement value picker support in `fzf.rs`**

`select_value(prompt, rows)` should run `fzf --prompt "<prompt>"`, write rows to stdin, and return the selected first field.

- [ ] **Step 4: Implement live list commands in `params.rs`**

For first version:

- bookmark rows: `jj bookmark list`, first field before `:`.
- revision rows: `jj log -r 'trunk() | @ | ancestors(@, 20)' --no-graph`, raw line as selectable row.
- file rows: `jj diff --name-only`, fallback `jj file list`.
- remote rows: `jj git remote list`, first field.
- text rows: use `print -r --` prompt only if running in a terminal; otherwise return an error that text prompting is interactive-only.

For params with `prompt: false` and a default, use the default without invoking fzf.

- [ ] **Step 5: Resolve params before rendering selected action**

Default interactive path:

1. select action,
2. resolve params,
3. render command,
4. print command.

`--print` remains non-interactive and uses defaults plus explicit overrides only.

- [ ] **Step 6: Run tests and verify pass**

Run: `cargo test && zsh tests/jjp-bin.zsh`

Expected: PASS.

---

### Task 6: zsh Wrapper, Install, And Documentation

**Files:**
- Modify: `jjhelp.zsh`
- Modify: `install.sh`
- Modify: `README.md`
- Modify: `tests/jjp-bin.zsh`

**Interfaces:**
- Produces: zsh function `jjp`.
- Produces: installer copying `target/release/jjp-bin` or building it when Cargo exists.

- [ ] **Step 1: Write failing shell checks for wrapper text**

Add to `tests/jjp-bin.zsh`:

```zsh
grep -q 'jjp()' "$repo/jjhelp.zsh"
grep -q 'print -z "$cmd"' "$repo/jjhelp.zsh"
grep -q 'jjp-bin' "$repo/install.sh"
grep -q 'jjp' "$repo/README.md"
```

- [ ] **Step 2: Run test and verify failure**

Run: `zsh tests/jjp-bin.zsh`

Expected: FAIL because wrapper/install/docs are not wired.

- [ ] **Step 3: Add `jjp` wrapper to `jjhelp.zsh`**

Append:

```zsh
jjp() {
  emulate -L zsh
  local cmd
  cmd="$(jjp-bin "$@")" || return
  [[ -n $cmd ]] || return 1
  print -z "$cmd"
}
```

- [ ] **Step 4: Update installer**

Installer behavior:

- If `cargo` exists, run `cargo build --release --bin jjp-bin`.
- Install `target/release/jjp-bin` to `~/.local/bin/jjp-bin`.
- If `cargo` is missing, warn that `jjp` requires building `jjp-bin`; still install `jjhelp.zsh` and jj config.
- On uninstall, remove `~/.local/bin/jjp-bin`.

- [ ] **Step 5: Update README**

Document:

- `jjhelp`: static reference.
- `jjp`: interactive palette.
- Requires `fzf`; Rust/Cargo required to build from source.
- `jjp` inserts commands into the prompt and does not run them.
- Examples: `jjp`, `jjp land`, `jjp --print land-main`.

- [ ] **Step 6: Run tests and verify pass**

Run: `cargo test && zsh tests/jjp-bin.zsh && zsh -n jjhelp.zsh install.sh tests/jjp-bin.zsh tests/jjhelp-flows-expanded.zsh`

Expected: PASS.

---

### Task 7: Final Verification And Cleanup

**Files:**
- Modify only if verification exposes issues.

**Interfaces:**
- Validates all prior interfaces.

- [ ] **Step 1: Run Rust tests**

Run: `cargo test`

Expected: PASS.

- [ ] **Step 2: Run shell integration tests**

Run: `zsh tests/jjp-bin.zsh && zsh tests/jjhelp-flows-expanded.zsh`

Expected: PASS.

- [ ] **Step 3: Run syntax checks**

Run: `zsh -n jjhelp.zsh install.sh tests/jjp-bin.zsh tests/jjhelp-flows-expanded.zsh`

Expected: exit 0.

- [ ] **Step 4: Run whitespace and line-ending checks**

Run:

```sh
git diff --check
perl -ne 'exit 1 if /\r/' jjhelp.zsh install.sh tests/jjp-bin.zsh tests/jjhelp-flows-expanded.zsh README.md Cargo.toml src/main.rs src/actions.rs src/render.rs src/fzf.rs src/params.rs
```

Expected: both commands exit 0.

- [ ] **Step 5: Manual smoke test**

Run:

```sh
cargo run --quiet --bin jjp-bin -- --list
cargo run --quiet --bin jjp-bin -- --preview land-main
cargo run --quiet --bin jjp-bin -- --print land-main
```

Expected:

- `--list` prints tab-delimited actions.
- `--preview land-main` explains shortcut and expanded commands.
- `--print land-main` prints `jj sync && jj evolve && jj tug main && jjgp --bookmark main`.

- [ ] **Step 6: Review changed files**

Run: `git status --short` and `git diff --stat`.

Expected: only intended files changed or added.

---

## Self-Review

Spec coverage:

- Intent-first palette: Tasks 1, 4, 6.
- fzf first screen and matching: Tasks 1 and 4.
- Preview pane teaching shortcut and expanded commands: Tasks 1 and 3.
- Typed parameters: Task 5.
- Insert-only zsh wrapper: Task 6.
- No PR-oriented first-screen actions: Task 1 action list.
- Error handling for missing/cancelled fzf and missing tools: Tasks 4 and 5.
- Testing requirements: Tasks 1 through 7.

Placeholder scan:

- The plan contains no placeholder markers.
- No task delegates unspecified test work; each task names concrete tests and commands.

Type consistency:

- `Action`, `Step`, `ParamSpec`, `actions()`, `find_action()`, render functions, fzf functions, and param resolver signatures are named consistently across tasks.

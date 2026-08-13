#!/usr/bin/env bash
# jjhelp installer. Idempotent — safe to re-run to pick up updates.
#
#   ./install.sh              install
#   ./install.sh --uninstall  remove
#
# Installs two files and adds one line to .zshrc:
#   ~/.config/zsh/jjhelp.zsh            the chart itself (sourced, not on PATH)
#   ~/.config/jj/conf.d/50-jjhelp.toml  the jj aliases the chart documents
set -euo pipefail

src_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

zsh_dir="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
jj_conf_d="${XDG_CONFIG_HOME:-$HOME/.config}/jj/conf.d"
zshrc="$HOME/.zshrc"

# Matched when deciding whether .zshrc already sources us, so that re-running
# doesn't append a second copy.
marker='jjhelp.zsh'
source_line='[[ -r ~/.config/zsh/jjhelp.zsh ]] && source ~/.config/zsh/jjhelp.zsh'

say()  { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }

uninstall() {
  rm -f "$zsh_dir/jjhelp.zsh" "$jj_conf_d/50-jjhelp.toml"
  say "removed jjhelp.zsh and 50-jjhelp.toml"
  if [ -f "$zshrc" ] && grep -q "$marker" "$zshrc"; then
    warn "left the source line in $zshrc — remove it by hand:"
    grep -n "$marker" "$zshrc" >&2 || true
  fi
  say "done. restart your shell."
  exit 0
}

[ "${1:-}" = "--uninstall" ] && uninstall

# --- prerequisites ----------------------------------------------------------
command -v zsh >/dev/null 2>&1 || warn "zsh not found — jjhelp is a zsh function"
command -v jj  >/dev/null 2>&1 || warn "jj not found — the chart will render, but with no jj config rows"

# --- files ------------------------------------------------------------------
mkdir -p "$zsh_dir" "$jj_conf_d"
install -m 0644 "$src_dir/jjhelp.zsh" "$zsh_dir/jjhelp.zsh"
say "installed $zsh_dir/jjhelp.zsh"

# conf.d is additive: jj loads every .toml there after config.toml, so this
# never rewrites a config you already have.
if [ -e "$jj_conf_d/50-jjhelp.toml" ] && \
   ! cmp -s "$src_dir/jj/50-jjhelp.toml" "$jj_conf_d/50-jjhelp.toml"; then
  cp -- "$jj_conf_d/50-jjhelp.toml" "$jj_conf_d/50-jjhelp.toml.bak"
  say "backed up your existing 50-jjhelp.toml to 50-jjhelp.toml.bak"
fi
install -m 0644 "$src_dir/jj/50-jjhelp.toml" "$jj_conf_d/50-jjhelp.toml"
say "installed $jj_conf_d/50-jjhelp.toml"

# Warn rather than fail: an alias you already define wins over ours only if it
# sits in a conf.d file sorting after 50-, which is worth knowing about.
if command -v jj >/dev/null 2>&1; then
  for a in tug sync evolve cl; do
    jj config get "aliases.$a" >/dev/null 2>&1 || warn "jj alias '$a' did not take effect — check for a conflicting conf.d file"
  done
fi

# --- .zshrc -----------------------------------------------------------------
if [ -f "$zshrc" ] && grep -q "$marker" "$zshrc"; then
  say "$zshrc already sources jjhelp — left it alone"
else
  printf '\n# jjhelp — jj quick-reference chart. Must be sourced (it reads `alias`),\n# and sourced AFTER the jj plugin so the aliases exist.\n%s\n' \
    "$source_line" >> "$zshrc"
  say "added the source line to $zshrc"
fi

# jjhelp reads the live alias table, so it has to be sourced after whatever
# defines the jj* aliases. Sourcing it first isn't an error — you just silently
# lose ~38 rows, which is exactly the failure this check exists to catch.
if [ -f "$zshrc" ] && grep -q 'plugins=.*\bjj\b' "$zshrc"; then
  plugin_ln=$(grep -n 'plugins=.*\bjj\b' "$zshrc" | head -1 | cut -d: -f1)
  jjhelp_ln=$(grep -n "$marker" "$zshrc" | head -1 | cut -d: -f1)
  if [ "$jjhelp_ln" -lt "$plugin_ln" ]; then
    warn "the jjhelp source line (line $jjhelp_ln) comes BEFORE your jj plugin (line $plugin_ln)."
    warn "move it after, or the shell-alias section of the chart will be empty."
  fi
else
  say "note: the oh-my-zsh 'jj' plugin supplies ~38 of the chart's rows — worth adding to plugins=()"
fi

say
say "done. restart your shell (or: exec zsh), then run: jjhelp"

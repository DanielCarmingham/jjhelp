#!/usr/bin/env zsh
set -eu

repo=${0:A:h:h}
tmp=${TMPDIR:-/tmp}/jjhelp-expanded.$$
mkdir -p "$tmp/bin"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/bin/jj" <<'JJ'
#!/bin/sh
case "$*" in
  "--no-pager config list aliases -T "*)
    printf 'aliases.sync\t["git", "fetch", "--all-remotes"]@@E@@\n'
    printf 'aliases.evolve\t["rebase", "--skip-emptied", "-o", "trunk()"]@@E@@\n'
    printf 'aliases.cl\t["git", "push", "-c", "pushable_on_branch"]@@E@@\n'
    printf 'aliases.tug\t["bookmark", "advance"]@@E@@\n'
    ;;
  "--no-pager config list revset-aliases -T "*)
    ;;
  "--no-pager config get templates.git_push_bookmark")
    printf '"push-" ++ change_id.short()\n'
    ;;
esac
JJ
chmod +x "$tmp/bin/jj"

PATH="$tmp/bin:$PATH"

alias jjnt='jj new "trunk()"'
alias jjdmsg='jj desc --message'
alias jjgp='jj git push'

source "$repo/jjhelp.zsh"

flows=$(jjhelp -f)
expanded=$(jjhelp -F)

[[ $flows == *'happy path'* ]]
[[ $flows == *'jj sync               — fetch FIRST'* ]]
[[ $flows == *'jjgp --bookmark main  — push the named bookmark'* ]]
[[ $flows == *'catch up'* ]]
[[ $flows == *'undo mistake'* ]]
[[ $flows == *'jj op log'* ]]
[[ $flows == *'jj undo'* ]]
[[ $flows != *'open a PR'* ]]
[[ $flows != *'gh pr create'* ]]
[[ $flows != *'jj sync = jj git fetch --all-remotes'* ]]

[[ $expanded == *'jjnt = jj new "trunk()"'* ]]
[[ $expanded == *'jjdmsg "…" = jj desc --message "…"'* ]]
[[ $expanded == *'jj sync = jj git fetch --all-remotes'* ]]
[[ $expanded == *'jj evolve = jj rebase --skip-emptied -o trunk()'* ]]
[[ $expanded == *'jj tug main = jj bookmark advance main'* ]]
[[ $expanded == *'jjgp --bookmark main = jj git push --bookmark main'* ]]
[[ $expanded == *'jj op log'* ]]
[[ $expanded == *'jj undo'* ]]
[[ $expanded != *'open a PR'* ]]
[[ $expanded != *'gh pr create'* ]]
[[ $expanded == *'flows expanded · jjhelp -f for shortcuts only'* ]]

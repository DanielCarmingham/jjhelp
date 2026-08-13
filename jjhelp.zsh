# jjhelp — quick reference for the jj (Jujutsu) shortcuts this shell has.
#
# Everything except the "proposed" section is read from live sources on every
# run, so the chart cannot drift from reality:
#
#   shell aliases    alias -m 'jj*'                  (oh-my-zsh jj plugin + local ones)
#   config aliases   jj config list aliases
#   revsets          jj config list revset-aliases
#
# An alias body is usually its own best description (jjba -> jj bookmark
# advance), so only the cryptic ones get a hand-written gloss in
# _jjhelp_gloss below. Anything without a gloss just shows its definition.
#
#   jjhelp           installed shortcuts
#   jjhelp push      rows whose name, body, or gloss matches "push"
#   jjhelp -p        also list optional extras you might want to install
#
# Everything is written to stdout rather than stderr, so `jjhelp | grep` and
# `jjhelp > cheatsheet.txt` both do what you'd expect.
#
# This has to be sourced, not run as a script on PATH: `alias` is shell state a
# child process cannot see, so a standalone script would render the shell-alias
# section empty — silently, since the rest of the chart would still work.
# Source it AFTER the jj plugin, so the aliases exist by the time it runs.

typeset -gA _jjhelp_gloss=(
  # --- shell aliases whose expansion doesn't tell the whole story ---
  jjla                'log every change, not just the default revset'
  jjnt                'start a new change on top of trunk()'
  jjrbm               'rebase onto trunk()'
  jjrt                'cd to the repo root'
  jjgfa               'fetch from every remote, not just the default'
  lj                  'lazyjj, the jj TUI'
  # --- config aliases (jj <name>) ---
  tug                 'advance the closest bookmarks — pass a name to move just one'
  sync                'fetch every remote — always do this before landing work'
  evolve              'rebase onto trunk(), dropping changes that emptied out — jj lands by rebase, never a merge'
  pullup              'evolve every straggler sitting on immutable history'
  cl                  'push latest real change, inventing bookmark @PUSHPFX@<id> — the PR path'
  push                'push every bookmark — fallback when the default push revset finds nothing'
  amend               'squash into the parent change'
  xl                  'log every change in the repo'
  pl                  'evolution log of @, with diffs'
  mdiff               'diff @ against trunk()'
  ls                  'names of the files @ touches'
  fork                'add a "mine" remote and point pushes at it'
  configure           'edit the repo-local jj config'
  init                'colocate jj onto the git repo in .'
  '..'                'move to the parent change and edit it'
  ',,'                'move to the child change and edit it'
  # --- revsets ---
  stragglers          'mutable changes sitting directly on immutable history'
  pushable_on_branch  'latest described, non-empty change between trunk() and @'
)

# Optional extras, shown by `jjhelp -p`. These are NOT installed by jjhelp —
# they're good ideas worth stealing if they fit how you work. Borrowed from
# jj-vcs/jj discussion #8484 and zerowidth.com/2025/jj-tips-and-tricks.
# Format: name <TAB> definition <TAB> gloss
typeset -ga _jjhelp_proposed=(
  $'restack\trebase -o trunk() -s "roots(trunk()..) & mutable()"\trestack every mutable branch onto trunk()'
  $'collapse\tsquash -f "branch_start(@)+::@" -t "branch_start(@)"\tfold the whole branch into one change'
  $'open\tlog -r "heads(mine()) ~ ::trunk()"\tyour branches not yet merged into trunk()'
  $'log-recent\tlog -r "default() & recent()"\tdefault log, last month only (needs a recent() revset)'
  $'slice\tlog -r "slice(@)"\tthe current branch end to end (needs a slice() revset)'
  $'difft\tdiff --tool difft\tdiff through difftastic'
  $'fetch-pr\tutil exec -- bash -c "git fetch origin pull/$1/head"\tfetch a GitHub PR as a local change'
)

# The bookmark name `cl` invents comes from templates.git_push_bookmark, which
# people customize (a "you/push-" prefix is a common one). Resolve it from live
# config instead of hardcoding a name that would be wrong on every other
# machine. Runs once per shell on first use, not at source time, so startup
# doesn't pay for a `jj` subprocess.
typeset -g _jjhelp_resolved=0
_jjhelp_resolve() {
  (( _jjhelp_resolved )) && return
  _jjhelp_resolved=1

  local pfx='push-' tmpl=''
  (( $+commands[jj] )) && \
    tmpl=$(command jj --no-pager config get templates.git_push_bookmark 2>/dev/null)

  # A template reads like: '"you/push-" ++ change_id.short()'. Take the first
  # double-quoted literal. If the key is unset, or is some shape we don't
  # recognise, fall back to jj's own default of "push-".
  [[ $tmpl == *\"*\"* ]] && pfx=${${tmpl#*\"}%%\"*}

  _jjhelp_gloss[cl]=${_jjhelp_gloss[cl]//@PUSHPFX@/$pfx}
  _jjhelp_flows=( ${_jjhelp_flows[@]//@PUSHPFX@/$pfx} )
}

# Pad $1 out to width $2, never truncating: ${(r:N:)} both pads and chops, which
# quietly turned `jj rebase --skip-emptied -o trunk()` into `... -o trunk`.
# The width is computed before the expansion because a ternary's `:` would
# otherwise terminate the (l:...:) flag and fail to parse.
_jjhelp_pad() {
  local -i n=$2-${#1}
  (( n < 0 )) && n=0
  print -rn -- "$1${(l:$n:: :)}"
}

# Recipes, not aliases — the ordering is the load-bearing part. Verified against
# a scratch colocated repo with a real remote; the notes record what actually
# goes wrong when a step is skipped or reordered.
# Format: flow <TAB> step <TAB> note
typeset -ga _jjhelp_flows=(
  $'happy path\tjj new main\tstart a change off main — no branch needed, name it later or never'
  $'happy path\t(edit files)\tsnapshotted automatically — no add, no stage, no stash'
  $'happy path\tjj describe -m "…"\tnames the change you are ON (jj commit = describe + new)'
  $'happy path\tjj cl\tpush it — the bookmark is invented for you'
  $'land on main\tjj sync\tfetch FIRST — skipping this gets the push rejected as "stale info"'
  $'land on main\tjj evolve\trebase onto the new trunk(); this is the "merge", history stays linear'
  $'land on main\tjj tug main\tname it — bare tug advances every closest bookmark, not just main'
  $'land on main\tjj git push --bookmark main\tname it — a bare `jj git push` often finds nothing to push'
  $'open a PR\tjj cl\tpush latest real change as @PUSHPFX@<id>, bookmark auto-created'
  $'open a PR\tgh pr create\t'
  $'open a PR\tjj sync && jj evolve\tafter it merges, to pick up the new trunk()'
)

# Don't mix the two flows on one change: once `cl` puts a push bookmark on it,
# that becomes the closest bookmark and `tug` either moves it instead of main or
# reports "No bookmarks to update" — silently leaving main behind. Landing that
# change on main afterwards needs an explicit `jj bookmark move main --to @`.
# git -> jj translation, shown by `jjhelp -g`. Every "!" note below is something
# a scratch-repo test actually produced, not a remembered rule.
# Format: group <TAB> git <TAB> jj <TAB> note ("" for none)
typeset -ga _jjhelp_rosetta=(
  $'everyday\tgit status\tjj st\t'
  $'everyday\tgit add -A  (staging)\t— nothing —\tthere is no index: @ is your working commit, snapshotted on every command'
  $'everyday\tgit add -p\tjj split / jj squash -i / jj absorb\tcarve a change up AFTER the fact instead of staging before'
  $'everyday\tgit commit -m "…"\tjj describe -m "…"\tdescribes the change you are ON. jj commit = describe + new'
  $'everyday\tgit commit --amend\tjj describe / jj squash\troutine, not a rewrite — descendants rebase themselves, no force-push dance'
  $'everyday\tgit stash\tjj new\tjust start another change; nothing to pop, nothing to lose'
  $'everyday\tgit checkout -- FILE\tjj restore FILE\trestores paths from the parent by default'
  $'branching\tgit checkout -b feat\tjj new main\ta bookmark is optional — name it later, or let jj cl invent one'
  $'branching\tgit switch feat\tjj new REV  (preferred)\tjj edit REV also works, but jj help says prefer new + squash'
  $'branching\tgit branch -f main HEAD\tjj tug main / jj bookmark move main --to @\tnothing moves a bookmark for you — this is the step git hides'
  $'syncing\tgit pull\tjj sync  then  jj evolve\tfetching never merges; you rebase deliberately'
  $'syncing\tgit merge main\tjj rebase -d main\tjj lands work by rebasing — history stays linear, no merge commit'
  $'syncing\tgit rebase -i\tjj squash / jj split / jj describe REV\tno interactive mode: edit any commit directly, descendants follow'
  $'syncing\tgit push -u origin feat\tjj git push --bookmark feat  /  jj cl\tpushes BOOKMARKS, never "the current branch"'
  $'undo\tgit reflog + git reset --hard\tjj op log + jj undo / jj op restore\tundoes ANY operation, not just commits — the real safety net'
  $'undo\tgit log --oneline --all\tjj log -r "all()"  (jj xl)\tplain jj log shows your work, not the whole repo'
  $'conflicts\t(rebase halts, must resolve)\t(rebase completes, conflict is committed)\tverified: rebase exited 0, marked the commit (conflict), and let me work elsewhere'
  $'conflicts\tgit mergetool\tjj resolve  (or edit markers, then jj squash)\tresolve whenever you like — nothing is blocked meanwhile'
)

typeset -g _jjhelp_flows_footnote='don'\''t mix flows on one change: after `cl`, tug stops advancing main'

jjhelp() {
  emulate -L zsh
  setopt local_options extended_glob no_nomatch

  local show_proposed=0 show_rosetta=0 only_flows=0 filter=''
  while (( $# )); do
    case $1 in
      -p|--proposed) show_proposed=1 ;;
      -g|--git)      show_rosetta=1 ;;
      -f|--flows)    only_flows=1 ;;
      -h|--help)
        print -r -- 'jjhelp [-f|--flows] [-g|--git] [-p|--proposed] [filter]'
        print -r -- '  -f   just the flows (recipes), without the alias chart'
        print -r -- '  -g   git -> jj translation table, with notes and foot-guns'
        print -r -- '  -p   also list borrowed aliases we have not installed'
        print -r -- '  filter   show only rows matching this text'
        print -r -- ''
        print -r -- 'plain jjhelp = alias chart + flows; -f and -g are views on their own'
        return 0 ;;
      *) filter=$1 ;;
    esac
    shift
  done

  _jjhelp_resolve

  local head name dim off
  if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
    head=$'\e[1;37m' name=$'\e[0;36m' dim=$'\e[1;30m' off=$'\e[0m'
  else
    head='' name='' dim='' off=''
  fi

  # --- git -> jj translation (its own view; the alias chart isn't shown) ----
  if (( show_rosetta )); then
    local -a rcells rgroups rkept
    local rg rline
    for rline in $_jjhelp_rosetta; do
      [[ -n $filter && ${(L)rline} != *${(L)filter}* ]] && continue
      rkept+=( "$rline" )
      rg=${rline%%$'\t'*}
      (( ${rgroups[(I)$rg]} )) || rgroups+=( "$rg" )
    done
    if (( ! ${#rkept} )); then
      print -r -- "${dim}nothing in the git→jj table matches '${filter}'${off}"
      return 1
    fi
    local -i gw
    for rg in $rgroups; do
      gw=0
      for rline in $rkept; do
        rcells=( ${(ps:\t:)rline} )
        [[ ${rcells[1]} == $rg ]] || continue
        (( ${#rcells[2]} > gw )) && gw=${#rcells[2]}
      done
      print -r -- "${head}── ${rg} ${off}${dim}${(l:$(( 46 - ${#rg} ))::─:)}${off}"
      for rline in $rkept; do
        rcells=( ${(ps:\t:)rline} )
        [[ ${rcells[1]} == $rg ]] || continue
        print -r -- "  ${dim}$(_jjhelp_pad "${rcells[2]}" $gw)${off}  ${name}${rcells[3]}${off}"
        [[ -n ${rcells[4]:-} ]] && print -r -- "  $(_jjhelp_pad '' $gw)  ${dim}! ${rcells[4]}${off}"
      done
      print
    done
    print -r -- "${dim}left: git · right: jj · ! = not obvious, or a foot-gun${off}"
    return 0
  fi

  # Rows are "section<TAB>name<TAB>body<TAB>gloss"; sections render in this order.
  local -a rows sections
  sections=(bookmarks changes log git workspaces other 'config aliases' revsets)

  # --- shell aliases ------------------------------------------------------
  # Skipped wholesale for -f: the flows are static, so there's no reason to
  # shell out to jj twice just to throw the rows away.
  local line n b sect
  local -i shell_alias_rows=0
  for line in ${(f)"$( (( only_flows )) || alias -m 'jj*' 'lj' 2>/dev/null)"}; do
    [[ -n $line ]] || continue
    n=${line%%=*}
    b=${(Q)${line#*=}}
    case $b in
      'jj bookmark'*)          sect=bookmarks ;;
      'jj git'*)               sect=git ;;
      ('jj log'*|'jj obslog'*) sect=log ;;
      'jj workspace'*)         sect=workspaces ;;
      'jj '*)                  sect=changes ;;
      *)                       sect=other ;;
    esac
    rows+=( "$sect"$'\t'"$n"$'\t'"$b"$'\t'"${_jjhelp_gloss[$n]:-}" )
    (( shell_alias_rows++ ))
  done

  # --- jj config aliases and revsets -------------------------------------
  # A single template line per entry, terminated by a sentinel, because values
  # like the `fork` alias are multi-line TOML strings that would otherwise
  # scramble any line-oriented parse.
  if (( $+commands[jj] && ! only_flows )); then
    local raw rec parts
    local -a recs part_arr

    raw=$(command jj --no-pager config list aliases \
            -T 'name ++ "\t" ++ value ++ "@@E@@\n"' 2>/dev/null)
    for rec in ${(ps:@@E@@:)raw}; do
      rec=${rec##$'\n'##}
      [[ -n $rec ]] || continue
      n=${${rec%%$'\t'*}#aliases.}
      n=${n//\"/}
      b=${rec#*$'\t'}
      if [[ $b == *$'\n'* ]]; then
        # Multi-line inline script — don't pretend to render it on one line.
        b='jj … ‹inline script›'
      else
        b=${${b#\[}%\]}
        part_arr=(${(s:, :)b})
        part_arr=(${part_arr//\'/})
        b="jj ${(j: :)part_arr}"
      fi
      rows+=( 'config aliases'$'\t'"$n"$'\t'"$b"$'\t'"${_jjhelp_gloss[$n]:-}" )
    done

    raw=$(command jj --no-pager config list revset-aliases \
            -T 'name ++ "\t" ++ value ++ "@@E@@\n"' 2>/dev/null)
    for rec in ${(ps:@@E@@:)raw}; do
      rec=${rec##$'\n'##}
      [[ -n $rec ]] || continue
      n=${${rec%%$'\t'*}#revset-aliases.}
      n=${n//\"/}
      b=${rec#*$'\t'}
      b=${${b#\'}%\'}
      rows+=( revsets$'\t'"$n"$'\t'"$b"$'\t'"${_jjhelp_gloss[$n]:-}" )
    done
  fi

  # --- filter -------------------------------------------------------------
  local total=$#rows
  if [[ -n $filter ]]; then
    local -a kept
    for line in $rows; do
      [[ ${(L)line} == *${(L)filter}* ]] && kept+=( "$line" )
    done
    rows=( $kept )
  fi

  # Which flows survive the filter. Computed here, not at render time, because
  # the "nothing matched" bail-out below has to account for them: `jjhelp gh`
  # matches no alias but does match `gh pr create` in the PR flow.
  # A recipe fragment is useless, so this keeps or drops whole flows, never
  # individual steps.
  local -a flow_names
  local fname
  for line in $_jjhelp_flows; do
    fname=${line%%$'\t'*}
    [[ -n $filter && ${(L)line} != *${(L)filter}* ]] && continue
    (( ${flow_names[(I)$fname]} )) || flow_names+=( "$fname" )
  done

  # --- render -------------------------------------------------------------
  # Columns are measured per section, so the bookmark aliases stay tight
  # instead of being stretched by a long revset name three sections down.
  # Bodies past $bodycap don't widen the column; they just push their own
  # gloss right rather than indenting every other line to match.
  local -i bodycap=36
  local -a cells section_rows
  local -i nw bw

  for sect in $sections; do
    section_rows=()
    for line in $rows; do
      [[ ${line%%$'\t'*} == $sect ]] && section_rows+=( "$line" )
    done
    (( ${#section_rows} )) || continue

    nw=0 bw=0
    for line in $section_rows; do
      cells=( ${(ps:\t:)line} )
      (( ${#cells[2]} > nw )) && nw=${#cells[2]}
      [[ -n ${cells[4]} ]] && (( ${#cells[3]} > bw && ${#cells[3]} <= bodycap )) && bw=${#cells[3]}
    done
    print -r -- "${head}── ${sect} ${off}${dim}${(l:$(( 46 - ${#sect} ))::─:)}${off}"
    for line in $section_rows; do
      cells=( ${(ps:\t:)line} )
      n=${cells[2]}; b=${cells[3]}
      if [[ -n ${cells[4]} ]]; then
        print -r -- "  ${name}$(_jjhelp_pad "$n" $nw)${off}  $(_jjhelp_pad "$b" $bw)  ${dim}— ${cells[4]}${off}"
      else
        print -r -- "  ${name}$(_jjhelp_pad "$n" $nw)${off}  ${b}"
      fi
    done
    print
  done

  if (( ${#rows} == 0 && ${#flow_names} == 0 )); then
    print -r -- "${dim}no jj shortcuts match '${filter}'${off}"
    return 1
  fi

  # --- flows --------------------------------------------------------------
  if (( ${#flow_names} )); then
    nw=0 bw=0
    for fname in $flow_names; do
      (( ${#fname} > nw )) && nw=${#fname}
      for line in $_jjhelp_flows; do
        cells=( ${(ps:\t:)line} )
        [[ ${cells[1]} == $fname ]] || continue
        (( ${#cells[2]} > bw )) && bw=${#cells[2]}
      done
    done
    print -r -- "${head}── flows ${off}${dim}${(l:39::─:)}${off}"
    for fname in $flow_names; do
      local shown=''
      for line in $_jjhelp_flows; do
        cells=( ${(ps:\t:)line} )
        [[ ${cells[1]} == $fname ]] || continue
        if [[ -z $shown ]]; then
          print -rn -- "  ${name}$(_jjhelp_pad "$fname" $nw)${off}  "
          shown=1
        else
          print -rn -- "  $(_jjhelp_pad '' $nw)  "
        fi
        if [[ -n ${cells[3]:-} ]]; then
          print -r -- "$(_jjhelp_pad "${cells[2]}" $bw)  ${dim}— ${cells[3]}${off}"
        else
          print -r -- "${cells[2]}"
        fi
      done
      print
    done
    print -r -- "  ${dim}! ${_jjhelp_flows_footnote}${off}"
    print
  fi

  # --- proposed -----------------------------------------------------------
  if (( show_proposed )); then
    local -a proposed_rows
    for line in $_jjhelp_proposed; do
      [[ -n $filter && ${(L)line} != *${(L)filter}* ]] && continue
      proposed_rows+=( "$line" )
    done
    if (( ${#proposed_rows} )); then
      nw=0 bw=0
      for line in $proposed_rows; do
        cells=( ${(ps:\t:)line} )
        (( ${#cells[1]} > nw )) && nw=${#cells[1]}
        (( ${#cells[2]} > bw && ${#cells[2]} <= bodycap + 12 )) && bw=${#cells[2]}
      done
      print -r -- "${head}── optional extras ${off}${dim}${(l:31::─:)} not installed${off}"
      for line in $proposed_rows; do
        cells=( ${(ps:\t:)line} )
        print -r -- "  ${dim}+ $(_jjhelp_pad "${cells[1]}" $nw)  jj $(_jjhelp_pad "${cells[2]}" $bw)  — ${cells[3]}${off}"
      done
      print
    fi
  fi

  # --- footer -------------------------------------------------------------
  # -f showed no aliases, so a shortcut tally would be a lie ("0 shortcuts").
  if (( only_flows )); then
    print -r -- "${dim}flows only · jjhelp for the alias chart · jjhelp -g for git→jj${off}"
    return 0
  fi
  local note="${#rows} of ${total} shortcuts"
  [[ -z $filter ]] && note="${total} shortcuts"
  (( show_proposed )) || note+=" · ${#_jjhelp_proposed} extras, see jjhelp -p"
  print -r -- "${dim}${note}${off}"

  # No shell aliases at all almost always means the oh-my-zsh jj plugin isn't
  # loaded — which costs the chart most of its rows. Say so, rather than just
  # rendering a conspicuously short chart.
  (( shell_alias_rows )) || print -r -- \
    "${dim}no jj* shell aliases found — add \`jj\` to your oh-my-zsh plugins for ~38 more${off}"
}

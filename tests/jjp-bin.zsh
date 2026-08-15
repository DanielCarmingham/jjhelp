#!/usr/bin/env zsh
set -eu

repo=${0:A:h:h}
cd "$repo"

cargo run --quiet --bin jjp-bin -- --list | grep -q 'land-main'
cargo run --quiet --bin jjp-bin -- --preview land-main | grep -q 'jj bookmark advance'
cmd=$(cargo run --quiet --bin jjp-bin -- --print land-main)
[[ $cmd == 'jj sync && jj evolve && jj tug main && jjgp --bookmark main' ]]
cmd=$(cargo run --quiet --bin jjp-bin -- --print push-bookmark bookmark=release)
[[ $cmd == 'jjgp --bookmark release' ]]

tmp=${TMPDIR:-/tmp}/jjp-bin.$$
mkdir -p "$tmp/bin"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/bin/fzf" <<'FZF'
#!/bin/sh
case "$*" in
  *"--prompt action>"*)
    cat >/dev/null
    if [ "${JJP_FAKE_ACTION:-land-main}" = "push-bookmark" ]; then
      printf 'push-bookmark\tpush bookmark\n'
    else
      printf 'land-main\tland current work on main\n'
    fi
    ;;
  *"--prompt bookmark>"*)
    cat >/dev/null
    printf 'release\n'
    ;;
  *)
    cat >/dev/null
    printf 'land-main\tland current work on main\n'
    ;;
esac
FZF
chmod +x "$tmp/bin/fzf"

cat > "$tmp/bin/jj" <<'JJ'
#!/bin/sh
case "$*" in
  "bookmark list")
    printf 'main: qmp 631 install: never clobber a symlink that points at the checkout\n'
    printf 'release: abc 123 release branch\n'
    ;;
esac
JJ
chmod +x "$tmp/bin/jj"

PATH="$tmp/bin:$PATH" cargo run --quiet --bin jjp-bin -- > "$tmp/out"
[[ "$(cat "$tmp/out")" == 'jj sync && jj evolve && jj tug main && jjgp --bookmark main' ]]

JJP_FAKE_ACTION=push-bookmark PATH="$tmp/bin:$PATH" cargo run --quiet --bin jjp-bin -- > "$tmp/out"
[[ "$(cat "$tmp/out")" == 'jjgp --bookmark release' ]]

grep -q 'jjp()' "$repo/jjhelp.zsh"
grep -q 'print -z "$cmd"' "$repo/jjhelp.zsh"
grep -q 'jjp-bin' "$repo/install.sh"
grep -q 'jjp' "$repo/README.md"

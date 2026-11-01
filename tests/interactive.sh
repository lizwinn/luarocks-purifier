#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# The tests of what runs outside the Nix sandbox, which need the network:
#
#   - the lock run of each fixture reproduces its committed lockfile;
#   - `luarocks-purifier luarocks make` installs the app fixture from the
#     locked files, and the command it installs runs;
#   - with a changed rockspec, `luarocks-purifier luarocks` warns that the
#     lockfile is out of date;
#   - the lock run records Mercurial, Subversion and CVS sources, from local
#     repositories;
#   - `luarocks-purifier publish` uploads the source rock Nix packed to a
#     stand-in for the luarocks.org upload API.
#
# Run it from the repository root: tests/interactive.sh
set -euo pipefail

repo=$(pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/luarocks-purifier-test.XXXXXX")
trap 'chmod -R u+w "$work"; rm -rf "$work"' EXIT

tool() {
  nix build --no-link --print-out-paths "nixpkgs#$1" | tail -1
}

nix build --out-link "$work/cli" "$repo#cli"
cli=$work/cli/bin/luarocks-purifier
for t in mercurial subversion cvs python3 gitMinimal lua5_4 lua5_4.pkgs.luarocks binutils; do
  dir=$(tool "$t")
  PATH=$dir/bin:$PATH
done
export PATH
export HOME=$work/home XDG_CONFIG_HOME=$work/home/.config
mkdir -p "$HOME"

step() {
  echo "== $*"
}

# The relock of each fixture reproduces its lockfile byte for byte.
for fixture in app lib; do
  step "relock $fixture"
  cp -r "$repo/tests/fixtures/$fixture" "$work/$fixture"
  # What a local run leaves behind (both are in .gitignore).
  rm -rf "$work/$fixture/lua_modules" "$work/$fixture/.luarocks-purifier"
  (cd "$work/$fixture" && "$cli" relock)
  cmp "$repo/tests/fixtures/$fixture/luarocks-purifier.lock.json" "$work/$fixture/luarocks-purifier.lock.json"
done

step "interactive make"
(
  cd "$work/app"
  "$cli" luarocks make 2>&1 | tee make.log
  grep -q 'luarocks-purifier-cache/server' make.log
  if grep -q 'https://luarocks.org' make.log; then
    echo "the interactive make reached luarocks.org"
    exit 1
  fi
  # The C module records where its C library is, whichever compiler built
  # it, so it loads outside the shell of the lock run.
  readelf -d lua_modules/lib/lua/5.4/zlib.so | grep -E 'R(UN)?PATH' | grep -q luarocks-purifier-external
  output=$(lua_modules/bin/app "the cat and the hat")
  echo "$output" | grep -q 'the = 2'
)

step "a rock missing from the lockfile"
(
  cd "$work/app"
  if "$cli" luarocks install penlight > missing.log 2>&1; then
    echo "an offline install of a rock outside the lockfile succeeded"
    exit 1
  fi
  # shellcheck disable=SC2016 # the backticks are part of the message
  grep -q 'run `luarocks-purifier lock`' missing.log
)

step "an edited hash"
(
  cp -r "$repo/tests/fixtures/app" "$work/tampered"
  rm -rf "$work/tampered/lua_modules" "$work/tampered/.luarocks-purifier"
  cd "$work/tampered"
  python3 - <<'EOF'
import json
lock = json.load(open("luarocks-purifier.lock.json"))
entry = next(d for d in lock["downloads"] if d["path"].startswith("server/"))
entry["hash"] = "sha256-" + "B" * 43 + "="
json.dump(lock, open("luarocks-purifier.lock.json", "w"), indent=2, sort_keys=True)
EOF
  if "$cli" luarocks make > tampered.log 2>&1; then
    echo "the interactive mode accepted an edited hash"
    exit 1
  fi
  grep -q 'hash mismatch' tampered.log
  grep -q 'luarocks-purifier relock' tampered.log
)

step "stale lockfile"
(
  cd "$work/app"
  echo "-- changed" >> app-0.1-1.rockspec
  "$cli" luarocks --version 2>&1 | tee stale.log
  grep -q 'out of date' stale.log
)

step "lock run of Mercurial, Subversion and CVS sources"
vcs=$work/vcs-repos
mkdir -p "$vcs"
# nixpkgs' CVS aborts (SIGABRT) on a tagged export on aarch64-linux, so the
# lock run cannot export a CVS source there (see the README's Limits). The
# vcs flake check covers how a CVS checkout is served on both systems.
rocks="hgrock svnrock cvsrock"
if [ "$(uname -m)" = aarch64 ]; then
  rocks="hgrock svnrock"
  echo "skipping the CVS source: nixpkgs' CVS aborts on aarch64-linux"
fi
(
  # A Mercurial repository with the tag 1.0.
  mkdir "$vcs/hgrock" && cd "$vcs/hgrock"
  hg init -q
  echo 'return "mercurial"' > hgrock.lua
  hg add -q hgrock.lua
  hg commit -q -m init -u test
  hg tag -q -u test 1.0
)
(
  # A Subversion repository at revision 1.
  svnadmin create "$vcs/svnrepo"
  svn checkout -q "file://$vcs/svnrepo" "$vcs/svnwc"
  cd "$vcs/svnwc"
  echo 'return "subversion"' > svnrock.lua
  svn add -q svnrock.lua
  svn commit -q -m init
)
case $rocks in
  *cvsrock*)
    (
      # A CVS module with the tag REL_1_0.
      cvs -d "$vcs/cvsroot" init
      mkdir "$vcs/cvsimport" && cd "$vcs/cvsimport"
      echo 'return "cvs"' > cvsrock.lua
      cvs -Q -d "$vcs/cvsroot" import -m init cvsrock vendor start
      cd "$vcs" && cvs -Q -d "$vcs/cvsroot" rtag REL_1_0 cvsrock
    )
    (
      # The tagged export the lock run makes, run here first so that a
      # failure shows what CVS reports.
      mkdir "$vcs/probe" && cd "$vcs/probe"
      cvs -d "$vcs/cvsroot" export -r REL_1_0 cvsrock
      test -f cvsrock/cvsrock.lua
    )
    ;;
esac
project=$work/vcs-project
mkdir -p "$project/rocks"
dependencies='"lua >= 5.1"'
requires=""
for rock in $rocks; do
  dependencies="$dependencies, \"$rock == 1.0\""
  requires="$requires require(\"$rock\"),"
  case $rock in
    hgrock) source="url = \"hg://file://$vcs/hgrock\", tag = \"1.0\"" ;;
    svnrock) source="url = \"svn://file://$vcs/svnrepo\", tag = \"1\"" ;;
    cvsrock) source="url = \"cvs://$vcs/cvsroot\", module = \"cvsrock\", tag = \"REL_1_0\"" ;;
  esac
  cat > "$project/rocks/$rock-1.0-1.rockspec" <<EOF
package = "$rock"
version = "1.0-1"
source = { $source }
dependencies = { "lua >= 5.1" }
build = { type = "builtin", modules = { $rock = "$rock.lua" } }
EOF
done
cat > "$project/vcs-1.0-1.rockspec" <<EOF
package = "vcs"
version = "1.0-1"
source = { url = "git+https://example.org/vcs.git" }
dependencies = { $dependencies }
build = { type = "builtin", modules = { vcs = "vcs.lua" } }
EOF
echo "return {$requires }" > "$project/vcs.lua"
LUA_INIT=@$repo/nix/lib/tmpname.lua luarocks-admin make_manifest "$project/rocks"
(
  cd "$project"
  "$cli" lock --only-server ./rocks
  # The kinds of checkout the lock must hold: hg, svn, and cvs when the
  # CVS source is part of the test.
  expected=$(for rock in $rocks; do echo "${rock%rock}"; done | sort | tr '\n' ' ')
  EXPECTED=$expected python3 - <<'EOF'
import json, os
expected = set(os.environ["EXPECTED"].split())
lock = json.load(open("luarocks-purifier.lock.json"))
kinds = {k for d in lock["downloads"] for k in ("hg", "svn", "cvs") if k in d}
assert kinds == expected, kinds
for d in lock["downloads"]:
    assert d["hash"].startswith("sha256-"), d
assert {c["kind"] for c in lock["checkouts"]} == expected
print("recorded", sorted(kinds))
EOF
)

step "a Surround SCM source"
(
  sscm=$work/sscm-project
  mkdir -p "$sscm/rocks"
  cat > "$sscm/rocks/sscmrock-1.0-1.rockspec" <<'EOF'
package = "sscmrock"
version = "1.0-1"
source = { url = "sscm://sscm.example.org/repo", branch = "main" }
dependencies = { "lua >= 5.1" }
build = { type = "builtin", modules = { sscmrock = "sscmrock.lua" } }
EOF
  cat > "$sscm/uses-sscm-1.0-1.rockspec" <<'EOF'
package = "uses-sscm"
version = "1.0-1"
source = { url = "git+https://example.org/uses-sscm.git" }
dependencies = { "lua >= 5.1", "sscmrock == 1.0" }
build = { type = "builtin", modules = {} }
EOF
  LUA_INIT=@$repo/nix/lib/tmpname.lua luarocks-admin make_manifest "$sscm/rocks"
  cd "$sscm"
  if "$cli" lock --only-server ./rocks > sscm.log 2>&1; then
    echo "the lock run accepted a Surround SCM source"
    exit 1
  fi
  grep -q 'Surround SCM' sscm.log
)

step "publish"
(
  cd "$work/lib"
  python3 "$repo/tests/fake-luarocks-server.py" "$work/uploads" "$work/port" &
  server=$!
  trap 'kill $server' EXIT
  while [ ! -f "$work/port" ]; do sleep 0.1; done
  "$cli" publish lib-1.0-1.rockspec --server "http://127.0.0.1:$(cat "$work/port")" --api-key test
  cmp "$work/uploads/lib-1.0-1.rockspec" lib-1.0-1.rockspec
  test -s "$work/uploads/lib-1.0-1.src.rock"
  # LuaRocks saved the API key where a plain `luarocks upload` finds it.
  grep -q 'test' "$HOME/.luarocks/upload_config.lua"
)

echo "all interactive tests passed"

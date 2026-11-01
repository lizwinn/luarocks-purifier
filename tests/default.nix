# SPDX-License-Identifier: MIT
#
# The flake's checks: the CLI, and the sandboxed builds of the fixtures
# under tests/fixtures from their committed lockfiles, each with a run of
# what it built.
{
  pkgs,
  overlay,
  cli,
}:
let
  p = pkgs.extend overlay;

  # app: a rock with a command, Lua modules, a C dependency (lpeg), a git
  # dependency that links a C library from nixpkgs (lua-zlib with zlib), a
  # zip archive (argparse), a GitHub archive (inspect) and a test suite
  # with a test dependency (luaunit).
  app =
    (p.buildLuarocksProject {
      src = ./fixtures/app;
      doCheck = true;
    }).packages.app;
  # lib: a LuaJIT project with two rockspecs, where lib-demo depends on
  # lib, a local rocks server (rocks/) with a git source of rockspec format
  # 3.0 (so with submodules), and the two kinds of own source a source rock
  # holds: a release archive that does not exist yet (lib), which the
  # project source stands in for, and an archive pinned by md5 (lib-demo),
  # which the lock holds.
  lib = p.buildLuarocksProject { src = ./fixtures/lib; };

  # vcs: dependencies from Mercurial, Subversion and CVS. Its lockfile is
  # written by hand, and the checkouts come from tests/vcs-checkouts in
  # place of the fetchers, so the check covers how LuaRocks gets each kind
  # of checkout offline. tests/interactive.sh covers how the lock run
  # records them, against local repositories.
  vcs =
    (p.buildLuarocksProject {
      src = ./fixtures/vcs;
      fetchhg = _: ./vcs-checkouts/hgrock;
      fetchsvn = _: ./vcs-checkouts/svnrock;
      fetchcvs = _: ./vcs-checkouts/cvsrock;
    }).packages.vcs;
in
{
  inherit cli;

  lib = lib.packages.lib;
  lib-demo = lib.packages.lib-demo;

  lib-runs = p.runCommand "lib-runs" { } ''
    output=$(${lib.packages.lib-demo.bin.lib-demo})
    echo "$output"
    echo "$output" | grep -q 'LuaJIT'
    test -f ${lib.packages.lib.modules.lib}
    touch $out
  '';

  # `luarocks upload`, as `luarocks-purifier publish` runs it, sends the
  # rockspec and the source rock Nix packed, byte for byte, to a stand-in
  # for the luarocks.org upload API.
  app-publish =
    p.runCommand "app-publish"
      {
        nativeBuildInputs = [
          p.python3
          p.curl
          app.luarocks
        ];
      }
      ''
        export HOME=$TMPDIR/home LUA_INIT=@${../nix/lib/tmpname.lua} LUAROCKS_CONFIG=${../nix/lib/publish-config.lua}
        mkdir -p $HOME
        python3 ${./fake-luarocks-server.py} $TMPDIR/uploads $TMPDIR/port &
        while [ ! -f $TMPDIR/port ]; do sleep 0.1; done
        cp -r ${./fixtures/app} src
        cd src
        luarocks upload app-0.1-1.rockspec ${app.rock}/app-0.1-1.src.rock \
          --server "http://127.0.0.1:$(cat $TMPDIR/port)" --api-key test
        cmp $TMPDIR/uploads/app-0.1-1.rockspec app-0.1-1.rockspec
        cmp $TMPDIR/uploads/app-0.1-1.src.rock ${app.rock}/app-0.1-1.src.rock
        touch $out
      '';

  vcs-runs = p.runCommand "vcs-runs" { } ''
    LUA_PATH='${vcs}/share/lua/5.4/?.lua' ${vcs.lua}/bin/lua -e '
      local s = require("vcs").sources
      assert(s[1] == "mercurial" and s[2] == "subversion" and s[3] == "cvs")
    '
    touch $out
  '';

  lib-rocks = p.runCommand "lib-rocks" { nativeBuildInputs = [ p.unzip ]; } ''
    unzip -l ${lib.packages.lib.rock}/lib-1.0-1.src.rock | tee lib
    grep -q 'lib-1.0.tar.gz' lib
    unzip -p ${lib.packages.lib.rock}/lib-1.0-1.src.rock lib-1.0.tar.gz | tar -tzf - | grep -q 'lib-1.0/src/lib.lua'
    unzip -l ${lib.packages.lib-demo.rock}/lib-demo-1.0-1.src.rock | tee demo
    grep -q '0.7.1.zip' demo
    touch $out
  '';

  app = app;

  # The command the rock installs runs, with its modules and the C modules
  # of its dependencies, and the outputs the lockfile names are where the
  # attributes say.
  app-runs = p.runCommand "app-runs" { } ''
    output=$(${app.bin.app} "the cat and The hat")
    echo "$output"
    echo "$output" | grep -q 'the = 2'
    test -f ${app.modules.app}
    test -f ${app.modules."app.words"}
    touch $out
  '';

  # The source rock holds the rockspec and the project source, which stands
  # in for the git tag the rockspec names.
  app-rock = p.runCommand "app-rock" { nativeBuildInputs = [ p.unzip ]; } ''
    unzip -l ${app.rock}/app-0.1-1.src.rock | tee listing
    grep -q 'app-0.1-1.rockspec' listing
    grep -q 'src/app/words.lua' listing
    touch $out
  '';
}

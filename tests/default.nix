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
  app = (p.buildLuarocksProject {
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

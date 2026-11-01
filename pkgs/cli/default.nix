# SPDX-License-Identifier: MIT
#
# The luarocks-purifier command: bin/luarocks-purifier on Python's standard
# library, with the Nix library it realizes lockfiles with, the nixpkgs
# `luarocks-purifier luarocks` and `publish` build with, and LuaRocks for
# every Lua a lockfile can name. The lock run needs the tools LuaRocks
# fetches and builds with: curl, git, Mercurial, Subversion and CVS for
# the sources, the nix-prefetch scripts to hash checkouts, archivers, and
# a C compiler, make and CMake for the rocks that build C code.
{
  lib,
  pkgs,
  stdenvNoCC,
  makeWrapper,
  python3Minimal,
  curl,
  gitMinimal,
  mercurial,
  subversion,
  cvs,
  nix-prefetch-scripts,
  unzip,
  zip,
  gnutar,
  gzip,
  bzip2,
  xz,
  gcc,
  gnumake,
  cmake,
  path,
  shims,
  version,
  # The shared nix-purifiers library, as a flake reference to its locked
  # source, which the default package overlay gives.
  purifierFlake ? throw "luarocks-purifier: the CLI needs purifierFlake, which the default package overlay of this flake sets",
}:
let
  # The repository files the CLI reads at run time: the Nix library (with
  # what source-rock.nix builds the stand-ins from) and this script.
  source = lib.fileset.toSource {
    root = ../..;
    fileset = lib.fileset.unions [
      ../../bin
      ../../nix
      ../../pkgs/shims
      ../../version.txt
    ];
  };
  luarocks = lib.mapAttrs (_: lua: {
    luarocks = "${lua.pkgs.luarocks}";
    lua = lib.getExe lua;
    version = lua.pkgs.luarocks.version;
  }) (import ../../nix/lib/lua.nix { inherit pkgs; });
in
stdenvNoCC.mkDerivation {
  pname = "luarocks-purifier";
  inherit version;
  src = source;
  nativeBuildInputs = [ makeWrapper ];
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    # The user's PATH comes first, for the user's nix and compilers.
    makeWrapper ${python3Minimal}/bin/python3 "$out/bin/luarocks-purifier" \
      --add-flags "${source}/bin/luarocks-purifier" \
      --set LUAROCKS_PURIFIER_LIB ${source}/nix/lib \
      --set LUAROCKS_PURIFIER_NIXPKGS ${path} \
      --set LUAROCKS_PURIFIER_SHIMS ${shims}/bin \
      --set LUAROCKS_PURIFIER_LIBRARY ${lib.escapeShellArg purifierFlake} \
      --set LUAROCKS_PURIFIER_LUAROCKS ${lib.escapeShellArg (builtins.toJSON luarocks)} \
      --suffix PATH : ${
        lib.makeBinPath [
          curl
          gitMinimal
          mercurial
          subversion
          cvs
          nix-prefetch-scripts
          unzip
          zip
          gnutar
          gzip
          bzip2
          xz
          gcc
          gnumake
          cmake
        ]
      }
    runHook postInstall
  '';
  meta = {
    description = "Locks the files a LuaRocks project downloads, so that Nix can build it offline";
    license = lib.licenses.mit;
    mainProgram = "luarocks-purifier";
  };
}

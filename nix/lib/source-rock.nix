# SPDX-License-Identifier: MIT
#
# What `luarocks-purifier publish ROCKSPEC` builds: the source rock of one
# rockspec of the project at `src`, packed by the sandboxed build.
{
  src,
  rockspec,
  # The nixpkgs the CLI was built with.
  nixpkgs,
}:
let
  pkgs = import nixpkgs { };
  buildLuarocksProject = pkgs.callPackage ./build-luarocks-project.nix {
    luarocks-purifier-shims = pkgs.callPackage ../../pkgs/shims { };
  };
in
(buildLuarocksProject { inherit src; }).rockspecs.${rockspec}.rock

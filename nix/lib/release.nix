# SPDX-License-Identifier: MIT
#
# What `luarocks-purifier publish` builds: the `release` of the project at
# `src`, the source rocks that the sandboxed build packs.
{
  src,
  lockFile,
  # The nixpkgs the CLI was built with.
  nixpkgs,
  # The shared nix-purifiers library the CLI was built with, as a flake
  # reference to its locked source.
  purifierFlake,
}:
let
  pkgs = import nixpkgs { };
  buildLuarocksProject = pkgs.callPackage ./build-luarocks-project.nix {
    luarocks-purifier.shims = pkgs.callPackage ../../pkgs/shims { };
    inherit ((builtins.getFlake purifierFlake).lib) purifier;
  };
in
(buildLuarocksProject { inherit src lockFile; }).release

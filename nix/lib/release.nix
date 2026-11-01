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
  buildLuarocksProject = import ./build-luarocks-project.nix {
    inherit ((builtins.getFlake purifierFlake).lib) purifier;
  };
in
(buildLuarocksProject {
  pkgs = import nixpkgs { };
  inherit src lockFile;
}).release

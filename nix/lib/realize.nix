# SPDX-License-Identifier: MIT
#
# What `luarocks-purifier luarocks` builds for the interactive mode: the
# offline cache of the lockfile, the same derivation the sandboxed build
# uses. The CLI builds it with an out-link, which is the GC root that keeps
# every locked file alive.
{
  lockFile,
  # The nixpkgs the CLI was built with.
  nixpkgs,
  # The shared nix-purifiers library the CLI was built with, as a flake
  # reference to its locked source.
  purifierFlake,
}:
let
  pkgs = import nixpkgs { };
in
pkgs.callPackage ./cache.nix {
  inherit lockFile;
  inherit ((builtins.getFlake purifierFlake).lib) purifier;
}

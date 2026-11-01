# SPDX-License-Identifier: MIT
#
# The default package overlay. It adds the packages of pkgs/ under
# `pkgs.luarocks-purifier` (`.cli`, `.shims`). A consumer that lists this
# flake in `projects` holds it as `luarocks-purifier/default`, which its
# package sets apply by default.
#
# The CLI loads the shared nix-purifiers library
# (github:nix-purifiers/purifier) in its own Nix builds, from the locked
# source of this flake's `purifier` input.
{ closure-inputs, closure-lib, ... }:
let
  packages = closure-lib.caisson.nixpkgs.mkPackagesOverlay ../../pkgs "luarocks-purifier";
  purifierInput = closure-inputs.purifier;
  purifierFlake = "path:${purifierInput.outPath}?narHash=${purifierInput.narHash}";
in
{
  overlay =
    final: prev:
    let
      base = packages final prev;
    in
    base
    // {
      luarocks-purifier = base.luarocks-purifier // {
        cli = base.luarocks-purifier.cli.override { inherit purifierFlake; };
      };
    };
}

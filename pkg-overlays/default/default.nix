# SPDX-License-Identifier: MIT
#
# The default package overlay. It adds the packages of pkgs/ under
# `pkgs.luarocks-purifier` (`.cli`, `.shims`), and the builder
# `pkgs.buildLuarocksProject` (nix/lib/build-luarocks-project.nix) beside
# them, where nixpkgs keeps its own builders, so a package written for
# callPackage takes it by name. A consumer that lists this flake in
# `projects` holds it as `luarocks-purifier/default`, which its package
# sets apply by default.
#
# The builder fetches with the shared nix-purifiers library
# (github:nix-purifiers/purifier). The CLI loads the same library in its
# own Nix builds, from the locked source of this flake's `purifier` input.
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
      buildLuarocksProject = final.callPackage ../../nix/lib/build-luarocks-project.nix {
        inherit (closure-lib) purifier;
      };
    };
}

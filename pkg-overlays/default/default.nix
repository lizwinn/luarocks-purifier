# SPDX-License-Identifier: MIT
#
# The default package overlay. It adds the packages of pkgs/ under
# `pkgs.luarocks-purifier` (`.cli`, `.shims`), and the builder
# `pkgs.buildLuarocksProject` (nix/lib/build-luarocks-project.nix) beside
# them, where nixpkgs keeps its own builders, so a package written for
# callPackage takes it by name. A consumer that lists this flake in
# `projects` holds it as `luarocks-purifier/default`, which its package
# sets apply by default.
{ closure-lib, ... }:
let
  packages = closure-lib.caisson.nixpkgs.mkPackagesOverlay ../../pkgs "luarocks-purifier";
in
{
  overlay =
    final: prev:
    packages final prev
    // {
      buildLuarocksProject = final.callPackage ../../nix/lib/build-luarocks-project.nix {
        luarocks-purifier-shims = final.luarocks-purifier.shims;
      };
    };
}

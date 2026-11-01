# SPDX-License-Identifier: MIT
{ ... }:
{
  config,
  inputs,
  lib,
  ...
}:
{

  imports = [ inputs.flake-parts.flakeModules.partitions ];

  debug = false;
  caisson = {
    libOverlays.exported = libOverlays: {
      inherit (libOverlays) default;
    };

    # The scope `luarocks-purifier` is the `default` entry of this flake's
    # package overlay registry (pkg-overlays/): the package set applies it by
    # default, and the flake exports it as `pkgOverlays` and as the plain
    # `overlays.default`. The scope holds the builder, which is a function
    # and not a package, so the flake exports the derivations of the scope
    # itself (see `packages` below).
    nixpkgs = {
      packages.export.enabled = false;
    };
  };

  # The packages of the flake are the derivations of the scope, and
  # `nix run github:nix-purifiers/luarocks-purifier -- lock` runs the command
  # `cli` to lock the project in the current directory.
  perSystem =
    { pkgs, ... }:
    {
      packages = lib.filterAttrs (_: lib.isDerivation) pkgs.luarocks-purifier // {
        default = pkgs.luarocks-purifier.cli;
      };
    };

  partitionedAttrs.checks = "checks";
  partitionedAttrs.formatter = "formatter";

  partitions.formatter = {
    extraInputs = (lib.caisson.pins.flake-compat ../../../tests/dependencies).sources;
    module =
      { inputs, ... }:
      {
        imports = [ inputs.treefmt-nix.flakeModule ];
        perSystem.treefmt.programs.nixfmt.enable = true;
      };
  };

  partitions.checks = {
    extraInputs = (lib.caisson.pins.flake-compat ../../../tests/dependencies).sources;
    module =
      { inputs, self, ... }:
      {
        imports = [ inputs.treefmt-nix.flakeModule ];
        perSystem =
          { pkgs, system, ... }:
          {
            checks = import ../../../tests {
              inherit pkgs;
              overlay = self.overlays.default;
              inherit (self.lib.luarocks-purifier) readLock;
              inherit (self.packages.${system}) cli;
              luacheck = inputs.luacheck;
            };
            treefmt.programs.nixfmt.enable = true;
          };
      };
  };

}

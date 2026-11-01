# SPDX-License-Identifier: MIT
{ closure-lib, ... }:
{
  config,
  inputs,
  lib,
  ...
}:
{

  imports = [
    inputs.flake-parts.flakeModules.partitions
    closure-lib.caisson.modules.flake."purifier/purifier-packages"
  ];

  # The flake's packages are the derivations of the scope
  # `luarocks-purifier` (see the module purifier-packages of the shared
  # library).
  purifier.scope = "luarocks-purifier";

  debug = false;
  caisson = {
    libOverlays.exported = libOverlays: {
      inherit (libOverlays) default;
    };

    # The scope `luarocks-purifier` is the `default` entry of this flake's
    # package overlay registry (pkg-overlays/): the package set applies it by
    # default, and the flake exports it as `pkgOverlays` and as the plain
    # `overlays.default`.
  };

  # `nix run github:nix-purifiers/luarocks-purifier -- lock` runs the command
  # `cli` to lock the project in the current directory.
  perSystem =
    { pkgs, ... }:
    {
      packages.default = pkgs.luarocks-purifier.cli;
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

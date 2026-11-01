# SPDX-License-Identifier: MIT
#
# The `luarocks-purifier` library namespace, which holds the builder
# `buildLuarocksProject` (nix/lib/build-luarocks-project.nix). The builder
# fetches with `lib.purifier`, the shared nix-purifiers library
# (github:nix-purifiers/purifier), which this flake lists in `projects`.
{ ... }:
{

  overlay = final: prev: {
    luarocks-purifier = (prev.luarocks-purifier or { }) // {
      buildLuarocksProject = import ../../nix/lib/build-luarocks-project.nix {
        inherit (final) purifier;
      };
    };
  };

}

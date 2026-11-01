# SPDX-License-Identifier: MIT
#
# The `luarocks-purifier` library namespace, which holds the builder
# `buildLuarocksProject` (nix/lib/build-luarocks-project.nix) and
# `readLock`, the lock in memory (nix/lib/read-lock.nix). The builder
# checks the lock and fetches with `lib.purifier`, the shared nix-purifiers
# library (github:nix-purifiers/purifier), which this flake lists in
# `projects`.
{ ... }:
{

  overlay = final: prev: {
    luarocks-purifier = (prev.luarocks-purifier or { }) // {
      buildLuarocksProject = import ../../nix/lib/build-luarocks-project.nix {
        inherit (final) purifier;
      };
      readLock = import ../../nix/lib/read-lock.nix;
    };
  };

}

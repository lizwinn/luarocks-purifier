# SPDX-License-Identifier: MIT
#
# The `luarocks-purifier` library namespace, which holds `readLock`, the
# lock in memory (nix/lib/read-lock.nix). The builder
# `buildLuarocksProject` needs a package set, so the default package
# overlay adds it as a package.
{ ... }:
{

  overlay = final: prev: {
    luarocks-purifier = (prev.luarocks-purifier or { }) // {
      readLock = import ../../nix/lib/read-lock.nix;
    };
  };

}

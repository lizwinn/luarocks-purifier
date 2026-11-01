# SPDX-License-Identifier: MIT
#
# The `luarocks-purifier` library namespace. It holds nothing: the builder
# needs a package set, so it is the package `buildLuarocksProject` that the
# default package overlay adds.
{ ... }:
{

  overlay = final: prev: {
    luarocks-purifier = prev.luarocks-purifier or { };
  };

}

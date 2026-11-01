# SPDX-License-Identifier: MIT
{ callPackage, ... }:
let
  version = builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile ../version.txt);
in
rec {
  # The tool stand-ins LuaRocks runs in the lock run and offline.
  shims = callPackage ./shims { };
  # The luarocks-purifier command.
  cli = callPackage ./cli { inherit version shims; };
}

# SPDX-License-Identifier: MIT
{
  inputs.caisson.url = "github:nix-caisson/caisson";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  inputs.flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  # Same channel as the main flake, so dev-partition evals agree with the
  # exported pkgSet.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.treefmt-nix.url = "github:numtide/treefmt-nix";
  inputs.treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  # luacheck v1.2.0, the real-world project the check real-luacheck builds
  # from the lockfile in tests/real/luacheck.
  inputs.luacheck.url = "github:lunarmodules/luacheck/cc089e3f65acdd1ef8716cc73a3eca24a6b845e4";
  inputs.luacheck.flake = false;
  outputs = { ... }: { };
}

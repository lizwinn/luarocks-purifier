# SPDX-License-Identifier: MIT
#
# The fetcher for locked downloads. The lock holds the download kinds of
# the shared nix-purifiers library:
#
#   { path, url, mirrors, hash }
#     a file, where hash is the SRI hash of the file, fetched from url or
#     from one of the mirrors, which serve the same bytes
#   { path, git = { url, rev, submodules, leaveDotGit }, hash }
#     a git checkout, where hash is the SRI hash that nix-prefetch-git
#     reports for it
#   { path, hg = { url, rev }, hash }
#   { path, svn = { url, rev }, hash }
#     a Mercurial or Subversion checkout, fetched with nixpkgs' fetchhg or
#     fetchsvn
#   { path, cvs = { root, module, tag }, hash }
#     a CVS export, fetched with nixpkgs' fetchcvs
#
# By default a file is a fixed-output derivation on Nix's built-in fetcher
# (the same derivation <nix/fetchurl.nix> makes). A fixed-output store
# path depends only on its name and hash, so the default fetcher and
# nixpkgs' fetchurl produce the same paths.
#
# `fetchurl`, when given, replaces the built-in fetcher for files. It is
# called with { name, urls, hash } and is the place for credentials
# (nixpkgs' fetchurl takes `netrcPhase`). The checkout fetchers can be
# replaced the same way, for instance with a fetchgit that has access to a
# private repository.
{
  lock,
  fetchgit,
  fetchhg,
  fetchsvn,
  fetchcvs,
  fetchurl ? null,
}:
download:
let
  name = lock.downloadName download;
in
if download ? git then
  fetchgit {
    inherit name;
    inherit (download.git) url rev leaveDotGit;
    fetchSubmodules = download.git.submodules;
    inherit (download) hash;
  }
else if download ? hg then
  fetchhg {
    inherit name;
    inherit (download.hg) url rev;
    inherit (download) hash;
  }
else if download ? svn then
  fetchsvn {
    inherit name;
    inherit (download.svn) url rev;
    inherit (download) hash;
  }
else if download ? cvs then
  fetchcvs {
    cvsRoot = download.cvs.root;
    inherit (download.cvs) module tag;
    inherit (download) hash;
  }
else if fetchurl != null then
  fetchurl {
    inherit name;
    urls = [ download.url ] ++ download.mirrors;
    inherit (download) hash;
  }
else
  derivation {
    inherit name;
    builder = "builtin:fetchurl";
    system = "builtin";
    inherit (download) url;
    urls = [ download.url ] ++ download.mirrors;
    outputHash = download.hash;
    outputHashAlgo = "sha256";
    outputHashMode = "flat";
    unpack = false;
    executable = false;
    preferLocalBuild = true;
    impureEnvVars = [
      "http_proxy"
      "https_proxy"
      "ftp_proxy"
      "all_proxy"
      "no_proxy"
    ];
  }

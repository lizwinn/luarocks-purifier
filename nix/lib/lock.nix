# SPDX-License-Identifier: MIT
#
# Reads a luarocks-purifier lockfile (written by `luarocks-purifier lock`).
# Given the project source, it also checks that the lockfile was made from
# the rockspecs and luarocks.lock the source holds.
{
  lockFile,
  src ? null,
}:
let
  text = builtins.readFile lockFile;
  parsed = builtins.fromJSON text;

  supportedVersion = import ./lock-version.nix;

  relock = "Run `luarocks-purifier relock` in the project root.";
  fail = message: throw "luarocks-purifier: ${toString lockFile} ${message} ${relock}";

  # The fields every lockfile has, which the builder reads.
  fields = [
    "version"
    "lua"
    "servers"
    "externalDeps"
    "definitionHash"
    "rockspecs"
    "downloads"
    "checkouts"
  ];
  missing = builtins.filter (f: !(parsed ? ${f})) fields;

  lock =
    if !builtins.isAttrs parsed then
      fail "is not a luarocks-purifier lockfile."
    else if missing != [ ] then
      fail "is not a valid lockfile: it has no ${builtins.concatStringsSep ", " missing}."
    else if parsed.version != supportedVersion then
      throw "luarocks-purifier: ${toString lockFile} has lock format version ${toString parsed.version}; this library reads version ${toString supportedVersion}. Run `luarocks-purifier relock` with the luarocks-purifier version that provides this library."
    else
      parsed;

  # The definition hash of the source, as `luarocks-purifier lock` computes
  # it (see definition_hash in bin/luarocks-purifier).
  definitionHash =
    let
      files = builtins.sort builtins.lessThan (
        map (r: r.file) lock.rockspecs
        ++ (if builtins.pathExists (src + "/luarocks.lock") then [ "luarocks.lock" ] else [ ])
      );
      lines = builtins.concatStringsSep "" (
        map (f: "${f} ${builtins.hashFile "sha256" (src + "/${f}")}\n") files
      );
    in
    builtins.convertHash {
      hash = builtins.hashString "sha256" lines;
      hashAlgo = "sha256";
      toHashFormat = "sri";
    };

  current =
    src == null
    || !(builtins.all (r: builtins.pathExists (src + "/${r.file}")) lock.rockspecs)
    || definitionHash == lock.definitionHash;

  # A store path name from a file name. Store path names allow
  # [A-Za-z0-9+._?=-], must not start with a dot, and are at most 211
  # characters; every other character becomes "_".
  storeName =
    fileName:
    let
      # builtins.split alternates the text between matches with a list per
      # match.
      replaced = builtins.concatStringsSep "" (
        map (part: if builtins.isList part then "_" else part) (
          builtins.split "[^A-Za-z0-9+._?=-]" fileName
        )
      );
      undotted = builtins.head (builtins.match "\\.*(.*)" replaced);
      nonEmpty = if undotted == "" then "file" else undotted;
    in
    builtins.substring 0 200 nonEmpty;

  isFile = d: d ? url;
in
assert
  builtins.all (r: builtins.pathExists (src + "/${r.file}")) (if src == null then [ ] else lock.rockspecs)
  || fail "names a rockspec that the project source does not have.";
assert
  current
  || fail "is out of date: a rockspec or luarocks.lock changed since the lock run.";
lock
// {
  inherit storeName;

  # The fetch name of a download: the last part of its path, made a valid
  # store name.
  downloadName = download: storeName (baseNameOf download.path);

  # The files of the rocks servers (rockspecs and rocks), which make up the
  # offline rocks server.
  serverFiles = builtins.filter (
    d: isFile d && builtins.substring 0 7 d.path == "server/"
  ) lock.downloads;

  # Every other file, such as the source archives that rockspecs name.
  otherFiles = builtins.filter (
    d: isFile d && builtins.substring 0 7 d.path != "server/"
  ) lock.downloads;

  downloadsByPath = builtins.listToAttrs (
    map (d: {
      name = d.path;
      value = d;
    }) lock.downloads
  );

  # The Lua whose ABI the rocks are built for, as LuaRocks names it in tree
  # paths such as share/lua/5.1.
  luaAbi = if lock.lua == "luajit" then "5.1" else lock.lua;
}

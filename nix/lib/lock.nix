# SPDX-License-Identifier: MIT
#
# Reads a luarocks-purifier lockfile (written by `luarocks-purifier lock`).
# It throws the message of lock-problem.nix for a lockfile that is not
# valid, was changed by hand, or, given the project source, is out of date.
{
  lockFile,
  src ? null,
  luarocksLock ? null,
}:
let
  parsed = builtins.fromJSON (builtins.readFile lockFile);
  problem = import ./lock-problem.nix {
    inherit parsed src luarocksLock;
    name = toString lockFile;
  };
  lock = if problem != null then throw problem else parsed;

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

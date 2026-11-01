# SPDX-License-Identifier: MIT
#
# buildLuarocksProject: builds the rocks of a LuaRocks project offline in
# the Nix sandbox, from its luarocks-purifier lockfile.
#
#   (buildLuarocksProject { src = ./.; }).packages.<package>
#
# is the rock that a rockspec of the project defines, installed with its
# dependencies into a LuaRocks tree (bin/, share/lua/, lib/lua/ and
# lib/luarocks/). The lockfile names every output of each rock, so each is
# an attribute, known without building:
#
#   .bin.<command>     the path of a command the rock installs
#   .modules.<module>  the path of a Lua or C module, such as "foo.bar"
#   .rock              the source rock that `luarocks upload` publishes,
#                      packed in the sandbox: a directory holding
#                      <package>-<version>.src.rock
#
# `rockspecs.<file>` holds the same packages by rockspec file name, and
# `cache` is the offline cache of the lockfile (see cache.nix).
#
# Arguments:
#
#   src           the project root
#   lockFile      the lockfile; the default is src's luarocks-purifier.lock.json
#   externalDeps  the C libraries the rocks need, as a list of packages; the
#                 default is the nixpkgs attributes the lockfile names
#   doCheck       run `luarocks test` for each rock (default false)
#   fetchurl      a fetcher for the locked files, called with
#                 { name, urls, hash }, for credentials or other mirrors
#   fetchgit, fetchhg, fetchsvn, fetchcvs
#                 the fetchers for locked checkouts
{
  lib,
  pkgs,
  stdenv,
  callPackage,
  luarocks-purifier-shims,
  unzip,
  zip,
  gnutar,
  gzip,
  bzip2,
  xz,
  cmake,
  gnumake,
  fetchgit,
  fetchhg,
  fetchsvn,
  fetchcvs,
}:
let
  defaultFetchgit = fetchgit;
  defaultFetchhg = fetchhg;
  defaultFetchsvn = fetchsvn;
  defaultFetchcvs = fetchcvs;
in
{
  src,
  lockFile ? src + "/luarocks-purifier.lock.json",
  externalDeps ? null,
  doCheck ? false,
  fetchurl ? null,
  fetchgit ? defaultFetchgit,
  fetchhg ? defaultFetchhg,
  fetchsvn ? defaultFetchsvn,
  fetchcvs ? defaultFetchcvs,
}:
let
  cache = callPackage ./cache.nix {
    inherit
      lockFile
      externalDeps
      fetchurl
      fetchgit
      fetchhg
      fetchsvn
      fetchcvs
      ;
  };
  inherit (cache) lock luarocks externals;
  lua = (import ./lua.nix { inherit pkgs; }).${lock.lua};
  abi = lock.luaAbi;

  # The project source, without the files of a local run.
  source = lib.cleanSourceWith {
    name = "source";
    src = lib.cleanSource src;
    filter =
      path: _type:
      !(builtins.elem (baseNameOf path) [
        ".luarocks-purifier"
        "lua_modules"
      ]);
  };

  luaString = s: builtins.toJSON s;

  # The LuaRocks configuration of a sandboxed run, with the tree and the
  # rocks servers given as shell words.
  writeConfig = ''
    writeConfig() {
      cat > "$1" <<EOF
    fs_use_modules = false
    check_certificates = true
    local_cache = "$TMPDIR/luarocks-local-cache"
    rocks_trees = { $2 }
    rocks_servers = { "${cache}/server" }
    external_deps_dirs = { ${lib.concatMapStringsSep ", " (d: luaString "${d}") externals} }
    variables = {
      WGET = "/nonexistent/wget",
      CURL = "${luarocks-purifier-shims}/bin/luarocks-purifier-curl",
      GIT = "${luarocks-purifier-shims}/bin/luarocks-purifier-git",
      HG = "${luarocks-purifier-shims}/bin/luarocks-purifier-hg",
      SVN = "${luarocks-purifier-shims}/bin/luarocks-purifier-svn",
      CVS = "${luarocks-purifier-shims}/bin/luarocks-purifier-cvs",
    }
    EOF
    }
    export HOME=$TMPDIR/home
    mkdir -p "$HOME"
    export LUA_INIT=@${./tmpname.lua}
    export LUAROCKS_PURIFIER_MODE=serve
    export LUAROCKS_PURIFIER_CACHE=${cache}
  '';

  nativeTools = [
    luarocks
    lua
    luarocks-purifier-shims
    unzip
    zip
    gnutar
    gzip
    bzip2
    xz
    cmake
    gnumake
  ];

  # How LuaRocks requests the rockspec's own source, which the source rock
  # holds: the tool it runs and the URL it passes (LuaRocks drops a "git+"
  # or "hg+" prefix and an "hg://" or "svn://" scheme), or a download.
  selfRequest =
    info:
    let
      s = info.source;
      url = s.url or "";
      has = lib.hasPrefix;
      basename = baseNameOf url;
    in
    if has "git+file://" url then
      {
        kind = "git";
        url = lib.removePrefix "git+file://" url;
      }
    else if has "git+" url then
      {
        kind = "git";
        url = lib.removePrefix "git+" url;
      }
    else if has "git://" url then
      {
        kind = "git";
        inherit url;
      }
    else if has "hg+" url then
      {
        kind = "hg";
        url = lib.removePrefix "hg+" url;
      }
    else if has "hg://" url then
      {
        kind = "hg";
        url = lib.removePrefix "hg://" url;
      }
    else if has "svn://" url then
      {
        kind = "svn";
        url = lib.removePrefix "svn://" url;
      }
    else if has "cvs://" url then
      {
        kind = "cvs";
        url = "${s.pathname or ""} ${s.module or (baseNameOf url)}";
      }
    else if builtins.match "(https?|ftp)://.*" url != null then
      {
        kind = "file";
        inherit url basename;
        # The directory LuaRocks unpacks the archive into: source.dir, or
        # the archive name without its extensions, as LuaRocks deduces it.
        dir =
          s.dir or (builtins.head (
            builtins.match "(.*)\\.(tar\\.gz|tgz|tar\\.bz2|tbz2|tar\\.xz|txz|tar|zip|gz|bz2)" basename
            ++ [ basename ]
          ));
        archive = info.sourceArchive or null;
        md5 = s.md5 or null;
      }
    else
      null;

  # The shell that stands the project source in for the rockspec's own
  # source, through LUAROCKS_PURIFIER_SELF.
  selfSetup =
    info:
    let
      r = selfRequest info;
      ref = info.source.ref or null;
      entry = path: builtins.toJSON {
        inherit (r) kind url;
        inherit ref path;
      };
    in
    if r == null then
      ""
    else if r.kind != "file" then
      ''
        export LUAROCKS_PURIFIER_SELF=${lib.escapeShellArg "[${entry "SELF"}]"}
        export LUAROCKS_PURIFIER_SELF=''${LUAROCKS_PURIFIER_SELF/SELF/$PWD}
      ''
    else if r.archive != null then
      ''
        export LUAROCKS_PURIFIER_SELF=${
          lib.escapeShellArg (builtins.toJSON [
            {
              kind = "file";
              inherit (r) url;
              path = "${cache.fetched.${r.archive.path}}";
            }
          ])
        }
      ''
    else if r.md5 != null then
      throw "luarocks-purifier: ${info.file} pins its source archive ${r.url} by md5, and the lock run could not download it. Publish the archive (by tagging the release), then run `luarocks-purifier relock` so that the lockfile holds it."
    else
      ''
        mkdir -p "$TMPDIR/self-archive/${r.dir}"
        cp -r . "$TMPDIR/self-archive/${r.dir}/"
        archive="$TMPDIR/${r.basename}"
        case ${lib.escapeShellArg r.basename} in
          *.zip) (cd "$TMPDIR/self-archive" && zip -qr -X "$archive" ${lib.escapeShellArg r.dir}) ;;
          *.tar.bz2|*.tbz2) tar -cjf "$archive" -C "$TMPDIR/self-archive" ${lib.escapeShellArg r.dir} ;;
          *.tar.xz|*.txz) tar -cJf "$archive" -C "$TMPDIR/self-archive" ${lib.escapeShellArg r.dir} ;;
          *) tar -czf "$archive" -C "$TMPDIR/self-archive" ${lib.escapeShellArg r.dir} ;;
        esac
        export LUAROCKS_PURIFIER_SELF="[{\"kind\": \"file\", \"url\": ${
          lib.escapeShellArg (builtins.toJSON r.url)
        }, \"path\": \"$archive\"}]"
      '';

  # The attribute name of a module file: "foo/bar.lua" and "foo/bar/init.lua"
  # are "foo.bar", and the C module "foo/bar.so" is "foo.bar".
  moduleName =
    file:
    let
      noExt = builtins.head (builtins.match "(.*)\\.[^./]+" file ++ [ file ]);
      noInit = lib.removeSuffix "/init" noExt;
    in
    builtins.replaceStrings [ "/" ] [ "." ] noInit;

  rockFor =
    info:
    stdenv.mkDerivation {
      pname = "${info.package}-src-rock";
      inherit (info) version;
      src = source;
      nativeBuildInputs = nativeTools;
      dontUseCmakeConfigure = true;
      dontConfigure = true;
      buildPhase = ''
        runHook preBuild
        ${writeConfig}
        writeConfig "$TMPDIR/config.lua" '{ name = "none", root = "'"$TMPDIR"'/tree" }'
        export LUAROCKS_CONFIG=$TMPDIR/config.lua
        ${selfSetup info}
        luarocks pack ${lib.escapeShellArg info.file}
        runHook postBuild
      '';
      installPhase = ''
        runHook preInstall
        install -Dm644 ${lib.escapeShellArg "${info.package}-${info.version}.src.rock"} -t $out
        runHook postInstall
      '';
    };

  packageFor =
    info:
    let
      package = stdenv.mkDerivation (finalAttrs: {
        pname = info.package;
        inherit (info) version;
        src = source;
        nativeBuildInputs = nativeTools;
        buildInputs = externals;
        dontUseCmakeConfigure = true;
        dontConfigure = true;
        inherit doCheck;
        buildPhase = ''
          runHook preBuild
          ${writeConfig}
          writeConfig "$TMPDIR/config.lua" '{ name = "out", root = "'"$out"'" }'
          export LUAROCKS_CONFIG=$TMPDIR/config.lua
          luarocks make ${lib.escapeShellArg info.file}
          runHook postBuild
        '';
        checkPhase = ''
          runHook preCheck
          # The test dependencies go to a tree of their own, and the rock
          # comes from the output tree.
          writeConfig "$TMPDIR/test-config.lua" '{ name = "out", root = "'"$out"'" }, { name = "test", root = "'"$TMPDIR"'/test-tree" }'
          export LUAROCKS_CONFIG=$TMPDIR/test-config.lua
          # A command-type test runs Lua on its script with LUA_PATH and
          # LUA_CPATH from the environment, which `luarocks path` sets for
          # both trees.
          eval "$(luarocks path)"
          luarocks test --tree "$TMPDIR/test-tree" ${lib.escapeShellArg info.file}
          runHook postCheck
        '';
        dontInstall = true;
        passthru = {
          inherit (info) outputs;
          bin = lib.genAttrs info.outputs.bin (name: "${finalAttrs.finalPackage}/bin/${name}");
          modules =
            builtins.listToAttrs (
              map (f: {
                name = moduleName f;
                value = "${finalAttrs.finalPackage}/share/lua/${abi}/${f}";
              }) info.outputs.lua
            )
            // builtins.listToAttrs (
              map (f: {
                name = moduleName f;
                value = "${finalAttrs.finalPackage}/lib/lua/${abi}/${f}";
              }) info.outputs.lib
            );
          rock = rockFor info;
          inherit lua luarocks;
        };
        meta.mainProgram = if info.outputs.bin == [ ] then null else builtins.head info.outputs.bin;
      });
    in
    package;

  byFile = builtins.listToAttrs (
    map (info: {
      name = info.file;
      value = packageFor info;
    }) lock.rockspecs
  );
in
{
  inherit cache;
  rockspecs = byFile;
  packages = builtins.listToAttrs (
    map (info: {
      name = info.package;
      value = byFile.${info.file};
    }) lock.rockspecs
  );
}

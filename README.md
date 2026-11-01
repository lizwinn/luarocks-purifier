# luarocks-purifier

luarocks-purifier is a command and a Nix library for
[LuaRocks](https://luarocks.org) projects. It records every file LuaRocks
downloads for a project in a lockfile, so that Nix can build the project's
rocks offline in its sandbox. The project needs no generated Nix files: the
lockfile is JSON, and it names every output of every rock, so Nix reads it
directly.

- **The lock run.** `luarocks-purifier lock` builds each rockspec of the
  project with LuaRocks, with an empty cache, and records what LuaRocks
  fetches: rockspecs and rocks from the rocks servers, the source archives
  the rockspecs name, and git, Mercurial, Subversion and CVS checkouts. It
  writes them to `luarocks-purifier.lock.json` by URL and SHA-256, with the
  commands, Lua modules and C modules each rock installs.
- **Sandboxed builds.** `buildLuarocksProject` builds each rock with
  `luarocks make` in the Nix sandbox, from the locked files alone.
- **The interactive mode.** `luarocks-purifier luarocks ARGS...` runs
  LuaRocks on the locked files, offline, so `luarocks make` in the project
  installs what the Nix build installs.
- **Publishing what Nix built.** `luarocks-purifier publish ROCKSPEC` packs
  the source rock in the sandbox and uploads it with `luarocks upload`.

## Use

Lock the project, in its root, and commit the lockfile:

```zsh
nix run github:nix-purifiers/luarocks-purifier -- lock
```

The lock options are saved in the lockfile, and a later `lock` reuses them:

| Option | Meaning |
|---|---|
| `--lua VERSION` | The Lua to lock for: `5.1`, `5.2`, `5.3`, `5.4` (the default) or `luajit`. |
| `--server URL` | A rocks server to search before luarocks.org. A directory of the project is a local rocks server. |
| `--only-server URL` | A rocks server to search instead of luarocks.org (repeatable). |
| `--external-dep ATTR` | A nixpkgs attribute that provides a C library a rock needs, such as `zlib` or `openssl` (repeatable). |
| `--rockspec FILE` | A rockspec of the project (repeatable). The default is every `*.rockspec` in the project root. |

`lock` locks again only when a rockspec, the project's `luarocks.lock` or
an option changed. `relock` locks whatever changed.

The flake's `overlays.default` adds `buildLuarocksProject` to a package
set, and a package written for `callPackage` takes it by name:

```nix
# package.nix
{ buildLuarocksProject }:
(buildLuarocksProject { src = ./.; }).packages.app
```

```nix
{
  inputs.luarocks-purifier.url = "github:nix-purifiers/luarocks-purifier";
  inputs.nixpkgs.follows = "luarocks-purifier/nixpkgs";

  outputs = { nixpkgs, luarocks-purifier, ... }:
    let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ luarocks-purifier.overlays.default ];
      };
    in
    {
      packages.x86_64-linux.app = pkgs.callPackage ./package.nix { };
    };
}
```

### The outputs

`(buildLuarocksProject { src = ./.; }).packages.<package>` is the rock a
rockspec of the project defines, installed with its dependencies into a
LuaRocks tree (`bin/`, `share/lua/`, `lib/lua/` and `lib/luarocks/`). The
lockfile names what each rock installs, so each output is an attribute that
Nix knows without building:

| Attribute | What it is |
|---|---|
| `.bin.<command>` | The path of a command the rock installs. |
| `.modules.<module>` | The path of a Lua or C module, by module name, such as `.modules."app.words"`. |
| `.rock` | The source rock that `luarocks upload` publishes, packed in the sandbox: a directory that holds `<package>-<version>.src.rock`. |

`rockspecs.<file>` holds the same packages by rockspec file name. When a
rockspec depends on another rockspec of the same project, the build
installs that one first, from the project source.

The builder takes these arguments besides `src`:

| Argument | Meaning |
|---|---|
| `lockFile` | The lockfile. The default is `luarocks-purifier.lock.json` in `src`. |
| `externalDeps` | The C libraries the rocks need, as a list of packages. The default is the nixpkgs attributes the lockfile names. |
| `doCheck` | Run `luarocks test` for each rock. The default is false. |
| `fetchurl` | A fetcher for the locked files, called with `{ name, urls, hash }`, for credentials or other mirrors. |
| `fetchgit`, `fetchhg`, `fetchsvn`, `fetchcvs` | The fetchers for locked checkouts, for instance a `fetchgit` with access to a private repository. |

### The interactive mode

```zsh
nix run github:nix-purifiers/luarocks-purifier -- luarocks make
```

runs `luarocks make` with the rocks servers replaced by the locked files,
which Nix builds into a cache under `.luarocks-purifier/` (one GC root).
Rocks go to `lua_modules/` in the project. A dependency that is not in the
lockfile fails with a hint to run `luarocks-purifier lock`. When the
lockfile is missing or out of date, the command warns and runs LuaRocks with
network access.

### Publishing

```zsh
nix run github:nix-purifiers/luarocks-purifier -- publish app-0.1-1.rockspec --api-key KEY
```

builds the rockspec's source rock with Nix and uploads the rockspec and the
source rock with `luarocks upload`, with certificate checks on. LuaRocks
keeps the API key in `~/.luarocks/upload_config.lua`, as `luarocks upload`
does. The arguments after the rockspec go to `luarocks upload`.

The source rock holds the rockspec's own source:

- For a git, Mercurial, Subversion or CVS source, the project source stands
  in for the tag or branch the rockspec names.
- For a source archive without an md5, the project source is packed as the
  archive, in the directory the rockspec names.
- A source archive pinned by `md5` is the published archive, which the lock
  run downloads when it exists. Publish the archive (by tagging the release)
  before you lock.

## Sources

Every source LuaRocks fetches is locked:

| Source | How it is locked |
|---|---|
| Rockspecs and rocks of a rocks server | A file entry, with the server's mirrors (luarocks.org has two) as fallbacks. |
| `http://`, `https://` and `ftp://` archives | A file entry. |
| `git+https://`, `git+ssh://`, `git://`, `git+file://` | A git checkout at the commit of the tag or branch, with submodules when the rockspec format is 3.0, as LuaRocks fetches it. An SSH URL is locked under the HTTPS URL of the same host. |
| `hg+https://`, `hg://` | A Mercurial checkout at the revision of the tag. |
| `svn://` | A Subversion checkout at the revision. |
| `cvs://` | A CVS export of the module at the tag. |
| A rocks server in the project | Served from the project source. |

A rockspec whose source is Surround SCM (`sscm://`) stops the lock run.
Surround SCM is proprietary, its server needs credentials for every
checkout, and nixpkgs has no fetcher for it.

The lock run searches only for platform-neutral rocks (rockspecs, source
rocks and `all` rocks), so one lockfile builds on every platform, and C
code is compiled in the sandbox.

## C libraries

A rock that links a C library from outside LuaRocks names it under
`external_dependencies`. Lock with `--external-dep` and the nixpkgs
attribute of the library:

```zsh
nix run github:nix-purifiers/luarocks-purifier -- lock --external-dep zlib
```

The lockfile records the attribute name. The lock run, the interactive mode
and the sandboxed build put the library's headers and libraries where
LuaRocks and the C compiler look for them.

## Limits

- A rock whose build downloads files itself, past LuaRocks (for instance
  with a CMake `ExternalProject`), fails in the sandbox: LuaRocks does not
  see those downloads, so the lock run cannot record them.
- A dependency on `scm` or `dev` versions locks the commit the branch points
  at during the lock run. A relock moves it to the newest commit.

## Credit

The purifier idea was inspired by nixcloud's
[cargo (libnix)](https://github.com/nixcloud/cargo). luarocks-purifier
follows the design of
[sbt-purifier](https://github.com/nix-purifiers/sbt-purifier).

## License

MIT

# luarocks-purifier

luarocks-purifier is a command and a Nix library for
[LuaRocks](https://luarocks.org) projects. It records every file LuaRocks
downloads for a project in a lockfile, so that Nix can build the project's
rocks offline in its sandbox. The project needs no generated Nix files: the
lockfile is JSON, and it names every output of every rock, so Nix reads it
directly.

luarocks-purifier is one of the [nix-purifiers](https://github.com/nix-purifiers),
and it meets their contract: the same builder interface, commands, checks
and README sections as every other purifier.

## Quickstart

Lock the project, in its root, and commit the lockfile
`luarocks-purifier.lock.json`:

```zsh
nix run github:nix-purifiers/luarocks-purifier -- lock
```

The lock run builds each rockspec of the project with LuaRocks, with an
empty cache, and records what LuaRocks fetches: rockspecs and rocks from
the rocks servers, the source archives the rockspecs name, and git,
Mercurial, Subversion and CVS checkouts. It records them by URL and
SHA-256, with the commands, Lua modules and C modules each rock installs.
Its options are saved in the lockfile, and a later `lock` reuses them:

| Option | Meaning |
|---|---|
| `--lua VERSION` | The Lua to lock for: `5.1`, `5.2`, `5.3`, `5.4` (the default) or `luajit`. |
| `--server URL` | A rocks server to search before luarocks.org. A directory of the project is a local rocks server. |
| `--only-server URL` | A rocks server to search instead of luarocks.org (repeatable). |
| `--external-dep ATTR` | A nixpkgs attribute that provides a C library a rock needs, such as `zlib` or `openssl` (repeatable). |
| `--rockspec FILE` | A rockspec of the project (repeatable). The default is every `*.rockspec` in the project root. |

Build the project with the builder in the flake's library:

```nix
{
  inputs.luarocks-purifier.url = "github:nix-purifiers/luarocks-purifier";
  inputs.nixpkgs.follows = "luarocks-purifier/nixpkgs";

  outputs = { nixpkgs, luarocks-purifier, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      project = luarocks-purifier.lib.luarocks-purifier.buildLuarocksProject {
        inherit pkgs;
        src = ./.;
      };
    in
    {
      packages.x86_64-linux.default = project.packages.app;
      checks.x86_64-linux.tests = project.tests;
    };
}
```

The builder takes these arguments:

| Argument | Meaning |
|---|---|
| `pkgs` | The package set to build with. |
| `src` | The project root. |
| `lockFile` | The lockfile. The default is `luarocks-purifier.lock.json` in `src`. A lockfile outside `src` replaces any copy in it, so a packaging flake can build a project whose author does not use luarocks-purifier. |
| `luarocksLock` | LuaRocks' own lockfile, `luarocks.lock`, for a `src` that holds none. It replaces any copy in `src`. |
| `externalDeps` | The C libraries the rocks need, as a list of packages. The default is the nixpkgs attributes the lockfile names. |
| `fetchers` | Fetchers that replace those of nixpkgs for the locked downloads, by name: `fetchurl`, `fetchgit`, `fetchhg`, `fetchsvn` and `fetchcvs`. A company mirror or credentials go into `fetchers.fetchurl`. The shared [purifier](https://github.com/nix-purifiers/purifier) library calls each with the arguments of the nixpkgs fetcher of the same name. |

The result has these attributes, each known without building:

| Attribute | What it is |
|---|---|
| `packages.<package>` | The rock a rockspec of the project defines, installed with its dependencies into a LuaRocks tree (`bin/`, `share/lua/`, `lib/lua/` and `lib/luarocks/`). `.bin.<command>` is the path of a command it installs, and `.modules.<module>` the path of a Lua or C module, such as `.modules."app.words"`. |
| `tests` | `luarocks test` of every rockspec with a test suite, in the sandbox. |
| `release` | The source rocks that `luarocks-purifier publish` uploads, packed in the sandbox: a directory holding `<package>-<version>.src.rock` for each rockspec. |
| `fetches` | The download entries of the lockfile, in the shape of the shared purifier library. |

When a rockspec depends on another rockspec of the same project, the build
installs that one first, from the project source.

## Everyday loop

The everyday loop is LuaRocks' own commands, run on the locked files:

```zsh
nix run github:nix-purifiers/luarocks-purifier -- luarocks make
nix run github:nix-purifiers/luarocks-purifier -- luarocks test
```

`luarocks-purifier luarocks ARGS...` runs `luarocks ARGS...` with the rocks
servers replaced by the locked files, which Nix builds into a cache under
`.luarocks-purifier/`. Rocks go to `lua_modules/` in the project, and the
commands LuaRocks starts, such as busted for `luarocks test`, find them
there.

To add or upgrade a dependency, change the rockspec and lock again:

```zsh
nix run github:nix-purifiers/luarocks-purifier -- lock
```

A lock of an unchanged project reproduces the lockfile byte for byte, as
long as the rocks servers serve the same files. For luacheck, a relock
takes about 40 seconds.

Every command takes `--lockfile PATH` before its other arguments, for a
lockfile outside the project root.

## Offline work

```zsh
nix run github:nix-purifiers/luarocks-purifier -- prefetch
```

realizes everything the everyday loop needs in the Nix store and keeps it
with two garbage-collector roots in `.luarocks-purifier/`. `cache` holds
the locked files and C libraries, and `tools` holds luarocks-purifier with
its LuaRocks, Lua, C compiler and nixpkgs. `prefetch` also installs the
dependencies and test dependencies of every rockspec into `lua_modules`.
After it, `luarocks-purifier luarocks make` and `luarocks-purifier luarocks
test` work with the network cut off, and CI checks that they do.

## Editor

After `prefetch`, `lua_modules` holds every dependency as a standard
LuaRocks tree. Point the language server at it. For
[lua-language-server](https://luals.github.io), a `.luarc.json` in the
project root sets its library path:

```json
{
  "runtime.version": "Lua 5.4",
  "workspace.library": ["lua_modules/share/lua/5.4"]
}
```

For LuaJIT and Lua 5.1, the directory is `lua_modules/share/lua/5.1`.

## Errors and fixes

Every error names the command that fixes it.

| Error | Fix |
|---|---|
| A rockspec or `luarocks.lock` changed since the lock run (the lockfile is out of date). | `luarocks-purifier lock` |
| The lockfile was changed after `lock` wrote it (its `contentHash` does not match its content). | `luarocks-purifier lock` |
| The lockfile is not valid JSON, lacks a field, or has another format version. | `luarocks-purifier lock` |
| LuaRocks needs a rock, a version or a file the lockfile lacks. | Add the dependency to a rockspec, then `luarocks-purifier lock`. |
| A rock links a C library LuaRocks cannot find. | `luarocks-purifier lock --external-dep ATTR`, with the nixpkgs attribute of the library. |
| A server changed a file it serves (a hash mismatch when Nix fetches it). | `luarocks-purifier lock` |

The commands, the interactive mode and the Nix build all stop on these;
none of them falls back to the network.

A rock that links a C library from outside LuaRocks names it under
`external_dependencies`, and `--external-dep` gives the nixpkgs package.
The lockfile records the attribute name, and the lock run, the interactive
mode and the sandboxed build put the library's headers and libraries where
LuaRocks and the C compiler look for them. The libraries of the C library
itself, such as `m`, `dl`, `pthread` and `rt`, need no option.

## Sources supported and refused

| Source | How it is locked |
|---|---|
| Rockspecs and rocks of a rocks server | A file entry, with the server's mirrors (luarocks.org has two) as fallbacks. |
| `http://`, `https://` and `ftp://` archives | A file entry. |
| `git+https://`, `git+ssh://`, `git://`, `git+file://` | A git checkout at the commit of the tag or branch, with submodules when the rockspec format is 3.0, as LuaRocks fetches it. An SSH URL is locked under the HTTPS URL of the same host. |
| `hg+https://`, `hg://` | A Mercurial checkout at the revision of the tag, with subrepositories. |
| `svn://` | A Subversion checkout at the revision, with externals. |
| `cvs://` | A CVS export of the module at the tag. |
| A rocks server in the project | Served from the project source. |

The lock run searches only for platform-neutral rocks (rockspecs, source
rocks and `all` rocks), so one lockfile builds on every platform, and C
code is compiled in the sandbox.

These are refused or limited:

- A rockspec whose source is Surround SCM (`sscm://`) stops the lock run.
  Surround SCM is proprietary, its server needs credentials for every
  checkout, and nixpkgs has no fetcher for it.
- A CVS source without a tag stops the lock run, because nothing would pin
  its content.
- CVS sources lock and build on x86_64-linux only. On aarch64-linux, the CVS
  of nixpkgs aborts on every export and checkout, which both the lock run
  and nixpkgs' `fetchcvs` make: the copy of gnulib's `vasnprintf` that CVS
  bundles receives a corrupted string argument there.
- A rock whose build downloads files itself, past LuaRocks (for instance
  with a CMake `ExternalProject`), fails in the sandbox: LuaRocks does not
  see those downloads, so the lock run cannot record them.
- A dependency on `scm` or `dev` versions locks the commit the branch points
  at during the lock run. A relock moves it to the newest commit.

## Real-world projects

| Project | What CI checks |
|---|---|
| [luacheck](https://github.com/lunarmodules/luacheck) v1.2.0 | The flake check `real-luacheck` builds luacheck, unchanged, from a lockfile kept outside its source, and runs it on its own source. The CI job `real-luacheck` adds the three test dependencies that luacheck's own CI installs by hand (`lanes`, `luautf8` and `luasocket`) to its rockspec, locks it, runs its 460 specs in the sandbox, prefetches, and runs them again with `luarocks test` with the network cut off. |

luacheck found three defects, which are fixed: the C library of the
compiler was not where LuaRocks looks for `rt`, a builder attribute hid a
package's `outputs`, and the interactive mode dropped Lua's default module
path.

## Credits

The purifier idea was inspired by nixcloud's
[cargo (libnix)](https://github.com/nixcloud/cargo). luarocks-purifier
follows the design of
[sbt-purifier](https://github.com/nix-purifiers/sbt-purifier), and fetches
with the shared [purifier](https://github.com/nix-purifiers/purifier)
library. luarocks-purifier is under the MIT license.

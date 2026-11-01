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
LuaRocks' own lockfile, `luarocks.lock`, pins versions and records no URLs
or hashes, so luarocks-purifier writes `luarocks-purifier.lock.json` for the
downloads, and it reads `luarocks.lock` when the project has one. Its
options are saved in the lockfile, and a later `lock` reuses them:

| Option | Meaning |
|---|---|
| `--lua VERSION` | The Lua to lock for: `5.1`, `5.2`, `5.3`, `5.4` (the default) or `luajit`. |
| `--server URL` | A rocks server to search before luarocks.org. A directory of the project is a local rocks server. |
| `--only-server URL` | A rocks server to search instead of luarocks.org (repeatable). |
| `--external-dep ATTR` | A nixpkgs attribute that provides a C library a rock needs, such as `zlib` or `openssl` (repeatable). |
| `--rockspec FILE` | A rockspec of the project (repeatable). The default is every `*.rockspec` in the project root. |

Build the project from its directory. The command adds no Nix file to the
project, and `app` is the package name in the rockspec:

```zsh
nix build --impure --expr '
  let
    purifier = builtins.getFlake "github:nix-purifiers/luarocks-purifier";
    pkgs = import purifier.inputs.nixpkgs {
      system = builtins.currentSystem;
      overlays = [ purifier.overlays.default ];
    };
  in
  (pkgs.luarocks-purifier.buildLuarocksProject { src = ./.; }).packages.app'
```

This uses the purifier's pinned nixpkgs, matching the lock command above.
To build with ambient `<nixpkgs>` from your Nix search path instead,
replace `import purifier.inputs.nixpkgs` with `import <nixpkgs>`.
Both forms need no Nix files in your project. The build tool and language
versions must match the lockfile; with ambient nixpkgs, lock with the
purifier from that package set or pass a compatible toolchain to the builder.

The result is `./result`, the rock installed into a LuaRocks tree, with the
commands the rock installs in `result/bin`.

A project whose authors want a flake can package itself with one. The flake
can live in the project's repository or in another one, and it calls the
builder directly:

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
      packages.x86_64-linux.default =
        (pkgs.luarocks-purifier.buildLuarocksProject { src = ./.; }).packages.app;
    };
}
```

The overlay `overlays.default` adds one attribute to a package set: the
scope `luarocks-purifier`. The scope holds the builder
`buildLuarocksProject`, the command `cli` and the tool stand-ins `shims`.
`luarocks-purifier.buildLuarocksProject.override` replaces any package the
builder takes, and `luarocks-purifier.overrideScope` replaces what everything
in the scope shares.

We recommend committing both lockfiles to the project's repository:
`luarocks-purifier.lock.json`, and `luarocks.lock` when the project has one.
The builder and the commands look for them in the project by default. The
builder takes these arguments:

| Argument | Meaning |
|---|---|
| `src` | The project root. |
| `lockFile` | The lockfile. The default is `luarocks-purifier.lock.json` in `src`. A lockfile outside `src` takes the place of any copy in it. |
| `luarocksLock` | LuaRocks' own lockfile, `luarocks.lock`. The default is the copy in `src`. A copy kept outside `src` takes its place. |
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

`luarocks-purifier.lib.luarocks-purifier.readLock { src, lockFile ? ... }`
reads the lockfile into the lock in memory that every purifier shares, for
tools such as SBOM generators: `purifier`, the download `entries`, the
`outputs` of each rock (its rockspec, version, commands and modules), and
`problems`, which names `luarocks-purifier lock` for a lockfile that is out
of date or changed by hand. The builder checks it with `checkLock` of the
shared purifier library.

## Development loop

LuaRocks has no plugin mechanism, so luarocks-purifier is a command that
runs LuaRocks itself, with the locked files in place of the network. The
development loop is LuaRocks' own commands, run on the locked files:

```zsh
nix run github:nix-purifiers/luarocks-purifier -- luarocks make
nix run github:nix-purifiers/luarocks-purifier -- luarocks test
```

`luarocks-purifier luarocks ARGS...` runs `luarocks ARGS...` with the rocks
servers replaced by the locked files, which Nix builds into a cache under
`.luarocks-purifier/`. Rocks go to `lua_modules/` in the project, and the
commands LuaRocks starts, such as busted for `luarocks test`, find them
there.

To add a dependency, change the rockspec and lock again:

```zsh
nix run github:nix-purifiers/luarocks-purifier -- lock
```

`lock` keeps the versions that `luarocks.lock` pins. A project often has no
`luarocks.lock`. Then `lock` resolves the newest versions the rockspecs
allow and records them in `luarocks-purifier.lock.json`, and it leaves the
project's files alone. To pin versions in `luarocks.lock`, or to move to
newer versions, run `update`, with the names of the rocks to move or with
none to move them all:

```zsh
nix run github:nix-purifiers/luarocks-purifier -- update argparse
```

LuaRocks has no update command of its own, so `update` drops those pins,
lets `luarocks make` resolve the rocks again within the constraints of the
rockspecs, writes the result to `luarocks.lock`, and then locks.

A lock of an unchanged project reproduces the lockfile byte for byte, as
long as the rocks servers serve the same files.

A project can keep its lockfiles outside its repository, as the last
subsection of Examples shows. Every command then takes `--lockfile PATH` before its
other arguments, and `--tool-lockfile PATH` for `luarocks.lock`. The
environment variables `LUAROCKS_PURIFIER_LOCKFILE` and
`LUAROCKS_PURIFIER_TOOL_LOCKFILE` name the same paths, and the options take
precedence over them. With `--tool-lockfile`, `update` writes `luarocks.lock`
there and leaves the copy in the project as it is, and the commands start
from the copy in the project until the outside one exists.

## Working offline

```zsh
nix run github:nix-purifiers/luarocks-purifier -- prefetch
```

realizes everything the development loop needs in the Nix store and keeps
it with two garbage-collector roots in `.luarocks-purifier/`. That
directory lies in the project root, also when the lockfile is kept
elsewhere. `cache` holds
the locked files and C libraries, and `tools` holds luarocks-purifier with
its LuaRocks, Lua, C compiler and nixpkgs. `prefetch` also installs the
dependencies and test dependencies of every rockspec into `lua_modules`.
After it, `luarocks-purifier luarocks make` and `luarocks-purifier luarocks
test` work with the network cut off.

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

`prefetch` realizes the rocks, and the language server comes from your own
editor setup, such as the nixpkgs package `lua-language-server`.

## Troubleshooting

Every error names the command that fixes it.

| Error | Fix |
|---|---|
| A rockspec or `luarocks.lock` changed since the lock run (the lockfile is out of date). | `luarocks-purifier lock` |
| The lockfile was changed after `lock` wrote it (its `contentHash` does not match its content). | `luarocks-purifier lock` |
| The lockfile is not valid JSON, lacks a field, or has another format version. | `luarocks-purifier lock` |
| LuaRocks needs a rock, a version or a file the lockfile lacks. | Add the dependency to a rockspec, then `luarocks-purifier lock`. |
| A rock links a C library LuaRocks cannot find. | `luarocks-purifier lock --external-dep ATTR`, with the nixpkgs attribute of the library. |
| A server changed a file it serves (a hash mismatch when Nix fetches it). | `luarocks-purifier lock` |

The commands and the Nix build stop on each of these errors.

A rock that links a C library from outside LuaRocks names it under
`external_dependencies`, and `--external-dep` gives the nixpkgs package.
The lockfile records the attribute name, and the lock run,
`luarocks-purifier luarocks` and the sandboxed build put the library's
headers and libraries where LuaRocks and the C compiler look for them. The
libraries of the C library itself, such as `m`, `dl`, `pthread` and `rt`,
need no option.

## Supported language repositories

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

Limits:

- A rockspec whose source is Surround SCM (`sscm://`) stops the lock run.
  Surround SCM is proprietary, its server needs credentials for every
  checkout, and nixpkgs has no fetcher for it.
- A CVS source without a tag stops the lock run, because nothing would pin
  its content.
- CVS sources lock and build on x86_64-linux only, because the CVS package
  of nixpkgs aborts on aarch64-linux, both in the lock run and in
  `fetchcvs`.
- A rock whose build downloads files itself, past LuaRocks (for instance
  with a CMake `ExternalProject`), fails in the sandbox: LuaRocks does not
  see those downloads, so the lock run cannot record them.
- A dependency on `scm` or `dev` versions locks the commit the branch points
  at during the lock run. A relock moves it to the newest commit.

## Examples

### Package luacheck

[luacheck](https://github.com/lunarmodules/luacheck) is a Lua linter. Clone
the release you want to package, and lock it:

```zsh
git clone --branch v1.2.0 https://github.com/lunarmodules/luacheck
cd luacheck
nix run github:nix-purifiers/luarocks-purifier -- lock
```

The lockfile `luarocks-purifier.lock.json` records every rock luacheck
needs, with a hash for each. Build luacheck from the checkout and run it:

```zsh
nix build --impure --expr '
  let
    purifier = builtins.getFlake "github:nix-purifiers/luarocks-purifier";
    pkgs = import purifier.inputs.nixpkgs {
      system = builtins.currentSystem;
      overlays = [ purifier.overlays.default ];
    };
  in
  (pkgs.luarocks-purifier.buildLuarocksProject { src = ./.; }).packages.luacheck'
./result/bin/luacheck --version
```

To work on luacheck, run the development commands in the checkout:

```zsh
nix run github:nix-purifiers/luarocks-purifier -- prefetch
nix run github:nix-purifiers/luarocks-purifier -- luarocks make
```

### Keep the lockfiles outside the repository

A flake can also package a project whose repository stays as published, with
no luarocks-purifier files in it. The flake keeps the lockfile next to its
own `flake.nix`, and takes luacheck as an input that is not a flake. Lock
from a checkout, and name the lockfile with `--lockfile`:

```zsh
mkdir luacheck-nix
cd luacheck
nix run github:nix-purifiers/luarocks-purifier -- lock --lockfile ../luacheck-nix/luarocks-purifier.lock.json
```

Then `luacheck-nix/flake.nix` passes the lockfile to the builder:

```nix
{
  inputs.luarocks-purifier.url = "github:nix-purifiers/luarocks-purifier";
  inputs.nixpkgs.follows = "luarocks-purifier/nixpkgs";
  inputs.luacheck = {
    url = "github:lunarmodules/luacheck/v1.2.0";
    flake = false;
  };

  outputs = { nixpkgs, luarocks-purifier, luacheck, ... }:
    let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ luarocks-purifier.overlays.default ];
      };
    in
    {
      packages.x86_64-linux.default =
        (pkgs.luarocks-purifier.buildLuarocksProject {
          src = luacheck;
          lockFile = ./luarocks-purifier.lock.json;
        }).packages.luacheck;
    };
}
```

Build it with `nix run path:. -- --version` in `luacheck-nix`. In the
checkout, the development commands name the same lockfile:

```zsh
nix run github:nix-purifiers/luarocks-purifier -- prefetch --lockfile ../luacheck-nix/luarocks-purifier.lock.json
nix run github:nix-purifiers/luarocks-purifier -- luarocks --lockfile ../luacheck-nix/luarocks-purifier.lock.json make
```

## Credits

The purifier idea was inspired by nixcloud's
[cargo (libnix)](https://github.com/nixcloud/cargo). luarocks-purifier
follows the design of
[sbt-purifier](https://github.com/nix-purifiers/sbt-purifier), and fetches
with the shared [purifier](https://github.com/nix-purifiers/purifier)
library. luarocks-purifier is under the MIT license.

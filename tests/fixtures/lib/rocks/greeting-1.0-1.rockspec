-- A rock of the fixture's own rocks server (this directory, given to the
-- lock run with --server ./rocks). Its source is a git tag, and the rockspec
-- format 3.0 makes LuaRocks check out submodules.
rockspec_format = "3.0"
package = "greeting"
version = "1.0-1"
source = {
   url = "git+https://github.com/kikito/inspect.lua.git",
   tag = "v3.1.3",
}
description = {
   summary = "A luarocks-purifier test fixture from a local rocks server",
   license = "MIT",
}
dependencies = {
   "lua >= 5.1",
}
build = {
   type = "builtin",
   modules = {
      greeting = "inspect.lua",
   },
}

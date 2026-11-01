package = "hgrock"
version = "1.0-1"
source = {
   url = "hg+https://hg.example.org/hgrock",
   tag = "1.0",
}
description = {
   summary = "A luarocks-purifier test fixture with a Mercurial source",
   license = "MIT",
}
dependencies = {
   "lua >= 5.1",
}
build = {
   type = "builtin",
   modules = {
      hgrock = "hgrock.lua",
   },
}

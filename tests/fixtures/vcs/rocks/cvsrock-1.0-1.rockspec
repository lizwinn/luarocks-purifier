package = "cvsrock"
version = "1.0-1"
source = {
   url = "cvs://:pserver:anonymous@cvs.example.org:/cvsroot",
   module = "cvsrock",
   tag = "REL_1_0",
}
description = {
   summary = "A luarocks-purifier test fixture with a CVS source",
   license = "MIT",
}
dependencies = {
   "lua >= 5.1",
}
build = {
   type = "builtin",
   modules = {
      cvsrock = "cvsrock.lua",
   },
}

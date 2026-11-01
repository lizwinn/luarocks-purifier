package = "svnrock"
version = "1.0-1"
source = {
   url = "svn://svn.example.org/svnrock",
   tag = "5",
}
description = {
   summary = "A luarocks-purifier test fixture with a Subversion source",
   license = "MIT",
}
dependencies = {
   "lua >= 5.1",
}
build = {
   type = "builtin",
   modules = {
      svnrock = "svnrock.lua",
   },
}

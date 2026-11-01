package = "vcs"
version = "1.0-1"
source = {
   url = "git+https://example.org/vcs.git",
   tag = "v1.0",
}
description = {
   summary = "A luarocks-purifier test fixture whose dependencies come from Mercurial, Subversion and CVS",
   license = "MIT",
}
dependencies = {
   "lua >= 5.1",
   "hgrock == 1.0",
   "svnrock == 1.0",
   "cvsrock == 1.0",
}
build = {
   type = "builtin",
   modules = {
      vcs = "vcs.lua",
   },
}

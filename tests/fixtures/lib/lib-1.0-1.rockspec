package = "lib"
version = "1.0-1"
-- A release archive that does not exist yet: the source rock packs the
-- project source in its place.
source = {
   url = "https://example.org/releases/lib-1.0.tar.gz",
   dir = "lib-1.0",
}
description = {
   summary = "A luarocks-purifier test fixture",
   license = "MIT",
}
dependencies = {
   "lua >= 5.1",
   -- From the local rocks server.
   "greeting == 1.0",
   -- From luarocks.org.
   "inspect == 3.1.3",
}
build = {
   type = "builtin",
   modules = {
      lib = "src/lib.lua",
   },
}

package = "lib-demo"
version = "1.0-1"
-- A source archive pinned by md5, which the lock run downloads for the
-- source rock. The archive is the argparse 0.7.1 release, which stands in
-- for a published release of this rock.
source = {
   url = "https://github.com/luarocks/argparse/archive/0.7.1.zip",
   md5 = "3393e3336b47dade24e0f273c6ae4ddb",
   dir = "argparse-0.7.1",
}
description = {
   summary = "A luarocks-purifier test fixture that depends on another rock of its project",
   license = "MIT",
}
dependencies = {
   "lua >= 5.1",
   "lib == 1.0",
}
build = {
   type = "builtin",
   modules = {
      lib_demo = "src/lib_demo.lua",
   },
   install = {
      bin = {
         ["lib-demo"] = "bin/lib-demo",
      },
   },
}

#!/usr/bin/env coffee
"use strict"

packageJSON = require("../package.json")
commander = require("commander")
Hikaru = require("./hikaru")

commander
.version(packageJSON["version"])
.usage("<subcommand> [options] [dir]")
.description(packageJSON["description"])

commander.command("init [dir]").alias("i")
.option("-d", "--debug", "Print debug messages.")
.option("-s", "--srcDir <dir>", "Alternative src dir.")
.option("-d", "--docDir <dir>", "Alternative doc dir.")
.option("-t", "--themeDir <dir>", "Alternative theme dir.")
.action((dir, cmd) ->
  new Hikaru(cmd["debug"]).init(dir || ".", cmd["srcDir"],
  cmd["docDir"], cmd["themeDir"])
)

commander.command("clean [dir]").alias("c")
.option("-d", "--debug", "Print debug messages.")
.action((dir, cmd) ->
  new Hikaru(cmd["debug"]).clean(dir || ".")
)

commander.command("generate [dir]").alias("g")
.option("-d", "--debug", "Print debug messages.")
.option("-c", "--config <yml>", "Alternative config path.")
.option("-s", "--srcDir <dir>", "Alternative src dir.")
.option("-d", "--docDir <dir>", "Alternative doc dir.")
.option("-t", "--themeDir <dir>", "Alternative theme dir.")
.action((dir, cmd) ->
  new Hikaru(cmd["debug"]).generate(dir || ".", cmd["config"],
  cmd["srcDir"], cmd["docDir"], cmd["themeDir"])
)

commander.parse(process.argv)

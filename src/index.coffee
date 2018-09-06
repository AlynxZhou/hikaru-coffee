packageJSON = require("../package.json")
commander = require("commander")
Hikaru = require("./hikaru")

commander
.version(packageJSON["version"])
.usage("<subcommand> [options] [dir]")
.description(packageJSON["description"])

commander.command("init [dir]").alias("i")
.option("-g, --debug", "Print debug messages.")
.option("-c, --config <yml>", "Alternative config path.")
.action((dir, cmd) ->
  new Hikaru(cmd["debug"]).init(dir || ".", cmd["config"])
)

commander.command("clean [dir]").alias("c")
.option("-g, --debug", "Print debug messages.")
.option("-c, --config <yml>", "Alternative config path.")
.action((dir, cmd) ->
  new Hikaru(cmd["debug"]).clean(dir || ".")
)

commander.command("generate [dir]").alias("g")
.option("-g, --debug", "Print debug messages.")
.option("-c, --config <yml>", "Alternative config path.")
.action((dir, cmd) ->
  new Hikaru(cmd["debug"]).generate(dir || ".", cmd["config"])
)

commander.parse(process.argv)

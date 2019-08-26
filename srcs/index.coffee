packageJSON = require("../package.json")
commander = require("commander")
Hikaru = require("./hikaru")

commander
.version(packageJSON["version"])
.usage("<subcommand> [options] [dir]")
.description(packageJSON["description"])

commander.command("init [dir]").alias("i")
.option("-d, --debug", "Print debug messages.")
.option("-c, --config <yml>", "Alternative site config path.")
.action((dir, cmd) ->
  new Hikaru(cmd["debug"]).init(dir || ".", cmd["config"])
)

commander.command("clean [dir]").alias("c")
.option("-d, --debug", "Print debug messages.")
.option("-c, --config <yml>", "Alternative site config path.")
.action((dir, cmd) ->
  new Hikaru(cmd["debug"]).clean(dir || ".")
)

commander.command("build [dir]").alias("b")
.option("-d, --debug", "Print debug messages.")
.option("-c, --config <yml>", "Alternative site config path.")
.action((dir, cmd) ->
  new Hikaru(cmd["debug"]).build(dir || ".", cmd["config"])
)

commander.command("serve [dir]").alias("s")
.option("-d, --debug", "Print debug messages.")
.option("-c, --config <yml>", "Alternative site config path.")
.option("-i, --ip <ip>", "Alternative listening IP address.")
.option("-p, --port <port>", "Alternative listening port.")
.action((dir, cmd) ->
  new Hikaru(cmd["debug"]).serve(
    dir || ".", cmd["config"], cmd["ip"], cmd["port"]
  )
)

commander.parse(process.argv)

colors = require("colors/safe")
Promise = require("bluebird")

module.exports =
class Logger extends console.Console
  constructor: (debug, options = {
    "stdout": process.stdout,
    "stderr": process.stderr
  }) ->
    super(options)
    @isDebug = debug

  log: (strs...) ->
    super.log("LOG:", strs...)

  info: (strs...) ->
    super.info(colors.blue("INFO:"), strs...)

  debug: (strs...) ->
    if @isDebug
      super.debug(colors.green("DEBUG:"), strs...)

  warn: (strs...) ->
    super.warn(colors.yellow("WARN:"), strs...)

  error: (strs...) ->
    super.error(colors.red("ERROR:"), strs...)

colors = require("colors/safe")

module.exports =
class Logger
  constructor: (debug) ->
    @isDebug = debug

  info: (strs...) ->
    console.log(colors.yellow("INFO:"), strs...)

  debug: (strs...) ->
    if @isDebug
      console.debug(colors.green("DEBUG:"), strs...)

  error: (strs...) ->
    console.log(colors.red("ERROR:"), strs...)

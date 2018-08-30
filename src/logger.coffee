"use strict"

module.exports =
class Logger
  constructor: (debug) ->
    @debug = debug

  info: (strs...) ->
    console.log("INFO:", strs...)

  debug: (strs...) ->
    if @debug
      console.debug("DEBUG:", strs...)

  error: (strs...) ->
    console.log("ERROR:", strs...)

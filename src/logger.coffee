"use strict"

module.exports =
class Logger
  constructor: (debug) ->
    @isDebug = debug

  info: (strs...) ->
    console.log("INFO:", strs...)

  debug: (strs...) ->
    if @isDebug
      console.debug("DEBUG:", strs...)

  error: (strs...) ->
    console.log("ERROR:", strs...)

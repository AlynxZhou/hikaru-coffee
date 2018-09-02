"use strict"
path = require("path")
module.exports =
class Renderer
  constructor: (logger) ->
    @logger = logger
    @store = {}

  # fn: param text, fullPath, ctx, return Promise
  register: (srcExt, fn) =>
    if srcExt instanceof Object
      @store[srcExt["srcExt"]] = srcExt["fn"]
      return
    @store[srcExt] = fn

  render: (text, fullPath, ctx) =>
    srcExt = path.extname(fullPath)
    if srcExt of @store
      return @store[srcExt](text, fullPath, ctx)
    return null

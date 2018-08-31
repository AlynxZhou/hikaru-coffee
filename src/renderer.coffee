"use strict"
path = require("path")
module.exports =
class Renderer
  constructor: (logger) ->
    @logger = logger
    @renderers = {}

  # fn: param text, fullPath, ctx, return Promise
  register: (srcExt, fn) =>
    if srcExt instanceof Object
      @renderers[srcExt["srcExt"]] = fn
      return
    @renderers[srcExt] = fn

  render: (text, fullPath, ctx) =>
    srcExt = path.extname(fullPath)
    if srcExt of @renderers
      fn = @renderers[srcExt]
      return fn(text, fullPath, ctx)
    return null

"use strict"
path = require("path")
module.exports =
class Renderer
  constructor: (logger) ->
    @logger = logger
    @renderers = {}

  # fn: param data | ctx, return Promise
  register: (srcExt, docExt, fn) =>
    if srcExt instanceof Object
      @renderers[srcExt["srcExt"]] = srcExt
      return
    if docExt instanceof Function
      fn = docExt
      docExt = null
    # @logger.info("Storing")
    @renderers[srcExt] = {"srcExt": srcExt, "docExt": docExt, "fn": fn}

  render: (data, ctx) =>
    # dirname shoule not contain src/ and doc/
    extname = path.extname(data["srcPath"])
    dirname = path.dirname(data["srcPath"])
    basename = path.basename(data["srcPath"], extname)
    if extname of @renderers
      fn = @renderers[extname]["fn"]
      docExt = @renderers[extname]["docExt"]
      return fn(data, ctx).then((res) ->
        data["content"] = res
        data["docPath"] = path.join(dirname, "#{basename}#{docExt}")
      ).catch(@logger.error)
    else
      # This will be copied.
      data["content"] = null
      data["docPath"] = data["srcPath"]

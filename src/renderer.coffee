path = require("path")

module.exports =
class Renderer
  constructor: (logger) ->
    @logger = logger
    @store = {}

  # fn: param data, ctx, return Promise
  register: (srcExt, docExt, fn) =>
    if srcExt instanceof Array
      for s in srcExt
        @store[s] = {"srcExt": s, "docExt": docExt, "fn": fn}
      return
    @store[srcExt] = {"srcExt": srcExt, "docExt": docExt, "fn": fn}

  render: (data, ctx) =>
    srcExt = path.extname(data["srcPath"])
    if srcExt of @store
      docExt = @store[srcExt]["docExt"]
      if docExt?
        dirname = path.dirname(data["srcPath"])
        basename = path.basename(data["srcPath"], srcExt)
        data["docPath"] = path.join(dirname, "#{basename}#{docExt}")
      else
        data["docPath"] = data["srcPath"]
      return @store[srcExt]["fn"](data, ctx)
    data["docPath"] = data["srcPath"]
    return data

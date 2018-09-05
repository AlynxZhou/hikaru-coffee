path = require("path")

module.exports =
class Renderer
  constructor: (logger, skipRenderList) ->
    @logger = logger
    @store = {}
    @skipRenderList = skipRenderList or []

  # fn: param data, ctx, return Promise
  register: (srcExt, docExt, fn) =>
    if srcExt instanceof Array
      for s in srcExt
        if fn instanceof Function
          @store[s] = {"srcExt": s, "docExt": docExt, "fn": fn}
      return
    if fn instanceof Function
      @store[srcExt] = {"srcExt": srcExt, "docExt": docExt, "fn": fn}

  render: (data, ctx) =>
    srcExt = path.extname(data["srcPath"])
    if srcExt of @store and data["srcPath"] not in @skipRenderList
      docExt = @store[srcExt]["docExt"]
      if docExt?
        dirname = path.dirname(data["srcPath"])
        basename = path.basename(data["srcPath"], srcExt)
        data["docPath"] = path.join(dirname, "#{basename}#{docExt}")
      else
        data["docPath"] = data["srcPath"]
      return @store[srcExt]["fn"](data, ctx)
    return new Promise((resolve, reject) ->
      try
        data["docPath"] = data["srcPath"]
        resolve(data)
      catch err
        reject(err)
    )

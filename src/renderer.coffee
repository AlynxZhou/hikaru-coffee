path = require("path")
colors = require("colors/safe")
Promise = require("bluebird")

module.exports =
class Renderer
  constructor: (logger, skipRenderList) ->
    @logger = logger
    @_ = {}
    @skipRenderList = skipRenderList or []

  # fn: param data, ctx, return Promise
  register: (srcExt, docExt, fn) =>
    if fn not instanceof Function
      throw new TypeError("fn must be a Function!")
      return
    if srcExt instanceof Array
      for s in srcExt
        @_[s] = {"srcExt": s, "docExt": docExt, "fn": fn}
      return
    @_[srcExt] = {"srcExt": srcExt, "docExt": docExt, "fn": fn}

  render: (data, ctx) =>
    srcExt = path.extname(data["srcPath"])
    if srcExt of @_ and data["srcPath"] not in @skipRenderList
      docExt = @_[srcExt]["docExt"]
      if docExt?
        dirname = path.dirname(data["srcPath"])
        basename = path.basename(data["srcPath"], srcExt)
        data["docPath"] = path.join(dirname, "#{basename}#{docExt}")
        @logger.debug(
          "Hikaru is rendering `#{colors.cyan(
            data["srcPath"]
          )}` to `#{colors.cyan(data["docPath"])}`..."
        )
      else
        data["docPath"] = data["srcPath"]
        @logger.debug("Hikaru is rendering `#{colors.cyan(
          data["srcPath"]
        )}`...")
      return @_[srcExt]["fn"](data, ctx)
    return new Promise((resolve, reject) =>
      try
        data["docPath"] = data["srcPath"]
        @logger.debug("Hikaru is rendering `#{colors.cyan(
          data["srcPath"]
        )}`...")
        resolve(data)
      catch err
        reject(err)
    )

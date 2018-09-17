path = require("path")
colors = require("colors/safe")
Promise = require("bluebird")

class Renderer
  constructor: (logger, skipRenderList) ->
    @logger = logger
    @_ = {}
    @skipRenderList = skipRenderList or []

  # fn: param file, ctx, return Promise
  register: (srcExt, docExt, fn) =>
    if fn not instanceof Function
      throw new TypeError("fn must be a Function!")
      return
    if srcExt instanceof Array
      for s in srcExt
        @_[s] = {"srcExt": s, "docExt": docExt, "fn": fn}
      return
    @_[srcExt] = {"srcExt": srcExt, "docExt": docExt, "fn": fn}

  render: (file, ctx) =>
    srcExt = path.extname(file["srcPath"])
    if srcExt of @_ and file["srcPath"] not in @skipRenderList
      docExt = @_[srcExt]["docExt"]
      if docExt?
        dirname = path.dirname(file["srcPath"])
        basename = path.basename(file["srcPath"], srcExt)
        file["docPath"] = path.join(dirname, "#{basename}#{docExt}")
        @logger.debug(
          "Hikaru is rendering `#{colors.cyan(
            file["srcPath"]
          )}` to `#{colors.cyan(file["docPath"])}`..."
        )
      else
        file["docPath"] = file["srcPath"]
        @logger.debug("Hikaru is rendering `#{colors.cyan(
          file["srcPath"]
        )}`...")
      return @_[srcExt]["fn"](file, ctx)
    return new Promise((resolve, reject) =>
      try
        file["docPath"] = file["srcPath"]
        @logger.debug("Hikaru is rendering `#{colors.cyan(
          file["srcPath"]
        )}`...")
        file["content"] = file["raw"]
        resolve(file)
      catch err
        reject(err)
    )

module.exports = Renderer

path = require("path")
colors = require("colors/safe")
Promise = require("bluebird")
{File} = require("./types")

class Renderer
  constructor: (logger, skipRenderList) ->
    @logger = logger
    @_ = {}
    @skipRenderList = skipRenderList or []

  register: (srcExt, docExt, fn) =>
    if fn not instanceof Function
      throw new TypeError("fn must be a Function!")
      return
    if srcExt not of @_
      @_[srcExt] = []
    @_[srcExt].push({"srcExt": srcExt, "docExt": docExt, "fn": fn})

  render: (input) =>
    srcExt = path.extname(input["srcPath"])
    results = []
    if srcExt of @_ and input["srcPath"] not in @skipRenderList
      for handler in @_[srcExt]
        output = new File(input)
        docExt = handler["docExt"]
        if docExt?
          dirname = path.dirname(output["srcPath"])
          basename = path.basename(output["srcPath"], srcExt)
          output["docPath"] = path.join(dirname, "#{basename}#{docExt}")
          @logger.debug(
            "Hikaru is rendering `#{
              colors.cyan(output["srcPath"])
            }` to `#{
              colors.cyan(output["docPath"])
            }`..."
          )
        else
          output["docPath"] = output["srcPath"]
          @logger.debug("Hikaru is rendering `#{colors.cyan(
            output["srcPath"]
          )}`...")
        results.push(handler["fn"](output))
    else
      # Or if file has no registered renderer...
      output = new File(input)
      output["docPath"] = output["srcPath"]
      @logger.debug("Hikaru is rendering `#{colors.cyan(
        output["srcPath"]
      )}`...")
      output["content"] = output["raw"]
      results.push(output)
    return results

module.exports = Renderer

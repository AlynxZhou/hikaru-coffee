colors = require("colors/safe")
Promise = require("bluebird")
{isArray, isFunction} = require("./utils")

class Generator
  constructor: (logger) ->
    @logger = logger
    @_ = []

  register: (name, fn) =>
    if not isFunction(fn)
      throw new TypeError("fn must be a Function!")
      return
    @_.push({"name": name, "fn": fn})

  generate: (site) =>
    results = []
    for {name, fn} in @_
      @logger.debug("Hikaru is generating `#{colors.blue(name)}`...")
      res = await fn(site)
      if not res?
        continue
      if not isArray(res)
        results.push(res)
      else
        results = results.concat(res)
    return results

module.exports = Generator

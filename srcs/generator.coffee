colors = require("colors/safe")
Promise = require("bluebird")

class Generator
  constructor: (logger) ->
    @logger = logger
    @_ = []

  register: (name, fn) =>
    if fn not instanceof Function
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
      if res not instanceof Array
        results.push(res)
      else
        results = results.concat(res)
    return results

module.exports = Generator

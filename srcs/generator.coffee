colors = require("colors/safe")
Promise = require("bluebird")

class Generator
  constructor: (logger) ->
    @logger = logger
    @_ = []

  register: (fn) =>
    if fn not instanceof Function
      throw new TypeError("fn must be a Function!")
      return
    @_.push(fn)

  generate: (site) =>
    results = []
    for fn in @_
      res = await fn(site)
      if res not instanceof Array
        res = [results]
      for file in res
        @logger.debug("Hikaru is generating `#{
          colors.cyan(file["docPath"])
        }`...")
        results.push(file)
    return results

module.exports = Generator

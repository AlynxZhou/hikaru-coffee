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
      file = await fn(site)
      @logger.debug("Hikaru is generating `#{colors.cyan(file["docPath"])}`...")
      results.push(file)
    return results

module.exports = Generator

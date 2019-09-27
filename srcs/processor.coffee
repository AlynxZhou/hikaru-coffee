colors = require("colors/safe")
Promise = require("bluebird")
{Site, File, Category, Tag} = require("./types")
{isFunction} = require("./utils")

class Processor
  constructor: (logger) ->
    @logger = logger
    @_ = []

  register: (name, fn) =>
    if not isFunction(fn)
      throw new TypeError("fn must be a Function!")
      return
    @_.push({"name": name, "fn": fn})

  process: (site) =>
    for {name, fn} in @_
      @logger.debug("Hikaru is processing `#{colors.blue(name)}`...")
      site = await fn(site)
    return site

module.exports = Processor

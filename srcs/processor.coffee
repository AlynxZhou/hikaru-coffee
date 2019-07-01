colors = require("colors/safe")
Promise = require("bluebird")
{Site, File, Category, Tag} = require("./types")

class Processor
  constructor: (logger) ->
    @logger = logger
    @_ = {}

  register: (layout, fn) =>
    if fn not instanceof Function
      throw new TypeError("fn must be a Function!")
      return
    if layout instanceof Array
      for l in layout
        if l not of @_
          @_[l] = []
        @_[l].push(fn)
      return
    if layout not of @_
      @_[layout] = []
    @_[layout].push(fn)

  process: (p) =>
    @logger.debug(
      "Hikaru is processing `#{colors.cyan(p["docPath"])}`..."
    )
    key = p["layout"] or p["type"]
    if key of @_
      for fn in @_[key]
        p = await fn(p)
      return p
    return p

module.exports = Processor

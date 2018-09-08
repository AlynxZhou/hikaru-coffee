colors = require("colors/safe")

module.exports =
class Processer
  constructor: (logger) ->
    @logger = logger
    @_ = {}

  # fn: param p, posts, ctx, return Promise
  register: (layout, fn) =>
    if fn not instanceof Function
      throw new TypeError("fn must be a Function!")
      return
    if layout instanceof Array
      for l in layout
        @_[l] = {"layout": l, "fn": fn}
      return
    @_[layout] = {"layout": layout, "fn": fn}

  process: (p, posts, templates, ctx) =>
    @logger.debug(
      "Hikaru is processing `#{colors.cyan(p["docPath"])}`..."
    )
    if p["layout"] of @_
      return @_[p["layout"]]["fn"](p, posts, ctx)
    return Object.assign({}, p, ctx)

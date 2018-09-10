colors = require("colors/safe")
Promise = require("bluebird")

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
        if l not of @_
          @_[l] = []
        @_[l].push(fn)
      return
    if layout not of @_
      @_[layout] = []
    @_[layout].push(fn)

  process: (p, posts, ctx) =>
    @logger.debug(
      "Hikaru is processing `#{colors.cyan(p["docPath"])}`..."
    )
    if p["layout"] of @_
      results = []
      for fn in @_[p["layout"]]
        res = await fn(p, posts, ctx)
        if res instanceof Array
          results = results.concat(res)
          continue
        results.push(res)
      return results
    return Object.assign({}, p, ctx)

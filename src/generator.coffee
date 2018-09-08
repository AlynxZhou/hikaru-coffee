colors = require("colors/safe")

module.exports =
class Generator
  constructor: (logger) ->
    @logger = logger
    @_ = {
      "beforeProcessing": [],
      "afterProcessing": []
    }

  # fn: param site, change site.
  register: (type, fn) =>
    if fn not instanceof Function
      throw new TypeError("fn must be a Function!")
      return
    if type instanceof Array
      for t in type
        if type not of @_
          throw new TypeError(
            "type must be a String in #{Object.keys(@_)}!"
          )
          continue
        @_[t].push(fn)
      return
    if type not of @_
      throw new TypeError("type must be a String in #{Object.keys(@_)}!")
      return
    @_[type].push(fn)

  generate: (type, site) =>
    if type not of @_
      throw new TypeError("type must be a String in #{Object.keys(@_)}!")
      return
    @logger.debug("Hikaru is generating `#{colors.blue(type)}`...")
    for fn in @_[type]
      site = await fn(site)
    return site

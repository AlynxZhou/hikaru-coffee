module.exports =
class Generator
  constructor: (logger) ->
    @logger = logger
    @store = {}

  # fn: param page, pages, ctx, return Promise
  register: (layout, fn) =>
    if layout instanceof Array
      for l in layout
        if fn instanceof Function
          @store[l] = {"layout": l, "fn": fn}
      return
    if fn instanceof Function
      @store[layout] = {"layout": layout, "fn": fn}

  generate: (page, posts, ctx) =>
    layout = page["layout"] or "page"
    if layout of @store
      return @store[layout]["fn"](page, posts, ctx)
    return page

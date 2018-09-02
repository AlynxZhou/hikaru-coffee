module.exports =
class Generator
  constructor: (logger) ->
    @logger = logger
    @store = {}

  # fn: param page, pages, return Promise
  register: (layout, fn) =>
    if layout instanceof Array
      for l in layout
        @store[l] = fn
      return
    @store[layout] = fn

  generate: (page, posts) =>
    if page["layout"] of @store
      return @store[page["layout"]](page, posts)
    return page

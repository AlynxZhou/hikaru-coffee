"use strict"

module.exports =
class Generator
  constructor: (logger) ->
    @logger = logger
    @store = {}

  # fn: param page, pages, return Promise
  register: (layout, fn) =>
    if layout instanceof Object
      @store[layout["layout"]] = layout["fn"]
      return
    @store[layout] = fn

  generate: (page, posts) =>
    if page["layout"] of @store
      return @store[page["layout"]](page, posts)
    return page

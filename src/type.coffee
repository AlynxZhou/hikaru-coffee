class Site
  constructor: (workDir) ->
    @_ = {
      "workDir": workDir,
      "siteConfig": {},
      "themeConfig": {},
      "templates": {},
      "assets": [],
      "pages": [],
      "subs": [],
      "posts": [],
      "files": [],
      "categories": [],
      # Flattend categories length.
      "categoriesLength": 0,
      "tags": [],
      # Flattend tags length.
      "tagsLength": 0
    }

  get: (key) =>
    if typeof(key) isnt "string" or key not of @_
      throw new TypeError("key must be a string in #{Object.keys(@_)}!")
    return @_[key]

  set: (key, value) =>
    if typeof(key) isnt "string"
      throw new TypeError("key must be a string!")
    @_[key] = value

  # Put a file into an array.
  # If a file with the same docPath already in array, replace it.
  # Else append it.
  put: (key, file) =>
    if not key? or not file?
      return
    for i in [0...@_[key].length]
      if @_[key][i]["docPath"] is file["docPath"] and
      @_[key][i]["docDir"] is file["docDir"]
        @_[key][i] = file
        return
    @_[key].push(file)

  del: (key, file) =>
    if not key? or not file?
      return null
    for i in [0...@_[key].length]
      if @_[key][i]["srcPath"] is file["srcPath"] and
      @_[key][i]["srcDir"] is file["srcDir"]
        return @_[key].splice(i, 1)
    return null

  raw: () =>
    return @_

class File
  constructor: (docDir, srcDir, srcPath) ->
    @docDir = docDir
    @docPath = null
    @srcDir = srcDir
    @srcPath = srcPath
    @date = null
    @title = null
    @name = null
    @raw = null
    @text = null
    @content = null
    @type = null
    @frontMatter = {}
    @categories = []
    @tags = []
    @excerpt = null
    @more = null
    @pageArray = []
    @pageIndex = null

class Category
  constructor: (name, posts = [], subs = []) ->
    @name = name
    @posts = posts
    @subs = subs

class Tag
  constructor: (name, posts = []) ->
    @name = name
    @posts = posts

module.exports = {
  "Site": Site,
  "File": File,
  "Category": Category,
  "Tag": Tag
}

class Site
  constructor: (workDir) ->
    @_ = {
      "workDir": workDir,
      # You should not use these variables.
      "srcDir": "",
      "docDir": "",
      "themeDir": "",
      "themeSrcDir": "",
      "categoryDir": "",
      "tagDir": "",
      # end
      "siteConfig": {},
      "themeConfig": {},
      "templates": {},
      "assets": [],
      "pages": [],
      "posts": [],
      "files": [],
      "categories": [],
      # Flattened categories length.
      "categoriesLength": 0,
      "tags": [],
      # Flattened tags length.
      "tagsLength": 0
    }
    @wrap()

  wrap: () =>
    for key of @_ then do (key) =>
      Object.defineProperty(this, key, {
        "get": () => return @get(key),
        "set": (value) => @set(key, value)
      })

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
      if @_[key][i]["docPath"] is file["docPath"] and
      @_[key][i]["docDir"] is file["docDir"]
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
    @createdTime = null
    @updatedTime = null
    @zone = null
    @title = null
    @layout = null
    @comment = false
    @raw = null
    @text = null
    @content = null
    @type = null
    @frontMatter = {}
    @categories = []
    @tags = []
    @excerpt = null
    @more = null
    @$ = null
    @toc = []
    @posts = []
    @pageArray = []
    @pageIndex = null
    @next = null
    @prev = null

class Category
  constructor: (name, posts = [], subs = []) ->
    @name = name
    @posts = posts
    @subs = subs

class Tag
  constructor: (name, posts = []) ->
    @name = name
    @posts = posts

class Toc
  constructor: (name, archor, text, subs = []) ->
    @name = name
    @archor = archor
    @text = text
    @subs = subs

module.exports = {
  "Site": Site,
  "File": File,
  "Category": Category,
  "Tag": Tag,
  "Toc": Toc
}

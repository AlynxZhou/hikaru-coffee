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
      "posts": [],
      "pages": [],
      "assets": [],
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
      Object.defineProperty(@, key, {
        "get": (() =>
          return @_[key]),
        "set": ((value) =>
          @_[key] = value)
      })

  # Put a file into an array.
  # If a file with the same docPath already in array, replace it.
  # Else append it.
  put: (key, file) =>
    if not key? or not file?
      return
    i = @_[key].findIndex((element) ->
      return element["docPath"] is file["docPath"] and
      element["docDir"] is file["docDir"]
    )
    if i isnt -1
      @_[key][i] = file
    else
      @_[key].push(file)

  del: (key, file) =>
    if not key? or not file?
      return
    for i in [0...@_[key].length]
      if @_[key][i]["srcPath"] is file["srcPath"] and
      @_[key][i]["srcDir"] is file["srcDir"]
        @_[key].splice(i, 1)

  raw: () =>
    return @_

class File
  constructor: (docDir, srcDir, srcPath) ->
    @srcDir = srcDir
    @srcPath = srcPath
    @docDir = docDir
    @docPath = null
    @isBinary = false
    @createdTime = null
    @updatedTime = null
    @zone = null
    @title = null
    @layout = null
    @comment = null
    @reward = null
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
    # Don't use utils here, or it will cause circular dependencies.
    if typeof(docDir) is "object"
      Object.assign(@, docDir)

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

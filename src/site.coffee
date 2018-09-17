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
      if @_[key][i]["docPath"] is file["docPath"]
        @_[key][i] = file
        return
    @_[key].push(file)

  splice: (key, file) =>
    if not key? or not file?
      return null
    for i in [0...@_[key].length]
      if @_[key][i]["srcPath"] is file["srcPath"] and
      @_[key][i]["srcDir"] is file["srcDir"]
        return @_[key].splice(i, 1)
    return null

  raw: () =>
    return @_

module.exports = Site

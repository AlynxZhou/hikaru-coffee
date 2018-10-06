class File
  constructor: (docDir, srcDir, srcPath) ->
    @docDir = docDir
    @docPath = null
    @srcDir = srcDir
    @srcPath = srcPath
    @raw = null
    @text = null
    @content = null
    @type = null
    @frontMatter = null
    @categories = null
    @tags = null
    @excerpt = null
    @more = null

module.exports = File

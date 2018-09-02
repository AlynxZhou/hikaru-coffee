"use strict"

fse = require("fs-extra")
fm = require("front-matter")
path = require("path")
glob = require("glob")

module.exports =
class Router
  constructor: (logger, renderer, generator, srcDir, docDir, themeDir) ->
    @logger = logger
    @renderer = renderer
    @generator = generator
    @srcDir = srcDir
    @docDir = docDir
    @themeDir = themeDir
    @store = {}
    @templates = {}
    @pages = []
    @posts = []
    @themeAssets = []
    @srcAssets = []

  route: () =>
    @loadThemeAssets().then(() =>
      return @renderThemeAssets()
    ).then(() =>
      for data in @themeAssets then do (data) =>
        @logger.debug("Hikaru is saving `#{data["docPath"]}`...")
        if data["content"]?
          fse.outputFile(path.join(@docDir, data["docPath"]), data["content"])
        else
          fse.copy(
            path.join(@themeDir, data["srcPath"]),
            path.join(@docDir, data["docPath"])
          )
    )
    Promise.all([@loadTemplates(), @loadSrc()]).then(() =>
      @renderSrcAssets().then(() =>
        for data in @srcAssets then do (data) =>
          @logger.debug("Hikaru is saving `#{data["docPath"]}`...")
          if data["content"]?
            fse.outputFile(path.join(@docDir, data["docPath"]), data["content"])
          else
            fse.copy(
              path.join(@srcDir, data["srcPath"]),
              path.join(@docDir, data["docPath"])
            )
      )
      @renderTemplates().then(() =>
        return @renderPages()
      ).then(() =>
        @posts.sort((a, b) ->
          return -(a["date"] - b["date"])
        )
        for i in [0...@posts.length]
          if i > 0
            @posts[i]["next"] = @posts[i - 1]
          if i < @posts.length - 1
            @posts[i]["prev"] = @posts[i + 1]
        for page in @pages then do (page) =>
          pages = @generator.generate(page, @posts)
          if pages not instanceof Array
            pages = [pages]
          @pages = @pages.concat(pages)
        for page in @pages then do (page) =>
          # @template[layout]["content"] is a function receives ctx,
          # returns HTML.
          layout = page["layout"]
          if layout not of @templates
            layout = "page"
          res = await @templates[layout]["content"](page)
          @logger.debug("Hikaru is saving `#{page["docPath"]}`...")
          fse.outputFile(path.join(@docDir, page["docPath"]), res)
      )
    )

  # fn: param text, fullPath, ctx, return Promise
  register: (srcExt, docExt, fn) =>
    if docExt instanceof Function
      fn = docExt
      @renderer.register(srcExt, fn)
      return
    @renderer.register(srcExt, fn)
    @store[srcExt] = docExt

  matchFiles: (pattern, options) ->
    return new Promise((resolve, reject) ->
      glob(pattern, options, (err, res) ->
        if err
          return reject(err)
        return resolve(res)
      )
    )

  getDocPath: (data) =>
    srcExt = path.extname(data["srcPath"])
    if srcExt of @store
      dirname = path.dirname(data["srcPath"])
      basename = path.basename(data["srcPath"], srcExt)
      docExt = @store[srcExt]
      return path.join(dirname, "#{basename}#{docExt}")
    return data["srcPath"]

  loadTemplates: () =>
    templateFiles = await @matchFiles("*.*", {"cwd": @themeDir})
    promiseQueue = []
    for filePath in templateFiles then do (filePath) =>
      @logger.debug("Hikaru is loading `#{filePath}`...")
      promiseQueue.push(
        fse.readFile(path.join(@themeDir, filePath), "utf8").then((raw) =>
          data = {
            "srcPath": filePath,
            "text": raw,
            "raw": raw
          }
          data["docPath"] = @getDocPath(data)
          @templates[path.basename(filePath, path.extname(filePath))] = data
        )
      )
    return Promise.all(promiseQueue)

  renderTemplates: () =>
    promiseQueue = []
    for key, data of @templates then do (data) =>
      @logger.debug("Hikaru is rendering `#{data["srcPath"]}`...")
      promiseQueue.push(data["content"] = @renderer.render(data["text"]
      path.join(@themeDir, data["srcPath"])))
    # Wait for all templates renderer finished.
    return Promise.all(promiseQueue)

  loadThemeAssets: () =>
    themeAssetFiles = await @matchFiles(path.join("**", "*.*"),
    {"cwd": @themeDir})
    promiseQueue = []
    for filePath in themeAssetFiles then do (filePath) =>
      # Skip templates.
      if path.dirname(filePath) is '.'
        return
      @logger.debug("Hikaru is loading `#{filePath}`...")
      promiseQueue.push(
        fse.readFile(path.join(@themeDir, filePath), "utf8").then((raw) =>
          data = {
            "srcPath": filePath,
            "text": raw,
            "raw": raw
          }
          data["docPath"] = @getDocPath(data)
          @themeAssets.push(data)
        )
      )
    return Promise.all(promiseQueue)

  renderThemeAssets: () =>
    promiseQueue = []
    for data in @themeAssets then do (data) =>
      @logger.debug("Hikaru is rendering `#{data["srcPath"]}`...")
      promiseQueue.push(data["content"] = @renderer.render(data["text"],
      path.join(@themeDir, data["srcPath"])))
    return Promise.all(promiseQueue)

  loadSrc: () =>
    srcFiles = await @matchFiles(path.join("**", "*.*"), {"cwd": @srcDir})
    promiseQueue = []
    for filePath in srcFiles then do (filePath) =>
      @logger.debug("Hikaru is loading `#{filePath}`...")
      promiseQueue.push(
        fse.readFile(path.join(@srcDir, filePath), "utf8").then((raw) =>
          data = {
            "srcPath": filePath,
            "raw": raw
          }
          data["docPath"] = @getDocPath(data)
          if typeof(raw) is "string"
            parsed = fm(raw)
            data["text"] = parsed["body"]
            if parsed["frontmatter"]?
              data = Object.assign(data, parsed["attributes"])
          if data["date"]?
            data["date"] = new Date(data["date"])
          if data["text"] isnt data["raw"]?
            @pages.push(data)
            if data["layout"] is "post"
              @posts.push(data)
          else
            @srcAssets.push(data)
        )
      )
    return Promise.all(promiseQueue)

  renderPages: () =>
    promiseQueue = []
    for data in @pages then do (data) =>
      @logger.debug("Hikaru is rendering `#{data["srcPath"]}`...")
      promiseQueue.push(data["content"] = @renderer.render(data["text"],
      path.join(@themeDir, data["srcPath"])))
    return Promise.all(promiseQueue)

  renderSrcAssets: () =>
    promiseQueue = []
    for data in @srcAssets then do (data) =>
      @logger.debug("Hikaru is rendering `#{data["srcPath"]}`...")
      promiseQueue.push(data["content"] = @renderer.render(data["text"],
      path.join(@themeDir, data["srcPath"])))
    return Promise.all(promiseQueue)

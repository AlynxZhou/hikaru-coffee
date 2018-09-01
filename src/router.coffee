"use strict"
fse = require("fs-extra")
fm = require("front-matter")
path = require("path")
glob = require("glob")
module.exports =
class Router
  constructor: (logger, renderer, srcDir, docDir, themeDir) ->
    @logger = logger
    @renderer = renderer
    @srcDir = srcDir
    @docDir = docDir
    @themeDir = themeDir
    @extPairs = {}
    @templates = {}
    @pages = []
    # [Post, Post, Post...]
    @archives = []
    ###
    [
      {
        "name"：String,
        "posts": [Post],
        "subs": [
          {
            "name": String,
            "posts": [Post],
            "subs": []
          }
        ]
      }
    ]
    ###
    @categories = []
    ###
    [
      {
        "name": String,
        "posts": [Post]
      }
    ]
    ###
    @tags = []
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
        @genSiteInfo()
        for data in @pages then do (data) =>
          # @template[layout]["content"] is a function receives ctx,
          # returns HTML.
          layout = data["layout"]
          # For currently debug.
          if layout is "archives"
            data["content"] = JSON.stringify(@archives, null, "  ")
          else if layout is "categories"
            data["content"] = JSON.stringify(@categories, null, "  ")
          else if layout is "tags"
            data["content"] = JSON.stringify(@tags, null, "  ")
          if layout not of @templates
            layout = "page"
          @templates[layout]["content"]({
            "page": {
              "title": data["title"]
              "content": data["content"],
            }
          }).then((res) =>
            data["content"] = res
            @logger.debug("Hikaru is saving `#{data["docPath"]}`...")
            fse.outputFile(path.join(@docDir, data["docPath"]),
            data["content"])
          )
      )
    )

  # fn: param text, fullPath, ctx, return Promise
  register: (srcExt, docExt, fn) =>
    if docExt instanceof Function
      fn = docExt
      @renderer.register(srcExt, fn)
      return
    @renderer.register(srcExt, fn)
    @extPairs[srcExt] = docExt

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
    if srcExt of @extPairs
      dirname = path.dirname(data["srcPath"])
      basename = path.basename(data["srcPath"], srcExt)
      docExt = @extPairs[srcExt]
      return path.join(dirname, "#{basename}#{docExt}")
    return data["srcPath"]

  genSiteInfo: () =>
    for data in @pages
      if data["layout"] is "post"
        @archives.push(data)
        if data["categories"]?
          subCategories = @categories
          for cateName in data["categories"]
            for category in subCategories
              if category["name"] is cateName
                category["posts"].push(data)
                subCategories = category["subs"]
                break
            newCate = {"name": cateName, "posts": [data], "subs": []}
            subCategories.push(newCate)
            subCategories = newCate["subs"]
        if data["tags"]?
          for tagName in data["tags"]
            for tag in @tags
              if tag["name"] is tagName
                tag["posts"].push(data)
                break
            @tags.push({"name": tagName, "posts": [data]})
    @archives.sort((a, b) ->
      return -(a["date"] - b["date"])
    )
    sortCategories = (category) ->
      category["posts"].sort((a, b) ->
        return -(a["date"] - b["date"])
      )
      category["subs"].sort((a, b) ->
        return a["name"].localeCompare(b["name"])
      )
      for sub in category["subs"]
        sortCategories(sub)
    @categories.sort((a, b) ->
      return a["name"].localeCompare(b["name"])
    )
    for sub in @categories
      sortCategories(sub)
    @tags.sort((a, b) ->
      return a["name"].localeCompare(b["name"])
    )
    for tag in @tags
      tag["posts"].sort((a, b) ->
        return -(a["date"] - b["date"])
      )

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

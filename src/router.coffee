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
    @templates = {}
    @src = []
    @assets = []

  route: () =>
    return Promise.all([
      @routeAssets()
      @routeTemplates().then(() =>
        @routeSrc()
      )
    ]).then(() =>
      return fse.emptyDir(@docDir)
    ).then(() =>
      promiseQueue = []
      for s in @src
        if s["content"]?
          promiseQueue.push(fse.outputFile(path.join(@docDir,
          s["docPath"]), s["content"]))
        else
          promiseQueue.push(fse.copy(path.join(@srcDir, s["srcPath"]),
          path.join(@docDir, s["docPath"])))
      for s in @assets
        if s["content"]?
          promiseQueue.push(fse.outputFile(path.join(@docDir,
          s["docPath"]), s["content"]))
        else
          promiseQueue.push(fse.copy(path.join(@themeDir, s["srcPath"]),
          path.join(@docDir, s["docPath"])))
      return Promise.all(promiseQueue)
    )

  matchFiles: (pattern, options) ->
    return new Promise((resolve, reject) ->
      glob(pattern, options, (err, res) ->
        if err
          return reject(err)
        return resolve(res)
      )
    )

  routeTemplates: () =>
    templateFiles = await @matchFiles("*.*", {"cwd": @themeDir})
    promiseQueue = []
    for filePath in templateFiles
      raw = await fse.readFile(path.join(@themeDir, filePath), "utf8")
      data = {
        "srcPath": filePath,
        "text": raw,
        "raw": raw
      }
      @templates[path.basename(filePath, path.extname(filePath))] = data
      promiseQueue.push(@renderer.render(data))
    # Wait for all templates renderer finished.
    return Promise.all(promiseQueue)

  routeAssets: () =>
    assetFiles = await @matchFiles(path.join("**", "*.*"), {"cwd": @themeDir})
    promiseQueue = []
    for filePath in assetFiles
      # Skip templates.
      if path.dirname(filePath) is '.'
        continue
      raw = await fse.readFile(path.join(@themeDir, filePath), "utf8")
      data = {
        "srcPath": filePath,
        "text": raw,
        "raw": raw
      }
      @assets.push(data)
      promiseQueue.push(@renderer.render(data))
    # Wait for all templates renderer finished.
    return Promise.all(promiseQueue)

  routeSrc: () =>
    # TODO: Metadata garthering. Tags Archives Categroies and helpers.
    srcFiles = await @matchFiles(path.join("**", "*.*"), {"cwd": @srcDir})
    promiseQueue = []
    for filePath in srcFiles
      raw = await fse.readFile(path.join(@srcDir, filePath), "utf8")
      data = {
        "srcPath": filePath,
        "raw": raw
      }
      if typeof(raw) is "string"
        parsed = fm(raw)
        data["text"] = parsed["body"]
        data["frontMatter"] = parsed["attributes"]
      @src.push(data)
      promiseQueue.push(@renderer.render(data, {
        "layout": @templates[data["frontMatter"]?["layout"] or
        "layout"]["content"]
      }))
    # Wait for all templates renderer finished.
    return Promise.all(promiseQueue)

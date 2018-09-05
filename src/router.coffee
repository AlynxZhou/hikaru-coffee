fse = require("fs-extra")
fm = require("front-matter")
path = require("path")
glob = require("glob")
moment = require("moment")
{dateStrCompare} = require("./utils")

module.exports =
class Router
  constructor: (logger, renderer, generator, translator,
  srcDir, docDir, themeSrcDir, siteConfig, themeConfig) ->
    @logger = logger
    @renderer = renderer
    @generator = generator
    @translator = translator
    @srcDir = srcDir
    @docDir = docDir
    @themeSrcDir = themeSrcDir
    @store = []
    @site = {
      "siteConfig": siteConfig,
      "themeConfig": themeConfig,
      "templates": {},
      "pages": [],
      "posts": [],
      "data": []
    }

  # fn: param site, change site.
  register: (fn) =>
    if fn instanceof Function
      @store.push(fn)

  matchFiles: (pattern, options) ->
    return new Promise((resolve, reject) ->
      glob(pattern, options, (err, res) ->
        if err
          return reject(err)
        return resolve(res)
      )
    )

  readData: (srcDir, srcPath) =>
    @logger.debug("Hikaru is loading `#{srcPath}`...")
    return fse.readFile(path.join(srcDir, srcPath), "utf8").then((raw) ->
      return {
        "srcPath": srcPath,
        "text": raw,
        "raw": raw
      }
    )

  writeData: (srcDir, data) =>
    @logger.debug("Hikaru is saving `#{data["docPath"]}`...")
    if data["content"]?
      return fse.outputFile(path.join(@docDir, data["docPath"]),
      data["content"])
    return fse.copy(
      path.join(srcDir, data["srcPath"]),
      path.join(@docDir, data["docPath"])
    )

  routeThemeAssets: () =>
    @matchFiles(path.join("**", "*"), {
      "nodir": true,
      "dot": true,
      "cwd": @themeSrcDir
    }).then((themeSrcs) =>
      themeSrcs.filter((srcPath) ->
        # Asset is in sub dir.
        return path.dirname(srcPath) isnt "."
      ).map((srcPath) =>
        return @readData(@themeSrcDir, srcPath).then((data) =>
          return @renderer.render(data, null)
        ).then((data) =>
          return @writeData(@themeSrcDir, data)
        )
      )
    )

  routeTemplates: () =>
    return @matchFiles("*", {
      "nodir": true,
      "dot": true,
      "cwd": @themeSrcDir
    }).then((templates) =>
      return Promise.all(templates.map((srcPath) =>
        return @readData(@themeSrcDir, srcPath).then((data) =>
          @site["templates"][path.basename(srcPath,
          path.extname(srcPath))] = @renderer.render(data, null)
        )
      ))
    )

  routeSrcs: () =>
    return @matchFiles(path.join("**", "*"), {
      "nodir": true,
      "dot": true,
      "cwd": @srcDir
    }).then((srcs) =>
      renderedPromises = []
      for srcPath in srcs then do (srcPath) =>
        renderedPromises.push(@readData(@srcDir, srcPath).then((data) =>
          if typeof(data["raw"]) is "string"
            parsed = fm(data["raw"])
            data["text"] = parsed["body"]
            data = Object.assign({}, data, parsed["attributes"])
            if data["text"] isnt data["raw"]
              if data["title"]?
                data["title"] = data["title"].toString()
              return @renderer.render(data, null)
          @renderer.render(data, null).then((data) =>
            @writeData(@srcDir, data)
          )
          return null
        ))
      return Promise.all(renderedPromises)
    )

  route: () =>
    @routeThemeAssets()
    @routeTemplates().then(() =>
      return @routeSrcs()
    ).then((renderedPages) =>
      for p in renderedPages
        if not p?
          continue
        if p["layout"] is "post"
          @site["posts"].push(p)
        else
          @site["pages"].push(p)
      # Posts.
      @site["posts"].sort(dateStrCompare)
      # Custum route.
      for fn in @store
        @site = fn(@site)
      generatedPosts = []
      for post in @site["posts"]
        p = @generator.generate(post, null, {
          "site": @site,
          "siteConfig": @site["siteConfig"],
          "themeConfig": @site["themeConfig"],
          "moment": moment,
          "pathPx": path.posix,
          "encodeURI": encodeURI,
          "encodeURIComponent": encodeURIComponent,
          "__": @translator.__,
          "_p": @translator._p
        })
        if p not instanceof Array
          generatedPosts.push(p)
        else
          generatedPosts = generatedPosts.concat(p)
      @site["posts"] = generatedPosts
      for i in [0...@site["posts"].length]
        if i > 0
          @site["posts"][i]["next"] = @site["posts"][i - 1]
        if i < @site["posts"].length - 1
          @site["posts"][i]["prev"] = @site["posts"][i + 1]
      # Pages.
      generatedPages = []
      for page in @site["pages"]
        if page["layout"] not of @site["templates"]
          page["layout"] = "page"
        p = @generator.generate(page, @site["posts"], {
          "site", @site,
          "siteConfig": @site["siteConfig"],
          "themeConfig": @site["themeConfig"],
          "moment": moment,
          "pathPx": path.posix,
          "encodeURI": encodeURI,
          "encodeURIComponent": encodeURIComponent,
          "__": @translator.__,
          "_p": @translator._p
        })
        if p not instanceof Array
          generatedPages.push(p)
        else
          generatedPages = generatedPages.concat(p)
      @site["pages"] = generatedPages
      for data in @site["data"]
        @writeData(@srcDir, data)
      for page in @site["pages"]
        page["content"] = await @site["templates"][page["layout"]](page)
        @writeData(@srcDir, page)
      # Merge post and template last.
      for post in @site["posts"]
        post["content"] = await @site["templates"][post["layout"]](post)
        @writeData(@srcDir, post)
    )

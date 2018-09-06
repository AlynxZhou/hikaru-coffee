path = require("path")
fm = require("front-matter")
fse = require("fs-extra")
yaml = require("js-yaml")
glob = require("glob")
moment = require("moment")

Translator = require("./translator")
{
  dateStrCompare,
  getAbsPathFn,
  getURLFn,
  isCurrentPathFn
} = require("./utils")

module.exports =
class Router
  constructor: (logger, renderer, generator, translator, site) ->
    @logger = logger
    @renderer = renderer
    @generator = generator
    @translator = translator
    @site = site
    @store = {
      "beforeGenerating": [],
      "afterGenerating": []
    }

  # fn: param site, change site.
  register: (type, fn) =>
    if type not of @store
      return
    if fn instanceof Function
      @store[type].push(fn)

  matchFiles: (pattern, options) ->
    return new Promise((resolve, reject) ->
      glob(pattern, options, (err, res) ->
        if err
          return reject(err)
        return resolve(res)
      )
    )

  readData: (srcDir, srcPath) =>
    @logger.debug("Hikaru is reading `#{path.join(srcDir, srcPath)}`...")
    return fse.readFile(path.join(srcDir, srcPath), "utf8").then((raw) ->
      return {
        "srcPath": srcPath,
        "text": raw,
        "raw": raw
      }
    )

  writeData: (srcDir, data) =>
    @logger.debug("Hikaru is writing `#{path.join(
      @site["docDir"], data["docPath"]
    )}`...")
    if data["content"]?
      return fse.outputFile(
        path.join(@site["docDir"], data["docPath"]), data["content"]
      )
    return fse.copy(
      path.join(srcDir, data["srcPath"]),
      path.join(@site["docDir"], data["docPath"])
    )

  routeThemeAssets: () =>
    @matchFiles(path.join("**", "*"), {
      "nodir": true,
      "dot": true,
      "cwd": @site["themeSrcDir"]
    }).then((themeSrcs) =>
      themeSrcs.filter((srcPath) ->
        # Asset is in sub dir.
        return path.dirname(srcPath) isnt "."
      ).map((srcPath) =>
        return @readData(@site["themeSrcDir"], srcPath).then((data) =>
          return @renderer.render(data, null)
        ).then((data) =>
          return @writeData(@site["themeSrcDir"], data)
        )
      )
    )

  routeTemplates: () =>
    return @matchFiles("*", {
      "nodir": true,
      "dot": true,
      "cwd": @site["themeSrcDir"]
    }).then((templates) =>
      return Promise.all(templates.map((srcPath) =>
        return @readData(@site["themeSrcDir"], srcPath).then((data) =>
          @site["templates"][path.basename(
            srcPath, path.extname(srcPath)
          )] = @renderer.render(data, null)
        )
      ))
    )

  routeSrcs: () =>
    return @matchFiles(path.join("**", "*"), {
      "nodir": true,
      "dot": true,
      "cwd": @site["srcDir"]
    }).then((srcs) =>
      renderedPromises = []
      for srcPath in srcs then do (srcPath) =>
        renderedPromises.push(@readData(
          @site["srcDir"], srcPath
        ).then((data) =>
          if typeof(data["raw"]) is "string"
            parsed = fm(data["raw"])
            data["text"] = parsed["body"]
            data = Object.assign(data, parsed["attributes"])
            if data["text"] isnt data["raw"]
              if data["title"]?
                data["title"] = data["title"].toString()
              return @renderer.render(data, null)
          @renderer.render(data, null).then((data) =>
            @writeData(@site["srcDir"], data)
          )
          return null
        ))
      return Promise.all(renderedPromises)
    )

  generateAll: (ps) ->
    generated = []
    for p in ps
      lang = p["language"] or @site["siteConfig"]["language"]
      if lang not of @translator.list()
        try
          language = yaml.safeLoad(fse.readFileSync(path.join(
            @site["themeDir"],
            "languages",
            "#{lang}.yml"
          )))
          @translator.register(lang, language)
        catch err
          null
      p = @generator.generate(p, @site["posts"], {
        "site": @site,
        "siteConfig": @site["siteConfig"],
        "themeConfig": @site["themeConfig"],
        "moment": moment,
        "getURL": getURLFn(
          @site["siteConfig"]["baseURL"], @site["siteConfig"]["rootDir"]
        ),
        "getAbsPath": getAbsPathFn(@site["siteConfig"]["rootDir"]),
        "isCurrentPath": isCurrentPathFn(
          @site["siteConfig"]["rootDir"], p["docPath"]
        ),
        "__": @translator.getTranslateFn(lang)
      })
      if p not instanceof Array
        generated.push(p)
      else
        generated = generated.concat(p)
    return generated

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
          if p["layout"] not of @site["templates"]
            p["layout"] = "page"
          @site["pages"].push(p)
      # Posts.
      @site["posts"].sort(dateStrCompare)
      # Custum route.
      for fn in @store["beforeGenerating"]
        @site = fn(@site)
      @site["posts"] = @generateAll(@site["posts"])
      for i in [0...@site["posts"].length]
        if i > 0
          @site["posts"][i]["next"] = @site["posts"][i - 1]
        if i < @site["posts"].length - 1
          @site["posts"][i]["prev"] = @site["posts"][i + 1]
      # Pages.
      @site["pages"] = @generateAll(@site["pages"])
      for fn in @store["afterGenerating"]
        @site = fn(@site)
      for page in @site["pages"]
        page["content"] = await @site["templates"][page["layout"]](page)
        @writeData(@site["srcDir"], page)
      # Merge post and template last.
      for post in @site["posts"]
        post["content"] = await @site["templates"][post["layout"]](post)
        @writeData(@site["srcDir"], post)
      for data in @site["data"]
        @writeData(@site["srcDir"], data)
    )

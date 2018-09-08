path = require("path")
fm = require("front-matter")
fse = require("fs-extra")
yaml = require("js-yaml")
glob = require("glob")
colors = require("colors/safe")
moment = require("moment")

{
  getAbsPathFn,
  getUrlFn,
  isCurrentPathFn
} = require("./utils")

module.exports =
class Router
  constructor: (logger, renderer, processer, generator, translator, site) ->
    @logger = logger
    @renderer = renderer
    @processer = processer
    @generator = generator
    @translator = translator
    @site = site
    @getUrl = getUrlFn(
      @site["siteConfig"]["baseUrl"], @site["siteConfig"]["rootDir"]
    )
    @getAbsPath = getAbsPathFn(@site["siteConfig"]["rootDir"])

  matchFiles: (pattern, options) ->
    return new Promise((resolve, reject) ->
      glob(pattern, options, (err, res) ->
        if err
          return reject(err)
        return resolve(res)
      )
    )

  readData: (srcDir, srcPath) =>
    @logger.debug("Hikaru is reading `#{colors.cyan(
      path.join(srcDir, srcPath)
    )}`...")
    return fse.readFile(path.join(srcDir, srcPath), "utf8").then((raw) ->
      return {
        "srcPath": srcPath,
        "srcDir": srcDir,
        "text": raw,
        "raw": raw
      }
    )

  writeData: (srcDir, data) =>
    @logger.debug("Hikaru is writing `#{colors.cyan(
      path.join(@site["docDir"], data["docPath"])
    )}`...")
    if data["content"]?
      return fse.outputFile(
        path.join(@site["docDir"], data["docPath"]), data["content"]
      )
    return fse.copy(
      path.join(srcDir, data["srcPath"]),
      path.join(@site["docDir"], data["docPath"])
    )

  loadThemeAssets: () =>
    @matchFiles(path.join("**", "*"), {
      "nodir": true,
      "dot": true,
      "cwd": @site["themeSrcDir"]
    }).then((themeSrcs) =>
      return Promise.all(themeSrcs.filter((srcPath) ->
        # Asset is in sub dir.
        return path.dirname(srcPath) isnt "."
      ).map((srcPath) =>
        return @readData(@site["themeSrcDir"], srcPath).then((data) =>
          @site["assets"].push(data)
        )
      ))
    )

  loadTemplates: () =>
    return @matchFiles("*", {
      "nodir": true,
      "dot": true,
      "cwd": @site["themeSrcDir"]
    }).then((templates) =>
      return Promise.all(templates.map((srcPath) =>
        return @readData(@site["themeSrcDir"], srcPath).then((data) =>
          data["key"] = path.basename(
            srcPath, path.extname(srcPath)
          )
          @site["templates"][data["key"]] = data
        )
      ))
    )

  loadSrcs: () =>
    return @matchFiles(path.join("**", "*"), {
      "nodir": true,
      "dot": true,
      "cwd": @site["srcDir"]
    }).then((srcs) =>
      return Promise.all(srcs.map((srcPath) =>
        @readData(@site["srcDir"], srcPath).then((data) =>
          if typeof(data["raw"]) is "string"
            parsed = fm(data["raw"])
            data["text"] = parsed["body"]
            data = Object.assign(data, parsed["attributes"])
            if data["date"]?
              # Fix js-yaml's bug that ignore timezone while parsing.
              # https://github.com/nodeca/js-yaml/issues/91
              data["date"] = new Date(
                data["date"].getTime() +
                data["date"].getTimezoneOffset() * 60000
              )
            else
              data["date"] = new Date()
            if data["text"] isnt data["raw"]
              if data["title"]?
                data["title"] = data["title"].toString()
              if data["layout"] is "post"
                @site["posts"].push(data)
              else
                # Need load templates first.
                if data["layout"] not of @site["templates"]
                  data["layout"] = "page"
                @site["pages"].push(data)
            else
              @site["assets"].push(data)
        )
      ))
    )

  renderAssets: () =>
    return Promise.all(@site["assets"].map((asset) =>
      @renderer.render(asset)
    ))

  renderTemplates: () =>
    return Promise.all(Object.values(@site["templates"]).map((template) =>
      @renderer.render(template)
    ))

  renderPosts: () =>
    return Promise.all(@site["posts"].map((post) =>
      @renderer.render(post)
    ))

  renderPages: () =>
    return Promise.all(@site["pages"].map((page) =>
      @renderer.render(page)
    ))

  processP: (p) =>
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
        if err["code"] is "ENOENT"
          @logger.info(
            "Hikaru cannot find `#{lang}` language file in your theme."
          )
    ps = await @processer.process(p, @site["posts"], @site["templates"], {
      "site": @site,
      "siteConfig": @site["siteConfig"],
      "themeConfig": @site["themeConfig"],
      "moment": moment,
      "getUrl": @getUrl,
      "getAbsPath": @getAbsPath,
      "isCurrentPath": isCurrentPathFn(
        @site["siteConfig"]["rootDir"], p["docPath"]
      ),
      "__": @translator.getTranslateFn(lang)
    })
    if ps not instanceof Array
      return [ps]
    return ps

  processPosts: () =>
    @site["posts"].sort((a, b) ->
      return -(a["date"] - b["date"])
    )
    processed = []
    for p in @site["posts"]
      p = await @processP(p)
      processed = processed.concat(p)
    @site["posts"] = processed
    for i in [0...@site["posts"].length]
      if i > 0
        @site["posts"][i]["next"] = @site["posts"][i - 1]
      if i < @site["posts"].length - 1
        @site["posts"][i]["prev"] = @site["posts"][i + 1]

  processPages: () =>
    processed = []
    for p in @site["pages"]
      p = await @processP(p)
      processed = processed.concat(p)
    @site["pages"] = processed

  saveAssets: () =>
    return @site["assets"].map((asset) =>
      @writeData(asset["srcDir"], asset)
      return asset
    )

  savePosts: () =>
    return @site["posts"].map((post) =>
      @writeData(post["srcDir"], post)
      return post
    )

  savePages: () =>
    return @site["pages"].map((page) =>
      @writeData(page["srcDir"], page)
      return page
    )

  saveData: () =>
    return @site["data"].map((data) =>
      @writeData(null, data)
      return data
    )

  route: () =>
    return Promise.all([
      @loadThemeAssets(),
      @loadTemplates().then(() =>
        return @loadSrcs()
    )]).then(() =>
      @renderAssets().then(() =>
        return @saveAssets()
      ).catch((err) =>
        @logger.info("Hikaru catched some error during generating!")
        @logger.error(err)
        @logger.info("Hikaru advise you to check generating files!")
      )
      return Promise.all([
        @renderTemplates(),
        @renderPages(),
        @renderPosts()
      ])
    ).then(() =>
      @site = await @generator.generate("beforeProcessing", @site)
      # processPages() needs to wait for processed posts.
      await @processPosts()
      await @processPages()
      # Render post template needs tag and category links,
      # but those links are only generated after processing pages.
      # Maybe change tags and categories routes to a fix path in future.
      @site["posts"] = await Promise.all(@site["posts"].map((p) =>
        p["content"] = await @site["templates"][p["layout"]]["content"](p)
        return p
      ))
      @site["pages"] = await Promise.all(@site["pages"].map((p) =>
        p["content"] = await @site["templates"][p["layout"]]["content"](p)
        return p
      ))
      @site = await @generator.generate("afterProcessing", @site)
      @savePosts()
      @savePages()
      @saveData()
    ).catch((err) =>
      @logger.info("Hikaru catched some error during generating!")
      @logger.error(err)
      @logger.info("Hikaru advise you to check generating files!")
    )

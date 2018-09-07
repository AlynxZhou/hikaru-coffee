path = require("path")
fm = require("front-matter")
fse = require("fs-extra")
yaml = require("js-yaml")
glob = require("glob")
moment = require("moment")

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
    @getURL = getURLFn(
      @site["siteConfig"]["baseURL"], @site["siteConfig"]["rootDir"]
    )
    @getAbsPath = getAbsPathFn(@site["siteConfig"]["rootDir"])

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
        "srcDir": srcDir,
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

  generateData: (p) =>
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
      "getURL": @getURL,
      "getAbsPath": @getAbsPath,
      "isCurrentPath": isCurrentPathFn(
        @site["siteConfig"]["rootDir"], p["docPath"]
      ),
      "__": @translator.getTranslateFn(lang)
    })
    if p not instanceof Array
      return [p]
    return p

  generatePosts: () =>
    @site["posts"].sort(dateStrCompare)
    generated = []
    for p in @site["posts"]
      p = @generateData(p)
      generated = generated.concat(p)
    @site["posts"] = generated
    for i in [0...@site["posts"].length]
      if i > 0
        @site["posts"][i]["next"] = @site["posts"][i - 1]
      if i < @site["posts"].length - 1
        @site["posts"][i]["prev"] = @site["posts"][i + 1]

  generatePages: () =>
    generated = []
    for p in @site["pages"]
      p = @generateData(p)
      generated = generated.concat(p)
    @site["pages"] = generated

  saveAssets: () =>
    return @site["assets"].map((asset) =>
      @writeData(asset["srcDir"], asset)
      return asset
    )

  savePosts: () =>
    return @site["posts"].map((post) =>
      @site["templates"][post["layout"]]["content"](post).then((content) =>
        post["content"] = content
        return @writeData(@site["srcDir"], post)
      )
      return post
    )

  savePages: () =>
    return @site["pages"].map((page) =>
      @site["templates"][page["layout"]]["content"](page).then((content) =>
        page["content"] = content
        return @writeData(@site["srcDir"], page)
      )
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
        @loadSrcs()
    )]).then(() =>
      @renderAssets().then(() =>
        @saveAssets()
      )
      return Promise.all([
        @renderTemplates(),
        @renderPages(),
        @renderPosts()
      ])
    ).then(() =>
      for fn in @store["beforeGenerating"]
        @site = fn(@site)
      @generatePosts()
      @generatePages()
      for fn in @store["afterGenerating"]
        @site = fn(@site)
      @savePosts()
      @savePages()
      @saveData()
    )

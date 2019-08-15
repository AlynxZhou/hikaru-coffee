fse = require("fs-extra")
path = require("path")
{URL} = require("url")
cheerio = require("cheerio")
colors = require("colors/safe")
Promise = require("bluebird")

yaml = require("js-yaml")
nunjucks = require("nunjucks")
marked = require("marked")
stylus = require("stylus")
nib = require("nib")

Logger = require("./logger")
Renderer = require("./renderer")
Processor = require("./processor")
Generator = require("./generator")
Translator = require("./translator")
Router = require("./router")
types = require("./types")
{Site, File, Category, Tag} = types
utils = require("./utils")
{
  escapeHTML,
  matchFiles,
  removeControlChars,
  paginate,
  sortCategories,
  paginateCategories,
  getPathFn,
  getURLFn,
  genCategories,
  genTags,
  resolveHeaderIds,
  resolveLink,
  resolveImage,
  genToc,
  highlight
} = utils

class Hikaru
  constructor: (debug = false) ->
    @debug = debug
    @logger = new Logger(@debug)
    @logger.debug("Hikaru is starting...")
    @types = types
    @utils = utils
    process.on("exit", () =>
      @logger.debug("Hikaru is stopping...")
    )
    if process.platform is "win32"
      require("readline").createInterface({
        "input": process.stdin,
        "output": process.stdout
      }).on("SIGINT", () ->
        process.emit("SIGINT")
      )
    process.on("SIGINT", () ->
      process.exit(0)
    )

  init: (workDir = ".", configPath) =>
    return fse.mkdirp(workDir).then(() =>
      @logger.debug("Hikaru is copying `#{colors.cyan(
        configPath or path.join(workDir, "config.yml")
      )}`...")
      @logger.debug("Hikaru is copying `#{colors.cyan(
        path.join(workDir, "package.json")
      )}`...")
      @logger.debug("Hikaru is creating `#{colors.cyan(
        path.join(workDir, "srcs", path.sep)
      )}`...")
      @logger.debug("Hikaru is creating `#{colors.cyan(
        path.join(workDir, "docs", path.sep)
      )}`...")
      @logger.debug("Hikaru is creating `#{colors.cyan(
        path.join(workDir, "themes", path.sep)
      )}`...")
      @logger.debug("Hikaru is creating `#{colors.cyan(
        path.join(workDir, "scripts", path.sep)
      )}`...")
      fse.copy(
        path.join(__dirname, "..", "dist", "config.yml"),
        configPath or path.join(workDir, "site.config.yml")
      )
      fse.readFile(
        path.join(__dirname, "..", "dist", "package.json")
      ).then((text) ->
        json = JSON.parse(text)
        # Set package name to site dir name.
        json["name"] = path.relative("..", ".")
        return fse.writeFile(
          path.join(workDir, "package.json"),
          JSON.stringify(json, null, "  ")
        )
      )
      fse.mkdirp(path.join(workDir, "srcs"))
      fse.mkdirp(path.join(workDir, "docs"))
      fse.mkdirp(path.join(workDir, "themes"))
      fse.mkdirp(path.join(workDir, "scripts"))
    ).catch((err) =>
      @logger.warn("Hikaru catched some error during initializing!")
      @logger.error(err)
    )

  clean: (workDir = ".", configPath) =>
    configPath = configPath or path.join(workDir, "site.config.yml")
    if not fse.existsSync(configPath)
      configPath = path.join(workDir, "config.yml")
    try
      siteConfig = yaml.safeLoad(fse.readFileSync(configPath, "utf8"))
    catch err
      @logger.warn("Hikaru cannot find site config!")
      @logger.error(err)
      process.exit(-1)
    if not siteConfig?["docDir"]?
      return
    matchFiles("*", {
      "cwd": path.join(workDir, siteConfig["docDir"]), "dot": true
    }).then((res) =>
      return res.map((r) =>
        fse.stat(path.join(workDir, siteConfig["docDir"], r)).then((stats) =>
          if stats.isDirectory()
            @logger.debug("Hikaru is removing `#{colors.cyan(path.join(
              workDir, siteConfig["docDir"], r, path.sep
            ))}`...")
          else
            @logger.debug("Hikaru is removing `#{colors.cyan(path.join(
              workDir, siteConfig["docDir"], r
            ))}`...")
          return fse.remove(path.join(workDir, siteConfig["docDir"], r))
        )
      )
    ).catch((err) =>
      @logger.warn("Hikaru catched some error during cleaning!")
      @logger.error(err)
    )

  build: (workDir = ".", configPath) =>
    @loadSite(workDir, configPath)
    @loadModules()
    @loadPlugins()
    @loadScripts()
    try
      process.on("unhandledRejection", (err) =>
        @logger.warn("Hikaru catched some error during generating!")
        @logger.error(err)
        @logger.warn("Hikaru advise you to check generated files!")
      )
      await @router.build()
    catch err
      @logger.warn("Hikaru catched some error during generating!")
      @logger.error(err)
      @logger.warn("Hikaru advise you to check generated files!")

  serve: (workDir = ".", configPath, ip, port) =>
    @loadSite(workDir, configPath)
    @loadModules()
    @loadPlugins()
    @loadScripts()
    try
      process.on("unhandledRejection", (err) =>
        @logger.warn("Hikaru catched some error during serving!")
        @logger.error(err)
      )
      await @router.serve(ip or "localhost", Number.parseInt(port) or 2333)
    catch err
      @logger.warn("Hikaru catched some error during serving!")
      @logger.error(err)

  loadSite: (workDir, configPath) =>
    @site = new Site(workDir)
    configPath = configPath or path.join(@site["workDir"], "site.config.yml")
    if not fse.existsSync(configPath)
      configPath = path.join(@site["workDir"], "config.yml")
    try
      @site["siteConfig"] = yaml.safeLoad(fse.readFileSync(configPath, "utf8"))
    catch err
      @logger.warn("Hikaru cannot find site config!")
      @logger.error(err)
      process.exit(-1)
    @site["siteConfig"]["srcDir"] = path.join(
      @site["workDir"], @site["siteConfig"]["srcDir"] or "srcs"
    )
    @site["siteConfig"]["docDir"] = path.join(
      @site["workDir"], @site["siteConfig"]["docDir"] or "docs"
    )
    @site["siteConfig"]["themeDir"] = path.join(
      @site["workDir"], "themes", @site["siteConfig"]["themeDir"]
    )
    @site["siteConfig"]["themeSrcDir"] = path.join(
      @site["siteConfig"]["themeDir"], "srcs"
    )
    @site["siteConfig"]["categoryDir"] = @site["siteConfig"]["categoryDir"] or
    "categories"
    @site["siteConfig"]["tagDir"] = @site["siteConfig"]["tagDir"] or "tags"
    themeConfigPath = path.join(@site["workDir"], "theme.config.yml")
    if not fse.existsSync(themeConfigPath)
      themeConfigPath = path.join(
        @site["siteConfig"]["themeDir"], "config.yml"
      )
    try
      @site["themeConfig"] = yaml.safeLoad(
        fse.readFileSync(themeConfigPath, "utf8")
      )
    catch err
      if err["code"] is "ENOENT"
        @logger.warn("Hikaru continues with a empty theme config...")
        @site["themeConfig"] = {}

  loadModules: () =>
    @renderer = new Renderer(@logger, @site["siteConfig"]["skipRender"])
    @processor = new Processor(@logger)
    @generator = new Generator(@logger)
    @translator = new Translator(@logger)
    try
      defaultLanguage = yaml.safeLoad(fse.readFileSync(path.join(
        @site["siteConfig"]["themeDir"], "languages", "default.yml"
      ), "utf8"))
      @translator.register("default", defaultLanguage)
    catch err
      if err["code"] is "ENOENT"
        @logger.warn("Hikaru cannot find default language file in your theme.")
    @router = new Router(
      @logger, @renderer, @processor, @generator, @translator, @site
    )
    try
      @registerInternalRenderers()
      @registerInternalProcessors()
      @registerInternalGenerators()
    catch err
      @logger.warn("Hikaru cannot register internal functions!")
      @logger.error(err)
      process.exit(-2)

  # Load local plugins for site.
  loadPlugins: () =>
    siteJsonPath = path.join(@site["workDir"], "package.json")
    if not fse.existsSync(siteJsonPath)
      return
    modules = JSON.parse(fse.readFileSync(siteJsonPath, "utf8"))["dependencies"]
    if not modules?
      return
    return Object.keys(modules).filter((name) ->
      return /^hikaru-/.test(name)
    ).map((name) =>
      @logger.debug("Hikaru is loading plugin `#{colors.blue(name)}`...")
      return require(require.resolve(name, {
        "paths": [@site["workDir"], ".", __dirname]
      }))(this)
    )

  # Load local scripts for site and theme.
  loadScripts: () =>
    scripts = (await matchFiles(path.join("**", "*.js"), {
      "nodir": true,
      "cwd": path.join(@site["workDir"], "scripts")
    })).map((filename) =>
      return path.join(@site["workDir"], "scripts", filename)
    ).concat((await matchFiles(path.join("**", "*.js"), {
      "nodir": true,
      "cwd": path.join(@site["siteConfig"]["themeDir"], "scripts")
    })).map((filename) =>
      return path.join(@site["siteConfig"]["themeDir"], "scripts", filename)
    ))
    return scripts.map((name) =>
      @logger.debug("Hikaru is loading script `#{
        colors.cyan(path.basename(name))
      }`...")
      return require(require.resolve(name, {
        "paths": [@site["workDir"], ".", __dirname]
      }))(this)
    )

  registerInternalRenderers: () =>
    njkConfig = Object.assign(
      {"autoescape": false, "noCache": true}, @site["siteConfig"]["nunjucks"]
    )
    njkEnv = nunjucks.configure(@site["siteConfig"]["themeSrcDir"], njkConfig)
    njkRenderer = (file) ->
      template = nunjucks.compile(file["text"], njkEnv, file["srcPath"])
      # For template you must give a render function as content.
      file["content"] = (ctx) ->
        return new Promise((resolve, reject) ->
          template.render(ctx, (err, res) ->
            if err?
              return reject(err)
            return resolve(res)
          )
        )
      return file
    @renderer.register(".njk", null, njkRenderer)
    @renderer.register(".j2", null, njkRenderer)

    @renderer.register(".html", ".html", (file) ->
      file["content"] = file["text"]
      return file
    )

    markedConfig = Object.assign({
      "gfm": true,
      "langPrefix": "",
      "highlight": (code, lang) =>
        return highlight(code, Object.assign({
          "lang": lang?.toLowerCase(),
          "hljs": true,
          "gutter": true
        }, @site["siteConfig"]["highlight"]))
    }, @site["siteConfig"]["marked"])
    marked.setOptions(markedConfig)
    @renderer.register(".md", ".html", (file) ->
      file["content"] = marked(file["text"])
      return file
    )

    stylConfig = @site["siteConfig"]["stylus"] or {}
    @renderer.register(".styl", ".css", (file) =>
      return new Promise((resolve, reject) =>
        stylus(file["text"])
        .use(nib())
        .use((style) =>
          style.define("getSiteConfig", (file) =>
            keys = file["val"].toString().split(".")
            res = @site["siteConfig"]
            for k in keys
              if k not of res
                return null
              res = res[k]
            return res
          )
        ).use((style) =>
          style.define("getThemeConfig", (file) =>
            keys = file["val"].toString().split(".")
            res = @site["themeConfig"]
            for k in keys
              if k not of res
                return null
              res = res[k]
            return res
          )
        ).set("filename", path.join(
          @site["siteConfig"]["themeSrcDir"], file["srcPath"]
        )).set("sourcemap", stylConfig["sourcemap"])
        .set("compress", stylConfig["compress"])
        .set("include css", true)
        .render((err, res) ->
          if err?
            return reject(err)
          file["content"] = res
          return resolve(file)
        )
      )
    )

  registerInternalProcessors: () =>
    @processor.register("post sequence", (site) ->
      site["posts"].sort((a, b) ->
        return -(a["createdTime"] - b["createdTime"])
      )
      for i in [0...site["posts"].length]
        if i > 0
          site["posts"][i]["next"] = site["posts"][i - 1]
        if i < site["posts"].length - 1
          site["posts"][i]["prev"] = site["posts"][i + 1]
      return site
    )

    @processor.register("categories collection", (site) ->
      result = genCategories(site["posts"])
      site["categories"] = result["categories"]
      site["categoriesLength"] = result["categoriesLength"]
      return site
    )

    @processor.register("tags collection", (site) ->
      result = genTags(site["posts"])
      site["tags"] = result["tags"]
      site["tagsLength"] = result["tagsLength"]
      return site
    )

    @processor.register("toc and link resolving for pages and posts", (site) ->
      # Preventing cheerio decode `&lt;`.
      # Only work with cheerio version less than or equal to `0.22.0`,
      # which uses `htmlparser2` as its parser.
      all = site["posts"].concat(site["pages"])
      for p in all
        p["$"] = cheerio.load(p["content"], {"decodeEntities": false})
        resolveHeaderIds(p["$"])
        p["toc"] = genToc(p["$"])
        resolveLink(
          p["$"],
          site["siteConfig"]["baseURL"],
          site["siteConfig"]["rootDir"],
          p["docPath"]
        )
        resolveImage(p["$"], site["siteConfig"]["rootDir"], p["docPath"])
        # May change after cheerio switching to `parse5`.
        p["content"] = p["$"].html()
        if p["content"].indexOf("<!--more-->") isnt -1
          split = p["content"].split("<!--more-->")
          p["excerpt"] = split[0]
          p["more"] = split[1]
          p["content"] = split.join("<a id=\"more\"></a>")
      return site
    )

  registerInternalGenerators: () =>
    @generator.register("index pages", (site) ->
      if site["siteConfig"]["perPage"] instanceof Object
        perPage = site["siteConfig"]["perPage"]["index"] or 10
      else
        perPage = site["siteConfig"]["perPage"] or 10
      return paginate(new File({
        "layout": "index",
        "docDir": site["siteConfig"]["docDir"],
        "docPath": path.join(site["siteConfig"]["indexDir"], "index.html"),
        "title": "index",
        "comment": false,
        "reward": false
      }), site["posts"], perPage)
    )

    @generator.register("archives pages", (site) ->
      if site["siteConfig"]["perPage"] instanceof Object
        perPage = site["siteConfig"]["perPage"]["archives"] or 10
      else
        perPage = site["siteConfig"]["perPage"] or 10
      return paginate(new File({
        "layout": "archives",
        "docDir": site["siteConfig"]["docDir"],
        "docPath": path.join(site["siteConfig"]["archiveDir"], "index.html"),
        "title": "archives",
        "comment": false,
        "reward": false
      }), site["posts"], perPage)
    )

    @generator.register("categories pages", (site) ->
      results = []
      if site["siteConfig"]["perPage"] instanceof Object
        perPage = site["siteConfig"]["perPage"]["category"] or 10
      else
        perPage = site["siteConfig"]["perPage"] or 10
      for sub in site["categories"]
        sortCategories(sub)
        for p in paginateCategories(
          sub, site["siteConfig"]["categoryDir"], perPage, site
        )
          results.push(p)
      results.push(new File({
        "layout": "categories",
        "docDir": site["siteConfig"]["docDir"],
        "docPath": path.join(site["siteConfig"]["categoryDir"], "index.html"),
        "title": "categories",
        "comment": false,
        "reward": false
      }))
      return results
    )

    @generator.register("tags pages", (site) ->
      results = []
      if site["siteConfig"]["perPage"] instanceof Object
        perPage = site["siteConfig"]["perPage"]["tag"] or 10
      else
        perPage = site["siteConfig"]["perPage"] or 10
      for tag in site["tags"]
        tag["posts"].sort((a, b) ->
          return -(a["date"] - b["date"])
        )
        sp = new File({
          "layout": "tag",
          "docDir": site["siteConfig"]["docDir"],
          "docPath": path.join(
            site["siteConfig"]["tagDir"], "#{tag["name"]}", "index.html"
          ),
          "title": "tag",
          "name": tag["name"].toString(),
          "comment": false,
          "reward": false
        })
        tag["docPath"] = sp["docPath"]
        for p in paginate(sp, tag["posts"], perPage)
          results.push(p)
      results.push(new File({
        "layout": "tags",
        "docDir": site["siteConfig"]["docDir"],
        "docPath": path.join(site["siteConfig"]["tagDir"], "index.html"),
        "title": "tags",
        "comment": false,
        "reward": false
      }))
      return results
    )

module.exports = Hikaru

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
Processer = require("./processer")
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
        configPath or path.join(workDir, "config.yml")
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
      fse.mkdirp(path.join(workDir, "srcs")).then(() =>
        @logger.debug("Hikaru is copying `#{colors.cyan(path.join(
          workDir, "srcs", "index.md"
        ))}`...")
        @logger.debug("Hikaru is copying `#{colors.cyan(path.join(
          workDir, "srcs", "archives", "index.md"
        ))}`...")
        @logger.debug("Hikaru is copying `#{colors.cyan(path.join(
          workDir, "srcs", "categories", "index.md"
        ))}`...")
        @logger.debug("Hikaru is copying `#{colors.cyan(path.join(
          workDir, "srcs", "tags", "index.md"
        ))}`...")
        fse.copy(
          path.join(__dirname, "..", "dist", "index.md"),
          path.join(workDir, "srcs", "index.md")
        )
        fse.copy(
          path.join(__dirname, "..", "dist", "archives.md"),
          path.join(workDir, "srcs", "archives", "index.md")
        )
        fse.copy(
          path.join(__dirname, "..", "dist", "categories.md"),
          path.join(workDir, "srcs", "categories", "index.md")
        )
        fse.copy(
          path.join(__dirname, "..", "dist", "tags.md"),
          path.join(workDir, "srcs", "tags", "index.md")
        )
      )
      fse.mkdirp(path.join(workDir, "docs"))
      fse.mkdirp(path.join(workDir, "themes"))
      fse.mkdirp(path.join(workDir, "scripts"))
    ).catch((err) =>
      @logger.warn("Hikaru catched some error during initializing!")
      @logger.error(err)
    )

  clean: (workDir = ".", configPath) =>
    configPath = configPath or path.join(workDir, "config.yml")
    siteConfig = yaml.safeLoad(fse.readFileSync(configPath, "utf8"))
    if not siteConfig?["docDir"]?
      return
    matchFiles("*", {
      "cwd": path.join(workDir, siteConfig["docDir"])
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
    configPath = configPath or path.join(@site["workDir"], "config.yml")
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
    try
      @site["themeConfig"] = yaml.safeLoad(
        fse.readFileSync(
          path.join(@site["siteConfig"]["themeDir"], "config.yml")
        )
      )
    catch err
      if err["code"] is "ENOENT"
        @logger.warn("Hikaru continues with a empty theme config...")
        @site["themeConfig"] = {}
    # For old plugins and will be removed.
    @site["srcDir"] = @site["siteConfig"]["srcDir"]
    @site["docDir"] = @site["siteConfig"]["docDir"]
    @site["themeDir"] = @site["siteConfig"]["themeDir"]
    @site["themeSrcDir"] = @site["siteConfig"]["themeSrcDir"]
    @site["categoryDir"] = @site["siteConfig"]["categoryDir"]
    @site["tagDir"] = @site["siteConfig"]["tagDir"]

  loadModules: () =>
    @renderer = new Renderer(@logger, @site["siteConfig"]["skipRender"])
    @processer = new Processer(@logger)
    @generator = new Generator(@logger)
    @translator = new Translator(@logger)
    try
      defaultLanguage = yaml.safeLoad(
        fse.readFileSync(
          path.join(@site["siteConfig"]["themeDir"], "languages", "default.yml")
        )
      )
      @translator.register("default", defaultLanguage)
    catch err
      if err["code"] is "ENOENT"
        @logger.warn("Hikaru cannot find default language file in your theme.")
    @router = new Router(
      @logger, @renderer, @processer, @generator, @translator, @site
    )
    try
      @registerInternalRenderers()
      @registerInternalProcessers()
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
    modules = JSON.parse(await fse.readFile(siteJsonPath))["dependencies"]
    if not modules?
      return
    return Object.keys(modules).filter((name) ->
      return /^hikaru-/.test(name)
    ).map((name) =>
      @logger.debug("Hikaru is loading plugin `#{colors.cyan(name)}`...")
      return require(require.resolve(name, {"paths": [
        @site["workDir"],
        ".",
        __dirname
      ]}))(this)
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
      return require(require.resolve(name, {"paths": [
        @site["workDir"],
        ".",
        __dirname
      ]}))(this)
    )

  registerInternalRenderers: () =>
    njkConfig = Object.assign(
      {"autoescape": false}, @site["siteConfig"]["nunjucks"]
    )
    njkEnv = nunjucks.configure(@site["siteConfig"]["themeSrcDir"], njkConfig)
    @renderer.register([".njk", ".j2"], null, (file, ctx) ->
      template = nunjucks.compile(file["text"], njkEnv, file["srcPath"])
      # For template you must give a async render function as content.
      file["content"] = (ctx) ->
        return new Promise((resolve, reject) ->
          template.render(ctx, (err, res) ->
            if err?
              return reject(err)
            return resolve(res)
          )
        )
      return file
    )

    @renderer.register(".html", ".html", (file, ctx) ->
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
    @renderer.register(".md", ".html", (file, ctx) ->
      file["content"] = marked(file["text"])
      return file
    )

    stylConfig = @site["siteConfig"]["stylus"] or {}
    @renderer.register(".styl", ".css", (file, ctx) =>
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

  registerInternalProcessers: () =>
    @processer.register("index", (p, posts, ctx) =>
      posts.sort((a, b) ->
        return -(a["date"] - b["date"])
      )
      return paginate(
        p, posts, @site["siteConfig"]["perPage"], ctx
      )
    )

    @processer.register("archives", (p, posts, ctx) =>
      posts.sort((a, b) ->
        return -(a["date"] - b["date"])
      )
      return paginate(
        p, posts, @site["siteConfig"]["perPage"], ctx
      )
    )

    @processer.register("categories", (p, posts, ctx) =>
      return Object.assign(new File(), p, ctx, {
        "categories": @site["categories"]
      })
    )

    @processer.register("tags", (p, posts, ctx) =>
      return Object.assign(new File(), p, ctx, {
        "tags": @site["tags"]
      })
    )

    @processer.register(["post", "page"], (p, posts, ctx) =>
      $ = cheerio.load(p["content"])
      resolveHeaderIds($)
      toc = genToc($)
      resolveLink(
        $,
        @site["siteConfig"]["baseURL"],
        @site["siteConfig"]["rootDir"],
        p["docPath"]
      )
      resolveImage($, @site["siteConfig"]["rootDir"], p["docPath"])
      p["content"] = $("body").html()
      if p["content"].indexOf("<!--more-->") isnt -1
        split = p["content"].split("<!--more-->")
        p["excerpt"] = split[0]
        p["more"] = split[1]
        p["content"] = split.join("<a id=\"more\"></a>")
      return Object.assign(
        new File(), p, ctx, {"toc": toc, "$": $}
      )
    )

  registerInternalGenerators: () =>
    @generator.register("beforeProcessing", (site) ->
      # Generate categories
      categories = []
      categoriesLength = 0
      for post in site["posts"]
        if not post["frontMatter"]["categories"]?
          continue
        postCategories = []
        subCategories = categories
        for cateName in post["frontMatter"]["categories"]
          found = false
          for category in subCategories
            if category["name"] is cateName
              found = true
              postCategories.push(category)
              category["posts"].push(post)
              subCategories = category["subs"]
              break
          if not found
            newCate = new Category(cateName, [post], [])
            ++categoriesLength
            postCategories.push(newCate)
            subCategories.push(newCate)
            subCategories = newCate["subs"]
        post["categories"] = postCategories
      categories.sort((a, b) ->
        return a["name"].localeCompare(b["name"])
      )
      for sub in categories
        sortCategories(sub)
        for p in paginateCategories(
          sub,
          site["siteConfig"]["categoryDir"],
          site["siteConfig"]["perPage"],
          site
        )
          site.put("pages", p)
      site["categories"] = categories
      site["categoriesLength"] = categoriesLength
      return site
    )

    @generator.register("beforeProcessing", (site) ->
      # Generate tags.
      tags = []
      tagsLength = 0
      for post in site["posts"]
        if not post["frontMatter"]["tags"]?
          continue
        postTags = []
        for tagName in post["frontMatter"]["tags"]
          found = false
          for tag in tags
            if tag["name"] is tagName
              found = true
              postTags.push(tag)
              tag["posts"].push(post)
              break
          if not found
            newTag = new Tag(tagName, [post])
            ++tagsLength
            postTags.push(newTag)
            tags.push(newTag)
        post["tags"] = postTags
      tags.sort((a, b) ->
        return a["name"].localeCompare(b["name"])
      )
      for tag in tags
        tag["posts"].sort((a, b) ->
          return -(a["date"] - b["date"])
        )
        sp = Object.assign(new File(site["siteConfig"]["docDir"]), {
          "layout": "tag",
          "docPath": path.join(
            site["siteConfig"]["tagDir"], "#{tag["name"]}", "index.html"
          ),
          "title": "tag",
          "name": tag["name"].toString()
        })
        tag["docPath"] = sp["docPath"]
        for p in paginate(
          sp, tag["posts"], site["siteConfig"]["perPage"]
        )
          site.put("pages", p)
      site["tags"] = tags
      site["tagsLength"] = tagsLength
      return site
    )

module.exports = Hikaru

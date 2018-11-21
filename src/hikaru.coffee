fse = require("fs-extra")
path = require("path")
{URL} = require("url")
cheerio = require("cheerio")
moment = require("moment")
colors = require("colors/safe")
Promise = require("bluebird")

yaml = require("js-yaml")
nunjucks = require("nunjucks")
marked = require("marked")
stylus = require("stylus")
nib = require("nib")

Logger = require("./logger")
{Site, File, Category, Tag} = require("./type")
Renderer = require("./renderer")
Processer = require("./processer")
Generator = require("./generator")
Translator = require("./translator")
Router = require("./router")
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
    }).then((err, res) =>
      if err?
        throw err
        return
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
        ).catch((err) =>
          @logger.warn("Hikaru catched some error during cleaning!")
          @logger.error(err)
        )
      )
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
    configPath = configPath or path.join(@site.get("workDir"), "config.yml")
    try
      @site.set(
        "siteConfig", yaml.safeLoad(fse.readFileSync(configPath, "utf8"))
      )
    catch err
      @logger.warn("Hikaru cannot find site config!")
      @logger.error(err)
      process.exit(-1)
    @site.set("srcDir", path.join(
      @site.get("workDir"), @site.get("siteConfig")["srcDir"] or "srcs"
    ))
    @site.set("docDir", path.join(
      @site.get("workDir"), @site.get("siteConfig")["docDir"] or "docs"
    ))
    @site.set("themeDir", path.join(
      @site.get("workDir"), "themes", @site.get("siteConfig")["themeDir"]
    ))
    @site.set("themeSrcDir", path.join(@site.get("themeDir"), "srcs"))
    try
      @site.set("themeConfig", yaml.safeLoad(
        fse.readFileSync(path.join(@site.get("themeDir"), "config.yml"))
      ))
    catch err
      if err["code"] is "ENOENT"
        @logger.warn("Hikaru continues with a empty theme config...")
        @site.set("themeConfig", [])
    @site.set(
      "categoryDir", @site.get("siteConfig")["categoryDir"] or "categories"
    )
    @site.set("tagDir", @site.get("siteConfig")["tagDir"] or "tags")

  loadModules: () =>
    @renderer = new Renderer(@logger, @site.get("siteConfig")["skipRender"])
    @processer = new Processer(@logger)
    @generator = new Generator(@logger)
    @translator = new Translator(@logger)
    try
      defaultLanguage = yaml.safeLoad(
        fse.readFileSync(
          path.join(@site.get("themeDir"), "languages", "default.yml")
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
    siteJsonPath = path.join(@site.get("workDir"), "package.json")
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
        @site.get("workDir"),
        ".",
        __dirname
      ]}))(this)
    )

  # Load local scripts for site and theme.
  loadScripts: () =>
    scripts = (await matchFiles(path.join("**", "*.js"), {
      "nodir": true,
      "cwd": path.join(@site.get("workDir"), "scripts")
    })).map((filename) =>
      return path.join(@site.get("workDir"), "scripts", filename)
    ).concat((await matchFiles(path.join("**", "*.js"), {
      "nodir": true,
      "cwd": path.join(@site.get("themeDir"), "scripts")
    })).map((filename) =>
      return path.join(@site.get("themeDir"), "scripts", filename)
    ))
    return scripts.map((name) =>
      @logger.debug("Hikaru is loading script `#{
        colors.cyan(path.basename(name))
      }`...")
      return require(require.resolve(name, {"paths": [
        @site.get("workDir"),
        ".",
        __dirname
      ]}))(this)
    )

  registerInternalRenderers: () =>
    njkConfig = Object.assign(
      {"autoescape": false}, @site.get("siteConfig")["nunjucks"]
    )
    njkEnv = nunjucks.configure(@site.get("themeSrcDir"), njkConfig)
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
        }, @site.get("siteConfig")["highlight"]))
    }, @site.get("siteConfig")["marked"])
    marked.setOptions(markedConfig)
    @renderer.register(".md", ".html", (file, ctx) ->
      file["content"] = marked(file["text"])
      return file
    )

    stylConfig = @site.get("siteConfig")["stylus"] or {}
    @renderer.register(".styl", ".css", (file, ctx) =>
      return new Promise((resolve, reject) =>
        stylus(file["text"])
        .use(nib())
        .use((style) =>
          style.define("getSiteConfig", (file) =>
            keys = file["val"].toString().split(".")
            res = @site.get("siteConfig")
            for k in keys
              if k not of res
                return null
              res = res[k]
            return res
          )
        ).use((style) =>
          style.define("getThemeConfig", (file) =>
            keys = file["val"].toString().split(".")
            res = @site.get("themeConfig")
            for k in keys
              if k not of res
                return null
              res = res[k]
            return res
          )
        ).set("filename", path.join(@site.get("themeSrcDir"), file["srcPath"]))
        .set("sourcemap", stylConfig["sourcemap"])
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
        p, posts, @site.get("siteConfig")["perPage"], ctx
      )
    )

    @processer.register("archives", (p, posts, ctx) =>
      posts.sort((a, b) ->
        return -(a["date"] - b["date"])
      )
      return paginate(
        p, posts, @site.get("siteConfig")["perPage"], ctx
      )
    )

    @processer.register("categories", (p, posts, ctx) =>
      return Object.assign(new File(), p, ctx, {
        "categories": @site.get("categories")
      })
    )

    @processer.register("tags", (p, posts, ctx) =>
      return Object.assign(new File(), p, ctx, {
        "tags": @site.get("tags")
      })
    )

    @processer.register(["post", "page"], (p, posts, ctx) =>
      $ = cheerio.load(p["content"])
      resolveHeaderIds($)
      toc = genToc($)
      resolveLink(
        $,
        @site.get("siteConfig")["baseURL"],
        @site.get("siteConfig")["rootDir"],
        p["docPath"]
      )
      resolveImage($, @site.get("siteConfig")["rootDir"], p["docPath"])
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
      for post in site.get("posts")
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
          site.get("categoryDir"),
          site.get("siteConfig")["perPage"],
          site
        )
          site.put("pages", p)
      site.set("categories", categories)
      site.set("categoriesLength", categoriesLength)
      return site
    )

    @generator.register("beforeProcessing", (site) ->
      # Generate tags.
      tags = []
      tagsLength = 0
      for post in site.get("posts")
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
        sp = Object.assign(new File(site.get("docDir")), {
          "layout": "tag",
          "docPath": path.join(
            site.get("tagDir"), "#{tag["name"]}", "index.html"
          ),
          "title": "tag",
          "name": tag["name"].toString()
        })
        tag["docPath"] = sp["docPath"]
        for p in paginate(
          sp, tag["posts"], site.get("siteConfig")["perPage"]
        )
          site.put("pages", p)
      site.set("tags", tags)
      site.set("tagsLength", tagsLength)
      return site
    )

    @generator.register("afterProcessing", (site) ->
      if not site.get("siteConfig")["search"]["enable"]
        return site
      # Generate search index.
      search = []
      all = site.get("pages").concat(site.get("posts"))
      getPath = getPathFn(site.get("siteConfig")["rootDir"])
      for p in all
        search.push({
          "title": "#{p["title"]}",
          "url": getPath(p["docPath"]),
          "content": p["text"]
        })
      file = new File(site.get("docDir"))
      file["docPath"] = site.get(
        "siteConfig"
      )["search"]["path"] or "search.json"
      file["content"] = JSON.stringify(search)
      site.put("files", file)
      return site
    )

    @generator.register("afterProcessing", (site) ->
      if not site.get("siteConfig")["sitemap"]["enable"]
        return site
      # Generate sitemap.
      tmpContent = fse.readFileSync(path.join(
        __dirname, "..", "dist", "sitemap.njk"
      ), "utf8")
      content = nunjucks.renderString(tmpContent, {
        "posts": site.get("posts"),
        "getURL": getURLFn(site.get("siteConfig")["baseURL"],
        site.get("siteConfig")["rootDir"]),
        "getPath": getPathFn(site.get("siteConfig")["rootDir"])
      })
      file = new File(site.get("docDir"))
      file["docPath"] = site.get(
        "siteConfig"
      )["sitemap"]["path"] or "sitemap.xml"
      file["content"] = content
      site.put("files", file)
      return site
    )

    @generator.register("afterProcessing", (site) ->
      if not site.get("siteConfig")["feed"]["enable"]
        return resolve(site)
      # Generate RSS feed.
      tmpContent = fse.readFileSync(path.join(
        __dirname, "..", "dist", "atom.njk"
      ), "utf8")
      content = nunjucks.renderString(tmpContent, {
        "siteConfig": site.get("siteConfig"),
        "themeConfig": site.get("themeConfig"),
        "posts": site.get("posts"),
        "removeControlChars": removeControlChars,
        "getURL": getURLFn(site.get("siteConfig")["baseURL"],
        site.get("siteConfig")["rootDir"]),
        "getPath": getPathFn(site.get("siteConfig")["rootDir"])
      })
      file = new File(site.get("docDir"))
      file["docPath"] = site.get("siteConfig")["feed"]["path"] or "atom.xml"
      file["content"] = content
      site.put("files", file)
      return site
    )

module.exports = Hikaru

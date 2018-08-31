"use strict"

fse = require("fs-extra")
path = require("path")

yaml = require("js-yaml")
nunjucks = require("nunjucks")
marked = require("marked")
stylus = require("stylus")
nib = require("nib")
coffee = require("coffeescript")

highlight = require("./highlight")
Logger = require("./logger")
Renderer = require("./renderer")
Router = require("./router")

module.exports =
class Hikaru
  constructor: (debug = false) ->
    @debug = debug
    @logger = new Logger(@debug)
    @logger.info("Hikaru is starting...")
    process.on("exit", () =>
      @logger.info("Hikaru is stopping...")
    )

  init: (workDir = ".", configPath, srcDir, docDir, themeDir) =>
    @logger.info("Hikaru started initialization in `#{workDir}`.")
    return fse.mkdirp(workDir).then(() =>
      @logger.info("Hikaru created `#{workDir}/`.")
      return fse.mkdirp(srcDir or path.join(workDir, "src"))
    ).then(() =>
      @logger.info("Hikaru created `#{srcDir or path.join(workDir, "src")}/`.")
      return fse.copy(path.join(__dirname, "..", "dist", "config.yml"),
      configPath or path.join(workDir, "config.yml"))
    ).then(() =>
      @logger.info("Hikaru copyed `#{configPath or
      path.join(workDir, "config.yml")}`.")
      return fse.mkdirp(docDir or path.join(workDir, "doc"))
    ).then(() =>
      @logger.info("Hikaru created `#{docDir or path.join(workDir, "doc")}/`.")
      return fse.mkdirp(themeDir or path.join(workDir, "themes"))
    ).then(() =>
      @logger.info("Hikaru created `#{themeDir or
      path.join(workDir, "themes")}/`.")
      @logger.info("Hikaru finished initialization in `#{workDir}`.")
    ).catch(@logger.error)

  clean: (workDir = ".", configPath, docDir) =>
    @workDir = workDir
    configPath = configPath or path.join(@workDir, "config.yml")
    @siteConfig = yaml.safeLoad(fse.readFileSync(configPath, "utf8"))
    @docDir = docDir or path.join(@workDir, @siteConfig["docDir"]) or
    path.join(@workDir, "doc")
    fse.emptyDir(@docDir).then(() =>
      @logger.info("Hikaru cleaned `#{@docDir}/`.")
    ).catch(@logger.error)

  generate: (workDir = ".", configPath, srcDir, docDir, themeDir) =>
    @workDir = workDir
    configPath = configPath or path.join(@workDir, "config.yml")
    @siteConfig = yaml.safeLoad(fse.readFileSync(configPath, "utf8"))
    @srcDir = srcDir or path.join(@workDir, @siteConfig["srcDir"]) or
    path.join(@workDir, "src")
    @docDir = docDir or path.join(@workDir, @siteConfig["docDir"]) or
    path.join(@workDir, "doc")
    @themeDir = (if themeDir?
    then path.join(themeDir, "src")
    else path.join(@workDir, @siteConfig["themeDir"], "src") or
    path.join(@workDir, "themes", "aria", "src"))
    try
      @themeConfig = yaml.safeLoad(fse.readFileSync(path.join(@themeDir,
      "config.yml")))
    catch err
      if err["code"] is "ENOENT"
        @logger.info("Hikaru continues with a empty theme config...")
        @themeConfig = {}
    @renderer = new Renderer(@logger)
    @router = new Router(@logger, @renderer, @srcDir, @docDir, @themeDir)
    @registerInternalRoutes()
    @router.route()

  registerInternalRoutes: () =>
    templateDir = @themeDir
    njkConfig = Object.assign({"autoescape": false}, @siteConfig["nunjucks"])
    njkEnv = nunjucks.configure(templateDir, njkConfig)
    @router.register(".njk", (text, fullPath, ctx) ->
      # For template you must give a render function.
      template = nunjucks.compile(text, njkEnv, fullPath)
      njkRender = (ctx) ->
        return new Promise((resolve, reject) ->
          template.render(ctx, (err, res) ->
            if err
              return reject(err)
            return resolve(res)
          )
        )
      return njkRender
    )

    markedConfig = Object.assign({"gfm": true} or @siteConfig["marked"])
    renderer = new marked.Renderer()
    renderer.heading = (text, level) ->
      escaped = text.toLowerCase().replace(/[^\w]+/g, '-')
      return """
        <h#{level}>
          <a class="headerlink" href="##{escaped}" title="##{escaped}"></a>
          #{text}
        </h#{level}>
      """
    marked.setOptions({
      "langPrefix": "",
      "highlight": (code, lang) ->
        return highlight(code, {
          "lang": lang?.toLowerCase(),
          "hljs":  markedConfig["hljs"] or true,
          "gutter": markedConfig["gutter"] or true
        })
    })
    @router.register(".md", ".html", (text, fullPath, ctx) ->
      return marked(
        text, Object.assign({
          "renderer": renderer
        }, markedConfig)
      )
    )

    stylConfig = @siteConfig.stylus or {}
    @router.register(".styl", ".css", (text, fullPath, ctx) ->
      return new Promise((resolve, reject) =>
        stylus(text)
        .use(nib())
        .use((style) =>
          style.define("getSiteConfig", (data) =>
            return @siteConfig[data["val"]]
          )
        ).use((style) =>
          style.define("getThemeConfig", (data) =>
            return @themeConfig[data["val"]]
          )
        ).set("filename", fullPath)
        .set("sourcemap", stylConfig["sourcemap"])
        .set("compress", stylConfig["compress"])
        .set("include css", true)
        .render((err, res) ->
          if err
            return reject(err)
          return resolve(res)
        )
      )
    )
    # TODO: CoffeeScript render.
    @router.register(".coffee", ".js", (text, fullPath, ctx) ->)

fse = require("fs-extra")
path = require("path")
yaml = require("js-yaml")
glob = require("glob")
http = require("http")
{URL} = require("url")
Site = require("./site")
colors = require("colors/safe")
moment = require("moment")
chokidar = require("chokidar")
Promise = require("bluebird")

{
  getPathFn,
  getURLFn,
  getContentType,
  isCurrentPathFn,
  parseFrontMatter
} = require("./utils")

class Router
  constructor: (logger, renderer, processer, generator, translator, site) ->
    @logger = logger
    @renderer = renderer
    @processer = processer
    @generator = generator
    @translator = translator
    @site = site
    @_ = {}
    @srcWatcher = null
    @themeWatcher = null
    @unprocessedSite = new Site(@site["workDir"])
    @getURL = getURLFn(
      @site.get("siteConfig")["baseURL"], @site.get("siteConfig")["rootDir"]
    )
    @getPath = getPathFn(@site.get("siteConfig")["rootDir"])

  matchFiles: (pattern, options) ->
    return new Promise((resolve, reject) ->
      glob(pattern, options, (err, res) ->
        if err
          return reject(err)
        return resolve(res)
      )
    )

  readFile: (file) =>
    @logger.debug("Hikaru is reading `#{colors.cyan(
      path.join(file["srcDir"], file["srcPath"])
    )}`...")
    return fse.readFile(path.join(
      file["srcDir"], file["srcPath"])
    ).then((raw) =>
      # Auto detect if a file is a binary file or a UTF-8 encoding text file.
      if raw.equals(Buffer.from(raw.toString("utf8"), "utf8"))
        raw = raw.toString("utf8")
      return {
        "srcPath": file["srcPath"],
        "srcDir": file["srcDir"],
        "docDir": @site.get("docDir")
        "text": raw,
        "raw": raw
      }
    )

  writeFile: (file) =>
    @logger.debug("Hikaru is writing `#{colors.cyan(
      path.join(@site.get("docDir"), file["docPath"])
    )}`...")
    if file["content"] isnt file["raw"]
      return fse.outputFile(
        path.join(@site.get("docDir"), file["docPath"]), file["content"]
      )
    return fse.copy(
      path.join(file["srcDir"], file["srcPath"]),
      path.join(@site.get("docDir"), file["docPath"])
    )

  loadFile: (file) =>
    file = await @readFile(file)
    if file["srcDir"] is @site.get("themeSrcDir")
      file = await @renderer.render(file)
      if path.dirname(file["srcPath"]) isnt "."
        file["type"] = "asset"
        @site.put("assets", file)
      else
        file["type"] = "template"
        @site.get("templates")[path.basename(
          file["srcPath"], path.extname(file["srcPath"])
        )] = file
    else if file["srcDir"] is @site.get("srcDir")
      file = parseFrontMatter(file)
      file = await @renderer.render(file)
      if file["text"] isnt file["raw"]
        if file["layout"] is "post"
          file["type"] = "post"
          @site.put("posts", file)
        else
          file["layout"] = file["layout"] or "page"
          file["type"] = "page"
          @site.put("pages", file)
      else
        file["type"] = "asset"
        @site.put("assets", file)
    return file

  processP: (p) =>
    lang = p["language"] or @site.get("siteConfig")["language"]
    if lang not of @translator.list()
      try
        language = yaml.safeLoad(fse.readFileSync(path.join(
          @site.get("themeDir"),
          "languages",
          "#{lang}.yml"
        )))
        @translator.register(lang, language)
      catch err
        if err["code"] is "ENOENT"
          @logger.warn(
            "Hikaru cannot find `#{lang}` language file in your theme."
          )
    ps = await @processer.process(p, @site.get("posts"), {
      "site": @site.raw(),
      "siteConfig": @site.get("siteConfig"),
      "themeConfig": @site.get("themeConfig"),
      "moment": moment,
      "getURL": @getURL,
      "getPath": @getPath,
      "isCurrentPath": isCurrentPathFn(
        @site.get("siteConfig")["rootDir"], p["docPath"]
      ),
      "__": @translator.getTranslateFn(lang)
    })
    if ps not instanceof Array
      return [ps]
    return ps

  processPosts: () =>
    @site.get("posts").sort((a, b) ->
      return -(a["date"] - b["date"])
    )
    processed = []
    for p in @site.get("posts")
      p = await @processP(p)
      processed = processed.concat(p)
    @site.set("posts", processed)
    for i in [0...@site.get("posts").length]
      if i > 0
        @site.get("posts")[i]["next"] = @site.get("posts")[i - 1]
      if i < @site.get("posts").length - 1
        @site.get("posts")[i]["prev"] = @site.get("posts")[i + 1]

  processPages: () =>
    for ps in @site.get("pages")
      ps = await @processP(ps)
      for p in ps
        @site.put("pages", p)

  saveAssets: () =>
    return @site.get("assets").map((asset) =>
      @writeFile(asset)
      return asset
    )

  savePosts: () =>
    return @site.get("posts").map((p) =>
      p["content"] = await @site.get("templates")[p["layout"]]["content"](p)
      @writeFile(p)
      return p
    )

  savePages: () =>
    return @site.get("pages").map((p) =>
      if p["layout"] not of @site.get("templates")
        p["layout"] = "page"
      p["content"] = await @site.get("templates")[p["layout"]]["content"](p)
      @writeFile(p)
      return p
    )

  saveFile: () =>
    return @site.get("files").map((file) =>
      @writeFile(file)
      return file
    )

  buildServerRoutes: () =>
    @_ = {}
    for f in @site.get("assets").concat(@site.get("posts"))
    .concat(@site.get("pages")).concat(@site.get("files"))
      key = @getPath(f["docPath"])
      @logger.debug("Hikaru is building route `#{colors.cyan(key)}`...")
      @_[key] = f

  watchTheme: () =>
    @themeWatcher = chokidar.watch(path.join("**", "*"), {
      "cwd": @site.get("themeSrcDir"),
      "ignoreInitial": true
    })
    for event in ["add", "change", "unlink"] then do (event) =>
      @themeWatcher.on(event, (srcPath) =>
        @logger.debug(
          "Hikaru watched event `#{colors.blue(event)}` from `#{
            colors.cyan(path.join(@site.get("themeSrcDir"), srcPath))
          }`"
        )
        @site.set("pages", @unprocessedSite.get("pages"))
        @unprocessedSite.set("pages", @site.get("pages")[0...])
        file = {"srcDir": @site.get("themeSrcDir"), "srcPath": srcPath}
        if event isnt "unlink"
          file = await @loadFile(file)
          if file["type"] is "template"
            for k, v of @site.get("templates")
              @site.get("templates")[k] = await @renderer.render(v)
          else if file["type"] is "asset"
            @site.set("assets", await Promise.all(
              @site.get("assets").map((file) =>
                return @renderer.render(file)
              )
            ))
        else
          for key in ["assets", "templates"]
            if @site.splice(key, file)?
              break
        @site = await @generator.generate("beforeProcessing", @site)
        await @processPosts()
        await @processPages()
        @site = await @generator.generate("afterProcessing", @site)
        @buildServerRoutes()
      )

  watchSrc: () =>
    @srcWatcher = chokidar.watch(path.join("**", "*"), {
      "cwd": @site.get("srcDir"),
      "ignoreInitial": true
    })
    for event in ["add", "change", "unlink"] then do (event) =>
      @srcWatcher.on(event, (srcPath) =>
        @logger.debug(
          "Hikaru watched event `#{colors.blue(event)}` from `#{
            colors.cyan(path.join(@site.get("srcDir"), srcPath))
          }`"
        )
        @site.set("pages", @unprocessedSite.get("pages"))
        @unprocessedSite.set("pages", @site.get("pages")[0...])
        file = {"srcDir": @site.get("srcDir"), "srcPath": srcPath}
        if event isnt "unlink"
          file = await @loadFile(file)
          if file["type"] is "asset"
            @site.set("assets", await Promise.all(
              @site.get("assets").map((file) =>
                return @renderer.render(file)
              )
            ))
        else
          for key in ["assets", "pages", "posts"]
            if @site.splice(key, file)?
              break
        @site = await @generator.generate("beforeProcessing", @site)
        await @processPosts()
        await @processPages()
        @site = await @generator.generate("afterProcessing", @site)
        @buildServerRoutes()
      )

  unwatchAll: () =>
    @themeWatcher.close()
    @themeWatcher = null
    @srcWatcher.close()
    @srcWatcher = null

  listen: (ip, port) =>
    server = http.createServer((request, response) =>
      if request["url"] not of @_
        @logger.log("404: #{request["url"]}")
        res = @_[@getPath("404.html")]
        response.writeHead(404, {
          "Content-Type": getContentType(res["docPath"])
        })
      else
        @logger.log("200: #{request["url"]}")
        res = @_[request["url"]]
        response.writeHead(200, {
          "Content-Type": getContentType(res["docPath"])
        })
      if res["layout"]?
        if res["layout"] not of @site.get("templates")
          res["layout"] = "page"
        response.write(
          await @site.get("templates")[res["layout"]]["content"](res)
        )
      else
        response.write(res["content"])
      response.end()
    )
    process.prependListener("exit", () =>
      server.close()
      @logger.log(
        "Hikaru stopped listening on http://#{ip}:#{port}#{@getPath()}..."
      )
      @unwatchAll()
    )
    @logger.log(
      "Hikaru is listening on http://#{ip}:#{port}#{@getPath()}..."
    )
    if ip isnt "localhost"
      server.listen(port, ip)
    else
      server.listen(port)
    @watchTheme()
    @watchSrc()

  generate: () =>
    allFiles = (await @matchFiles(path.join("**", "*"), {
      "nodir": true,
      "dot": true,
      "cwd": @site.get("themeSrcDir")
    })).map((srcPath) =>
      return {"srcDir": @site.get("themeSrcDir"), "srcPath": srcPath}
    ).concat((await @matchFiles(path.join("**", "*"), {
      "nodir": true,
      "dot": true,
      "cwd": @site.get("srcDir")
    })).map((srcPath) =>
      return {"srcDir": @site.get("srcDir"), "srcPath": srcPath}
    ))
    await Promise.all(allFiles.map(@loadFile))
    @saveAssets()
    @site = await @generator.generate("beforeProcessing", @site)
    await @processPosts()
    await @processPages()
    @site = await @generator.generate("afterProcessing", @site)
    @savePosts()
    @savePages()
    @saveFile()

  serve: (ip, port) =>
    allFiles = (await @matchFiles(path.join("**", "*"), {
      "nodir": true,
      "dot": true,
      "cwd": @site.get("themeSrcDir")
    })).map((srcPath) =>
      return {"srcDir": @site.get("themeSrcDir"), "srcPath": srcPath}
    ).concat((await @matchFiles(path.join("**", "*"), {
      "nodir": true,
      "dot": true,
      "cwd": @site.get("srcDir")
    })).map((srcPath) =>
      return {"srcDir": @site.get("srcDir"), "srcPath": srcPath}
    ))
    await Promise.all(allFiles.map(@loadFile))
    @unprocessedSite.set("pages", @site.get("pages")[0...])
    @site = await @generator.generate("beforeProcessing", @site)
    await @processPosts()
    await @processPages()
    @site = await @generator.generate("afterProcessing", @site)
    @buildServerRoutes()
    @listen(ip, port)

module.exports = Router

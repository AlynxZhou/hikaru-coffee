// Generated by CoffeeScript 2.3.2
(function() {
  var Category, File, Promise, Site, Tag, URL, escapeHTML, extMIME, fm, fse, genToc, getContentType, getPathFn, getURLFn, getVersion, glob, highlight, isCurrentPathFn, matchFiles, moment, packageJSON, paginate, paginateCategories, parseFrontMatter, path, removeControlChars, resolveHeaderIds, resolveImage, resolveLink, sortCategories, transposeYAMLTime;

  fm = require("front-matter");

  fse = require("fs-extra");

  path = require("path");

  glob = require("glob");

  ({URL} = require("url"));

  moment = require("moment-timezone");

  Promise = require("bluebird");

  ({Site, File, Category, Tag} = require("./types"));

  highlight = require("./highlight");

  packageJSON = require("../package.json");

  extMIME = require("../dist/ext-mime.json");

  escapeHTML = function(str) {
    return str.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/"/g, "&#039;");
  };

  matchFiles = function(pattern, options) {
    return new Promise(function(resolve, reject) {
      return glob(pattern, options, function(err, res) {
        if (err != null) {
          return reject(err);
        }
        return resolve(res);
      });
    });
  };

  removeControlChars = function(str) {
    return str.replace(/[\x00-\x1F\x7F]/g, "");
  };

  // YAML ignores your local timezone and parse time as UTC.
  // This function will transpose it to a time without timezone.
  // Which looks the same as the original string.
  // If you keep timezone, you cannot easily parse it as another timezone.
  // https://github.com/nodeca/js-yaml/issues/91
  transposeYAMLTime = function(datetime) {
    // If you don't write full YYYY-MM-DD HH:mm:ss, js-yaml will leave a string.
    if (typeof datetime === "string") {
      return moment(datetime).format("YYYY-MM-DD HH:mm:ss");
    }
    return moment(new Date(datetime.getTime() + datetime.getTimezoneOffset() * 60000)).format("YYYY-MM-DD HH:mm:ss");
  };

  parseFrontMatter = function(file) {
    var parsed, ref;
    if (typeof file["raw"] !== "string") {
      return file;
    }
    parsed = fm(file["raw"]);
    file["text"] = parsed["body"];
    file["frontMatter"] = parsed["attributes"];
    file = Object.assign(file, parsed["attributes"]);
    file["title"] = (ref = file["title"]) != null ? ref.toString() : void 0;
    // Nunjucks does not allow to call moment.tz.guess() in template.
    // So we pass timezone to each file as an attribute.
    file["zone"] = file["zone"] || moment.tz.guess();
    if (file["updatedTime"] == null) {
      file["updatedTime"] = fse.statSync(path.join(file["srcDir"], file["srcPath"]))["mtime"];
    } else {
      file["updatedTime"] = moment.tz(transposeYAMLTime(file["updatedTime"]), file["zone"]).toDate();
    }
    // Fallback compatibility.
    file["createdTime"] = file["createdTime"] || file["date"];
    if (file["createdTime"] == null) {
      file["createdTime"] = file["updatedTime"];
      file["createdMoment"] = moment(file["createdTime"]);
    } else {
      // Parsing non-timezone string with a user-specific timezone.
      file["createdMoment"] = moment.tz(transposeYAMLTime(file["createdTime"]), file["zone"]);
      file["createdTime"] = file["createdMoment"].toDate();
    }
    if (file["language"] != null) {
      file["createdMoment"].locale(file["language"]);
    }
    // Fallback compatibility.
    file["date"] = file["createdTime"];
    return file;
  };

  getContentType = function(docPath) {
    return extMIME[path.extname(docPath)] || "application/octet-stream";
  };

  paginate = function(p, posts, perPage, ctx) {
    var i, j, k, len, perPagePosts, post, ref, results;
    if (!perPage) {
      perPage = 10;
    }
    results = [];
    perPagePosts = [];
    for (j = 0, len = posts.length; j < len; j++) {
      post = posts[j];
      if (perPagePosts.length === perPage) {
        results.push(Object.assign(new File(), p, ctx, {
          "posts": perPagePosts
        }));
        perPagePosts = [];
      }
      perPagePosts.push(post);
    }
    results.push(Object.assign(new File(), p, ctx, {
      "posts": perPagePosts
    }));
    results[0]["pageArray"] = results;
    results[0]["pageIndex"] = 0;
    results[0]["docPath"] = p["docPath"];
    for (i = k = 1, ref = results.length; (1 <= ref ? k < ref : k > ref); i = 1 <= ref ? ++k : --k) {
      results[i]["pageArray"] = results;
      results[i]["pageIndex"] = i;
      results[i]["docPath"] = path.join(path.dirname(p["docPath"]), `${path.basename(p["docPath"], path.extname(p["docPath"]))}-${i + 1}.html`);
    }
    return results;
  };

  sortCategories = function(category) {
    var j, len, ref, results1, sub;
    category["posts"].sort(function(a, b) {
      return -(a["date"] - b["date"]);
    });
    category["subs"].sort(function(a, b) {
      return a["name"].localeCompare(b["name"]);
    });
    ref = category["subs"];
    results1 = [];
    for (j = 0, len = ref.length; j < len; j++) {
      sub = ref[j];
      results1.push(sortCategories(sub));
    }
    return results1;
  };

  paginateCategories = function(category, parentPath, perPage, site) {
    var j, len, ref, results, sp, sub;
    results = [];
    sp = Object.assign(new File(site["siteConfig"]["docDir"]), {
      "layout": "category",
      "docPath": path.join(parentPath, `${category["name"]}`, "index.html"),
      "title": "category",
      "name": category["name"].toString()
    });
    category["docPath"] = sp["docPath"];
    results = results.concat(paginate(sp, category["posts"], perPage));
    ref = category["subs"];
    for (j = 0, len = ref.length; j < len; j++) {
      sub = ref[j];
      results = results.concat(paginateCategories(sub, path.join(parentPath, `${category["name"]}`), perPage, site));
    }
    return results;
  };

  getPathFn = function(rootDir = path.posix.sep) {
    rootDir = rootDir.replace(path.win32.sep, path.posix.sep);
    return function(docPath = "") {
      if (!path.posix.isAbsolute(rootDir)) {
        rootDir = path.posix.join(path.posix.sep, rootDir);
      }
      if (docPath.endsWith("index.html")) {
        docPath = docPath.substring(0, docPath.length - "index.html".length);
      }
      return encodeURI(path.posix.join(rootDir, docPath.replace(path.win32.sep, path.posix.sep)));
    };
  };

  getURLFn = function(baseURL, rootDir = path.posix.sep) {
    var getPath;
    getPath = getPathFn(rootDir);
    return function(docPath = "") {
      return new URL(getPath(docPath), baseURL);
    };
  };

  isCurrentPathFn = function(rootDir = path.posix.sep, currentPath) {
    var currentToken, getPath;
    // Must join a "/" before resolve or it will join current work dir.
    getPath = getPathFn(rootDir);
    currentPath = getPath(currentPath);
    currentToken = path.posix.resolve(path.posix.join(path.posix.sep, currentPath.replace(path.win32.sep, path.posix.sep))).split(path.posix.sep);
    return function(testPath = "", strict = false) {
      var i, j, ref, testToken;
      testPath = getPath(testPath);
      if (currentPath === testPath) {
        return true;
      }
      testToken = path.posix.resolve(path.posix.join(path.posix.sep, testPath.replace(path.win32.sep, path.posix.sep))).split(path.posix.sep);
      if (strict && testToken.length !== currentToken.length) {
        return false;
      }
// testPath is shorter and usually be a menu link.
      for (i = j = 0, ref = testToken.length; (0 <= ref ? j < ref : j > ref); i = 0 <= ref ? ++j : --j) {
        if (testToken[i] !== currentToken[i]) {
          return false;
        }
      }
      return true;
    };
  };

  resolveHeaderIds = function($) {
    var escaped, h, hNames, headerIds, headings, id, j, len, results1, text;
    hNames = ["h1", "h2", "h3", "h4", "h5", "h6"];
    headings = $(hNames.join(", "));
    headerIds = {};
    results1 = [];
    for (j = 0, len = headings.length; j < len; j++) {
      h = headings[j];
      text = $(h).text();
      // Remove some chars in escaped ID because
      // bootstrap scrollspy cannot support it.
      escaped = escapeHTML(text).trim().replace(/[\s\(\)\[\]{}<>\.,\!\@#\$%\^&\*=\|`"'\/\?~]+/g, "");
      if (headerIds[escaped]) {
        id = `${escaped}-${headerIds[escaped]++}`;
      } else {
        id = escaped;
        headerIds[escaped] = 1;
      }
      $(h).attr("id", `${id}`);
      results1.push($(h).html(`<a class="headerlink" href="#${id}" title="${escaped}">` + "</a>" + `${text}`));
    }
    return results1;
  };

  genToc = function($) {
    var h, hNames, headings, j, len, level, toc;
    // TOC generate.
    hNames = ["h1", "h2", "h3", "h4", "h5", "h6"];
    headings = $(hNames.join(", "));
    toc = [];
    for (j = 0, len = headings.length; j < len; j++) {
      h = headings[j];
      level = toc;
      while (level.length > 0 && hNames.indexOf(level[level.length - 1]["name"]) < hNames.indexOf(h["name"])) {
        level = level[level.length - 1]["subs"];
      }
      // Don't set archor to absolute path because bootstrap scrollspy
      // can only accept relative path for ID.
      level.push({
        "archor": `#${$(h).attr("id")}`,
        "name": h["name"],
        "text": $(h).text().trim(),
        "subs": []
      });
    }
    return toc;
  };

  resolveLink = function($, baseURL, rootDir, docPath) {
    var a, getPath, getURL, href, j, len, links, results1;
    getURL = getURLFn(baseURL, rootDir);
    getPath = getPathFn(rootDir);
    // Replace relative path to absolute path.
    links = $("a");
    results1 = [];
    for (j = 0, len = links.length; j < len; j++) {
      a = links[j];
      href = $(a).attr("href");
      if (href == null) {
        continue;
      }
      if (new URL(href, baseURL).host !== getURL(docPath).host) {
        $(a).attr("target", "_blank");
      }
      if (href.startsWith("https://") || href.startsWith("http://") || href.startsWith("//") || href.startsWith("/") || href.startsWith("javascript:")) {
        continue;
      }
      results1.push($(a).attr("href", getPath(path.join(path.dirname(docPath), href))));
    }
    return results1;
  };

  resolveImage = function($, rootDir, docPath) {
    var getPath, i, imgs, j, len, results1, src;
    getPath = getPathFn(rootDir);
    // Replace relative path to absolute path.
    imgs = $("img");
    results1 = [];
    for (j = 0, len = imgs.length; j < len; j++) {
      i = imgs[j];
      src = $(i).attr("src");
      if (src == null) {
        continue;
      }
      if (src.startsWith("https://") || src.startsWith("http://") || src.startsWith("//") || src.startsWith("/") || src.startsWith("file:image")) {
        continue;
      }
      results1.push($(i).attr("src", getPath(path.join(path.dirname(docPath), src))));
    }
    return results1;
  };

  getVersion = function() {
    return packageJSON["version"];
  };

  module.exports = {
    "escapeHTML": escapeHTML,
    "matchFiles": matchFiles,
    "removeControlChars": removeControlChars,
    "parseFrontMatter": parseFrontMatter,
    "getContentType": getContentType,
    "paginate": paginate,
    "sortCategories": sortCategories,
    "paginateCategories": paginateCategories,
    "getPathFn": getPathFn,
    "getURLFn": getURLFn,
    "isCurrentPathFn": isCurrentPathFn,
    "resolveHeaderIds": resolveHeaderIds,
    "resolveLink": resolveLink,
    "resolveImage": resolveImage,
    "genToc": genToc,
    "getVersion": getVersion,
    "highlight": highlight
  };

}).call(this);

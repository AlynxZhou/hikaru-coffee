Hikaru
======

A static site generator that generates routes based on directories naturally.
-----------------------------------------------------------------------------

# NOT FINISHED YET, JUST IMPLEMENTED VERY SIMPLE FUNCTIONS.

# List

- [X] Dir based router.
- [X] Marked Markdown renderer.
- [X] Stylus CSS renderer.
- [X] Nunjucks template renderer.
- [X] Highlight.js code highlight.
- [X] Async loading, rendering and saving file.
- [ ] Pagination for index, archives, categories (different category pages) and tags (different tag pages).
- [ ] Archives info for templating.
- [ ] Categories info for templating.
- [ ] Tags info for templating.
- [ ] Cheerio-based toc generating.
- [ ] Cheerio-based path converting (relative to absolute).
- [ ] Date operations in templates.
- [ ] sprintf-js based multi-languages support.

# Dir Structure

```plain
hikura-site/
    |- src/ # source dir for user files
    |   |- images/
    |   |- css/
    |   |- js/
    |   |- index.md
    |   |- about/
    |   |   |- index.md
    |   |- tags/
    |   |   |- index.md
    |- doc/ # source will be render to here
    |   |- images/
    |   |   |- logo.png
    |   |- css/
    |   |   |- index.css
    |   |- js/
    |   |   |- index.js
    |   |- index.html
    |   |- 2.html # page 2 of index
    |   |- 3.html # page 3 of index
    |   |- about/
    |   |   |- index.html
    |   |- tags/
    |   |   |- index.html
    |   |   |- tag-1/
    |   |   |   |- index.html # automatically generated
    |   |   |   |- 2.html # page 2 of tag-1
    |- themes/
    |   |- aria/
    |   |   |- src/ # this will be render to doc/
    |   |   |   |- layout.njk # templates
    |   |   |   |- index.njk
    |   |   |   |- about.njk
    |   |   |   |- page.njk # if no layout specific, fallback to this
    |   |   |   |- css/
    |   |   |   |   |- index.styl
    |   |   |   |- js/
    |   |   |   |   |- index.js
    |   |   |   |- images/
    |   |   |   |   |- logo.png
    |   |- README.md
```

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
- [ ] Pagination.
- [ ] Archives info for templating.
- [ ] Categories info for templating.
- [ ] Tags info for templating.
- [ ] Cheerio-based toc generating.
- [ ] Cheerio-based path converting (relative to absolute).
- [ ] Date operations in templates.

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
    |   |   |- 2/ # page 2
    |   |   |   |- index.html
    |   |   |- 3/ # page 3
    |	|   |   |- index.html
    |   |- about/
    |   |   |- index.html
    |   |- tags/
    |   |   |- index.html
    |- themes/
    |   |- aria/
    |   |   |- src/ # this will be render to doc/
    |   |   |   |- layout.njk # templates
    |   |   |   |- index.njk
    |   |   |   |- about.njk
    |   |   |   |- css/
    |   |   |   |   |- index.styl
    |   |   |   |- js/
    |   |   |   |   |- index.js
    |   |   |   |- images/
    |   |   |   |   |- logo.png
    |   |- README.md
```

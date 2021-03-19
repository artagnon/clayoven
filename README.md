# clayoven ![logo](assets/clayoven.png)

[![Maintainability](https://api.codeclimate.com/v1/badges/f80781c50c7fb18e6130/maintainability)](https://codeclimate.com/github/artagnon/clayoven/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/f80781c50c7fb18e6130/test_coverage)](https://codeclimate.com/github/artagnon/clayoven/test_coverage)

clayoven is a beautiful website generator with a carefully curated set of features. It has been built at a glacial pace, over a period of [eight years](https://github.com/artagnon/clayoven/commit/d4d40161e9f76dbe74078c669de9af698cf621d6), as [my website](https://artagnon.com) expanded in content. I have a spread of mathematical notes, both in LaTeX and handwritten, software-related posts, and some wider-audience [articles](https://artagnon.com/articles); it suffices to say that clayoven is good on all three fronts. The source files are written in "claytext", a custom format built for elegance and speed.

## Getting started

There is no published gem yet. To get started, clone, run `bundle` to install the required gems, and put `bin/clayoven` in `$PATH`. Then, run `clayoven init` in a fresh directory. To start writing, install [vsclay](https://marketplace.visualstudio.com/items?itemName=artagnon.vsclay) for vscode, which will provide the necessary syntax highlighting, and trigger-incremental-build-on-save functionality.

## The claytext format

Here's an excerpt of claytext, illustrating the main features:

![vsclay demo](assets/vsclay-demo.png)

## The site-generation engine

All site content is split up into "topics", to put in the sidebar, each of which can either serve as an index to a collection of `ContentPages` (as a bunch of `.clay` files in a subdirectory with the name `#{topic}`), or a single `IndexPage` (named `#{topic}.index.clay`). `index.clay` is special-cased to serve as the root of the site.

So, if you have these files,

    .vscode/...             # provided by `init`
    .htaccess               # provided by `init`
    lib/...                 # provided by `init`
    design/template.slim    # provided by `init`
    index.clay              # provided by `init`
    scratch.index.clay      # provided by `init`
    404.index.clay          # provided by `init`
    blog.index.clay
    blog/personal/1.clay
    blog/math/1.clay
    colophon.index.clay

clayoven automatically builds a sidebar with `index`, `blog` and `colophon` (called `IndexPage`). `/blog` will have links to the posts `/blog/personal/1` and `/blog/math/1` (called `ContentPage`), under the titles `personal` and `math` (the "subtopics"). If there are `ContentPage` for a topic, the `IndexPage` simply serves to give a introduction, with links to articles automatically appearing after the introduction. `IndexPage` and `ContentPage` are run through the same `design/template.slim`, but this isn't a problem in practice because all the necessary accessors are in the base class `Page`.

The engine works closely with the git object store, and builds are incremental by default; it mostly Just Works, and when it doesn't, there's an option to force a full rebuild. The engine also pulls out the created-timestamp (`Page#crdate`) and last-modified-timestamp (`Page#lastmod`) from git, respecting moves. `ContentPages` are sorted by `crdate`, reverse-chronologically, and `IndexPages` are sorted alphabetically.

## Usage

- `clayoven init` to generate the necessary template website.
- `clayoven` to generate html files incrementally based on the current git index.
- `clayoven aggressive` to regenerate the entire site along with a `sitemap.xml.gz`; run occassionally.
- `clayoven httpd` to preview your website locally.

## Configuration

1. `.clayoven/sitename` is URL of the site, excluding the `https://` prefix.
2. `.clayoven/hidden` is a list of `IndexFiles` that should be built, but not displayed in the sidebar. You would want to use it for your 404 page and drafts.
3. `.clayoven/tz` is a timezone-to-location mapper, with lines of the form `+0000 London`. clayoven digs through the git history for locations, and exposes a `Page#locations`.
4. `.clayoven/st` is a [subtopic directory]-to-subtitle mapper, with lines of the form `inf ∞-categories`.

## Tips

- Check in the generated html to the site's repository, so that eyeballing `git diff` can serve as a testing mechanism.
- If you accidentally commit `.clay` files before running clayoven, running it afterward will do nothing, since it will see a clean git index; you'll need to run the aggressive variant.
- Importing historical content is easy; a `git commit --date="#{historical_date}"` would give the post an appropriate creation date that will be respected in the sorting-order.

## The claytext processor

The claytext processor is, at its core, a paragraph-processor; all content must be split up into either plain paragraphs, or "fences" (or multiple paragraphs delimited by start and end tokens). The function of most markers should be evident from the `scratch.html` produced by a `clayoven init`. The format is strict, and the processor doesn't like files with paragraphs wrapped using hard line breaks.

`Transforms::LINE` matches paragraphs where all lines begin with some regex, and `Transforms::Fenced` match fences (could be multiple paragraphs) that start and end with the specified tokens.

## Planned features, and anti-features

- Intellisense for vsclay.
- Anti: extending claytext in ways that would necessitate an ugly implementation.

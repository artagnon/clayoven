# clayoven ![logo](assets/clayoven.png)

[![Maintainability](https://img.shields.io/codeclimate/maintainability/artagnon/clayoven?style=for-the-badge&logo=code-climate&labelColor=000000&label=Maintainability)](https://codeclimate.com/github/artagnon/clayoven/maintainability)
[![Test Coverage](https://img.shields.io/codeclimate/coverage/artagnon/clayoven?style=for-the-badge&logo=code-climate&labelColor=000000&label=Test%20Coverage)](https://codeclimate.com/github/artagnon/clayoven/test_coverage)

clayoven is a beautiful static site generator with a carefully curated set of features. It has been built at a glacial pace, over a period of [eight years](https://github.com/artagnon/clayoven/commit/d4d40161e9f76dbe74078c669de9af698cf621d6), as [my website](https://artagnon.com) expanded in content. I have a spread of mathematical notes, both typeset and handwritten, software-related posts, and some wider-audience articles; while clayoven is primarily aimed at math-heavy sites, it is good on all three fronts. The source files are written in "claytext", a custom format built for elegance and speed.

rdoc documentation is available at [clayoven.artagnon.com](https://clayoven.artagnon.com).

## Unique features

- Small! ~500 lines of well-written and well-documented Ruby.
- Beautiful and easily extensible markup, with a dedicated vscode plugin for it.
- Automatically picks timestamps from git history, respecting moves.
- Server-side rendering of math, including commutative diagrams, via MathJaX and XyJaX.

## Demo

A starter project is bundled with the following `scratch.index.clay`:

![syntax highlighting demo](https://user-images.githubusercontent.com/37226/113478818-91a7f280-948b-11eb-87f0-3610f2aa3160.png)

whose rendered output can be seen [here](https://artagnon.com/scratch)).

Here's an excerpt of embedded MathJaX with IntelliSense powered by vsclay:

![IntelliSense demo](https://user-images.githubusercontent.com/37226/113474233-24866400-946f-11eb-8e72-b82460d16c71.mp4)

## Getting started

There is no published gem. To get started, clone, run `bundle` to install the required gems, and put `bin/clayoven` in `$PATH`. Then, run `clayoven init` in a fresh directory. To start writing, install [vsclay](https://marketplace.visualstudio.com/items?itemName=artagnon.vsclay) for vscode, which will provide the necessary syntax highlighting, IntelliSense support for MathJaX, and trigger-[incremental build]-on-save functionality.

## The site-generation engine

All site content is split up into "topics", to put in the sidebar, each of which can either serve as an index to a collection of `ContentPages` (as a bunch of `.clay` files in a subdirectory with the name `#{topic}`), or a single `IndexPage` (named `#{topic}.index.clay`). `index.clay` is special-cased to serve as the root of the site.

So, if you have these files,

    .vscode/...             # provided by `init`
    .htaccess               # provided by `init`
    lib/...                 # provided by `init`
    design/                 # provided by `init`
    index.clay              # provided by `init`
    scratch.index.clay      # provided by `init`
    404.index.clay          # provided by `init`
    blog.index.clay
    blog/personal/1.clay
    blog/math/1.clay
    colophon.index.clay

clayoven automatically builds a sidebar with `index`, `blog` and `colophon` (each of which are instances of `IndexPage`). `/blog` will have links to the posts `/blog/personal/1` and `/blog/math/1` (each of which are instances of `ContentPage`), under the titles `personal` and `math` (the "subtopics"). If there multiple `ContentPage` entries under an `IndexPage`, the latter simply serves to give a introduction, with links to articles automatically appearing after the introduction. `IndexPage` and `ContentPage` are run through the same `design/template.slim`, and the template file has access to the accessors.

The engine works closely with the git object store, and builds are incremental by default; it mostly Just Works, and when it doesn't, there's an option to force a full rebuild. The engine also pulls out the created-timestamp (`Page#crdate`) and last-modified-timestamp (`Page#lastmod`) from git, respecting moves. `ContentPages` are sorted by `crdate`, reverse-chronologically, and `IndexPages` are sorted alphabetically.

## Usage

- `clayoven init` to generate the necessary starter project.
- `clayoven` to generate html files incrementally based on the current git index.
- `clayoven aggressive` to regenerate the entire site; only requires to be run on occassion.
- `clayoven httpd` to preview your website locally.

## Configuration

1. `.clayoven/sitename` is URL of the site, excluding the `https://` prefix.
2. `.clayoven/hidden` is a list of `IndexFiles` that should be built, but not displayed in the sidebar. You would want to use it for your 404 page and drafts.
3. `.clayoven/tz` is a timezone-to-location mapper, with lines of the form `+0000 London`. clayoven digs through the git history for locations, and exposes a `Page#locations`.
4. `.clayoven/subtopic` is a [subtopic directory]-to-subtitle mapper, with lines of the form `inf ∞-categories`.

## The claytext processor

The claytext processor is, at its core, a paragraph-processor; all content must be split up into either plain paragraphs, or "fences" (multiple paragraphs delimited by start and end tokens). The function of most markers should be evident from the `scratch.html` produced by a `clayoven init`. The format is strict, and the processor doesn't like files with paragraphs wrapped using hard line breaks.

`Clayoven::Claytext::Transforms::LINE` matches paragraphs where all lines begin with some regex, and `Clayoven::Claytext::Transforms::Fenced` match fences (could be multiple paragraphs) that start and end with the specified tokens. In addition to this, there are inline markdown markers `` `...` `` and `[...](...)`, for content that is to be put in `<mark>` and `<a>`, respectively.

## Tips

- Check in the generated html to the site's repository, so that eyeballing `git diff` can serve as a testing mechanism.
- If you accidentally commit `.clay` files before running clayoven, running it afterward will do nothing, since it will see a clean git index; you'll need to run the aggressive variant.
- Importing historical content is easy; a `git commit --date="#{historical_date}"` would give the post an appropriate creation date that will be respected in the sorting-order.

## Planned features, and anti-features

- Have one unified dhall configuration.
- Allow the user to extend claytext syntax with configuration.
- Hit 100% test coverage.
- Get vsclay to report syntax errors.
- Anti: extend clayoven in ways that would necessitate an ugly implementation.

# clayoven ![logo](clayoven.png)

[![Code Climate](https://codeclimate.com/github/artagnon/clayoven.png)](https://codeclimate.com/github/artagnon/clayoven)

clayoven is an minimalist website generator with a carefully curated set of features. It has been built at a glacial pace, over a period of [seven years](https://github.com/artagnon/clayoven/commit/d4d40161e9f76dbe74078c669de9af698cf621d6), as [my website](https://artagnon.com) expanded in content. I have a spread of mathematical notes, software-related posts, and even one wider-audience article; it suffices to say that clayoven is good on all three fronts. The source files are written in "claytext", a custom format built for elegance and speed.

## The claytext processor, briefly

Here's an excerpt of claytext, illustrating the main features.

```latex
claytext demo

(Posts here have been ressurrected from several years ago)

<<
rM-reading.jpg
rM-writing.jpg
>>

I have written a lot of [code](https://github.com/artagnon) in the past.

# Functors

For a fixed field $K$, consider the functors

$$
\begin{xy}
\xymatrix{
\textbf{Set}\ar@<.5ex>[r]^V & \textbf{Vct}_K\ar@<.5ex>[l]^U
}
\end{xy}
$$

--

[[
void assignHeads(std::vector<Statement*> branchHeads,
                 std::vector<Statement*> headsToStaggerWith,
                 Statement* nestWithin, Statement* toEnclose);
]]

(ii) Every element of $A$ is either unit or nilpotent.
(iii) $A/\mathfrak{N}$ is a field.

1. The Merge dominates the Split, in which case, the Merge dominates everything lying on the outEdges of the Split leading to the Merge
2. The Split dominates the Merge, in which case, the Split dominates everything on its outEdges leading to the Merge.

[^1]: Hat tip to [Sanjoy](http://playingwithpointers.com) for pointing out the fifth case.
[^2]: You might want to merge loops that share a header in a post-pass.
```

## The site-generation engine, briefly

All site content is split up into "topics", to put in the sidebar, each of which can either serve as an index to a collection of `ContentPages` (as a bunch of `.clay` files in a subdirectory with the name `#{topic}`), or a single `IndexPage` (named `#{topic}.index.clay`). `index.clay` is special-cased to serve as the root of the site.

So, if you have these files,

    index.clay
    design/template.slim
    blog.index.clay
    blog/1.clay
    blog/2.clay
    colophon.index.clay

clayoven automatically builds a sidebar with `index`, `blog` and `colophon` (the `IndexPages`). `/blog` will have links to the posts `/blog/1` and `/blog/2` (the `ContentPages`). If there are `ContentPages` for a topic, the `IndexPage` simply serves to give a introduction, with links to articles appearing after the introduction.

`IndexPages` and `ContentPages` are run through the same `template.slim`, which is expected to conditionally reason about the available accessors. To illustrate, here's a simple `template.slim`:

```slim
doctype html
html
  head
    title clayoven: #{permalink}
  body
    div id="main"
      h1 #{title}
      time #{authdate.strftime('%F')}
        - if paragraph.is_plain?
          p
            == paragraph.contents.join "\n"
    div id="sidebar"
      ul
        - if topics
          - topics.each do |topic|
            li
              a href="/#{topic}"
                = topic
```

The site-generation engine works closely with the git object store, and builds are incremental by default; it mostly Just Works, and when it doesn't, there's an option to force a full build. The engine also pulls out the created-timestamp (`authdate`) and last-modified-timestamp (`pubdate`) from git, respecting moves; as long as there is a significant correlation between old content and new content, `authdate` is calculated on the old content. `ContentPages` are sorted by `authdate`, reverse-chronologically, and `IndexPages` are sorted alphabetically.

## Usage

Install the `slim` and `sitemap_generator` gems, and run `clayoven` in an empty directory; on a first-run, the necessary template-files are created, and git is initialized. An `index.html` is produced.

- `clayoven` on your website's repository to generate html files incrementally based on the current git index and untracked files.
- `clayoven aggressive` to regenerate the entire site along with a `sitemap.xml`. You can run this occassionally, when you add or remove files.
- `clayoven httpd` to preview your website at `localhost:8000`.

Use [MathJax](https://www.mathjax.org) to render LaTeX, and [highlight.js](https://highlightjs.org) to do syntax highlighting.

## Configuration

`.clayoven/hidden` is a list of `IndexFiles` that should be built, but not displayed in the sidebar. You would want to use it for your 404 page and drafts.

## Workflow and vscode integration

Getting _some_ syntax highlighting in `.clay` files in vscode is pretty simple: you simply have to tell it to associate the extension with the `latex` mode. A build-on-save is also pretty easy to set up: write a custom build task, and use [an extension](https://marketplace.visualstudio.com/items?itemName=Gruntfuggly.triggertaskonsave) to trigger the build on save.

## [Appendix A] The claytext processor, in greater detail

The claytext processor is, at its core, a paragraph-processor; all content must be split up into paragraphs, decorated with optional first-and-last-line-markers. The function of `<< ... >>`, `$$ ... $$`, and `[[ ... ]]` markers should be evident; the marker tokens must be in lines of their own. The first paragraph is optionally a header, and if so, markers `( ... )` must be used. The last paragraph is an optional footer, prefixed with `[^\d+]:` lines to enable the footer. The `#` prefix for a paragraph is for subheadings. In a paragraph with lists, each line must begin with the numeral or roman numeral, as shown. The format is strict, and the processor doesn't like files with paragraphs wrapped using hard line breaks, for instance.

`PARAGRAPH_LINE_FILTERS` matches paragraphs where all lines begin with some regex, and `PARAGRAPH_START_END_FILTERS` match paragraphs that start and end with the specified tokens. For things that involve using a regex to match text in the middle of a paragraph like the markdown-style links in the example, [javascript](https://github.com/artagnon/artagnon.com/blob/master/design/claytext.js) is the easy way of getting it done.

## [Appendix B] Tips

- This document is not an exhaustive list of features.
- Check in the generated html to the site's repository, so that eyeballing `git diff` can serve as a testing mechanism.
- Use suitable rewrite rules for your webserver to have URLs without the ugly `.html` suffix.
- If you accidentally commit `.clay` files before running clayoven, running it afterward will do nothing, since it will see a clean git index; you'll need to run the aggressive version. This kind of situation doesn't occur in the first place, if you follow the [workflow guidelines](/README.md#workflow-and-vscode-integration).
- Importing historical content is easy; a `git commit --date="#{historical_date}"` would give the post an appropriate `authdate` that will be respected in the sorting-order.
- Don't bother attempting to optimize the Ruby; the biggest contributor to the runtime, by far, are the multiple shell-outs to `git log --follow`.

## [Appendix C] Planned features, and anti-features

- A vscode extension for syntax highlighting.
- Anti: extending claytext in ways that would necessitate an ugly implementation.
- Anti: attempting to shave the startup time using Rugged or some other bindings; the shell-out cost is balanced out by the simplicity.

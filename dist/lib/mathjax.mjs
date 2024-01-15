import { readFileSync, writeFileSync } from "fs";
import yargs from "yargs";
import { hideBin } from "yargs/helpers";
import "colors";
import ProgressBar from "progress";
import * as mathjax from "mathjax-full/es5/node-main.js";

const argv = yargs(hideBin(process.argv)).argv;

mathjax
  .init({
    options: {
      typesetError: (_, math, err) => console.log(math.math + ": " + err),
    },
    loader: {
      paths: { mathjax: "mathjax-full/es5", custom: "." },
      require: (url) => import(url),
      load: ["input/tex-full", "output/chtml", "[custom]/xypic"],
    },
    tex: {
      packages: { "[+]": ["xypic"] },
      inlineMath: [["$", "$"]],
    },
    chtml: {
      fontURL:
        "https://cdn.jsdelivr.net/npm/mathjax@3/es5/output/chtml/fonts/woff-v2",
    },
  })
  .then((MathJax) => {
    let progress = new ProgressBar(
      `[${"TeX".green} ]: |:bar|`,
      {
        total: argv._.length,
        incomplete: " ",
      }
    );
    argv._.forEach((r) => {
      // Read in the HTML file
      const html = (MathJax.startup.document = MathJax.startup.getDocument(
        readFileSync(r, "utf8")
      ));

      // xypic has used the adaptor
      const adaptor = MathJax.startup.adaptor;

      // Clear the font cache
      html.outputJax.clearCache();

      // Typeset the document, with the render hooks that xypic has put in place
      html.clear().render();

      // Output the resulting HTML in-place
      writeFileSync(
        r,
        adaptor.doctype(html.document) +
        adaptor.outerHTML(adaptor.root(html.document))
      );
      progress.tick();
    });
  })
  .catch((err) => console.log(err));

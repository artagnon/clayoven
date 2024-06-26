import minify from "@node-minify/core";
import terser from "@node-minify/terser";
import * as sass from "sass";
import { writeFileSync } from "fs";

minify({
  compressor: terser,
  input: "design/script.js",
  output: "dist/script.min.js",
  callback: (err, _) => {
    if (err) console.log(err);
  },
});

writeFileSync("dist/style.min.css", sass.compile("design/style.sass", { style: "compressed" }).css);
writeFileSync("dist/rouge.min.css", sass.compile("design/rouge.sass", { style: "compressed" }).css);

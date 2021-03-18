import minify from '@node-minify/core';
import babelMin from '@node-minify/babel-minify';
import cleanCSS from '@node-minify/clean-css';

minify({
  compressor: babelMin,
  input: 'design/script.js',
  output: 'dist/script.min.js',
  callback: (err, _) => { if (err) console.log(err); }
});

minify({
  compressor: cleanCSS,
  input: ['design/style.css'],
  output: 'dist/style.min.css',
  callback: (err, _) => { if (err) console.log(err); }
});

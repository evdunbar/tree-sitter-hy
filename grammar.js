/**
 * @file Hy grammar for tree-sitter
 * @author E Dunbar <evdunbar@protonmail.com>
 * @license MIT
 */

/// <reference types="tree-sitter-cli/dsl" />
// @ts-check

module.exports = grammar({
  name: "hy",

  rules: {
    // TODO: add the actual grammar rules
    source_file: $ => "hello"
  }
});

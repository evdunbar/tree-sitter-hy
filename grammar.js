/**
 * @file Hy grammar for tree-sitter
 * @author E Dunbar <evdunbar@protonmail.com>
 * @license MIT
 */

/// <reference types="tree-sitter-cli/dsl" />
// @ts-check

const regexp = {
  ascii_whitespace: /[\u0009\u000A\u000B\u000C\u000D\u0020]/,
  symbol_seq: /[^()\[\]{};"'`~:.\d\u0009\u000A\u000B\u000C\u000D\u0020][^()\[\]{};"'`~.\u0009\u000A\u000B\u000C\u000D\u0020]*/
}
const symbol_seq_immediate = token.immediate(regexp.symbol_seq)
const digitpart = seq(/\d/, repeat(/_*\d+/))
const pointfloat = choice(
  seq(optional(digitpart), '.', digitpart),
  seq(digitpart, '.'),
)
const exponentfloat = seq(
  choice(digitpart, pointfloat),
  seq(/[eE]/, optional(/[+-]/), digitpart),
)

module.exports = grammar({
  name: 'hy',

  extras: $ => [
    regexp.ascii_whitespace,
    $.comment,
  ],

  // word: $ => $.symbol,

  rules: {
    source_file: $ => seq(optional($.shebang), repeat($._element)),

    shebang: _ => token(seq('#!', /.*/)),
    _element: $ => choice($._form, $.discard, $.comment),

    _form: $ => seq(optional($._sugar), choice($._identifier, $._sequence, $._string)),
    discard: $ => seq('#_', $._form),
    comment: _ => token(seq(';', /.*/)),

    _sugar: _ => choice(
      field('quote', '\''),
      field('quasiquote', '`'),
      field('unqoute', '~'),
      field('unqoute_splice', '~@'),
      field('unpack_iterable', '#*'),
      field('unpack_mapping', '#**'),
    ),
    _identifier: $ => choice(
      $._numeric_literal,
      $.keyword,
      $.symbol,
      $.dotted_identifier,
    ),
    _sequence: $ => choice($.expression, $.list, $.tuple, $.set, $.dictionary),
    _string: $ => choice($.string, $.bracket_string),

    _numeric_literal: $ => choice($.integer, $.float, $.complex),
    keyword: _ => token(seq(':', optional(regexp.symbol_seq))),
    dotted_identifier: _ => prec(1, choice(
      seq(
        /[.]+/,
        symbol_seq_immediate,
        repeat(seq(token.immediate('.'), symbol_seq_immediate)),
      ),
      seq(
        regexp.symbol_seq,
        repeat1((seq(token.immediate('.'), symbol_seq_immediate)))),
    )),
    symbol: _ => choice(
      /[.]+/,
      regexp.symbol_seq,
    ),

    expression: $ => seq('(', repeat1($._element), ')'),
    list: $ => seq('[', repeat($._element), ']'),
    tuple: $ => seq('#(', repeat($._element), ')'),
    set: $ => seq('#{', repeat($._element), '}'),
    dictionary: $ => seq(
      '{',
      repeat(
        seq(
          field("key", $._element),
          field("value", $._element),
        ),
      ),
      '}'
    ),

    string: _ => token(seq(
      /[rbf]{0,3}/,
      '"',
      /[^"]*/,
      '"'
    )),
    bracket_string: _ => token(seq('#[[', /[^\]]*/, ']]')),

    integer: $ => choice($._decinteger, $._bininteger, $._octinteger, $._hexinteger),
    float: _ => token(prec(1, seq(
      optional(/[+-]/),
      choice(pointfloat, exponentfloat, 'Inf', 'NaN'),
    ))),
    complex: _ => token(prec(1, seq(
      optional(/[+-]/),
      choice(pointfloat, exponentfloat, digitpart, 'Inf', 'NaN'),
      /[+-]/,
      seq(
        choice(pointfloat, exponentfloat, digitpart, 'NaN', 'Inf'),
        /[jJ]/,
      ),
    ))),

    _decinteger: _ => token(prec(1, seq(optional(/[+-]/), /\d/, repeat(/[,_]*\d+/)))),
    _bininteger: _ => token(prec(1, seq('0', /[bB]/, repeat(/[,_]*[01]+/)))),
    _octinteger: _ => token(prec(1, seq('0', /[oO]/, repeat(/[,_]*[0-7]+/)))),
    _hexinteger: _ => token(prec(1, seq('0', /[xX]/, repeat(/[,_]*[\da-fA-F]+/)))),
  }
});

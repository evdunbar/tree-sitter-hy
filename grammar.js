/**
 * @file Hy grammar for tree-sitter
 * @author E Dunbar <evdunbar@protonmail.com>
 * @license MIT
 */

/// <reference types="tree-sitter-cli/dsl" />
// @ts-check

const regexp = {
  ascii_whitespace: /[\u0009\u000A\u000B\u000C\u000D\u0020]/,
}
const plus_minus = choice('+', '-')
const digitpart = seq(/\d/, repeat(/_*\d+/))
const pointfloat = choice(
  seq(optional(digitpart), '.', digitpart),
  seq(digitpart, '.'),
)
const exponentfloat = seq(
  choice(digitpart, pointfloat),
  seq(choice('e', 'E'), optional(plus_minus), digitpart),
)

module.exports = grammar({
  name: 'hy',

  extras: $ => [
    regexp.ascii_whitespace,
    $.comment,
  ],

  word: $ => $.symbol,

  rules: {
    // SYNTACTIC ELEMENTS
    source_file: $ => seq(optional($.shebang), repeat($._element)),

    shebang: _ => token(seq('#!', /.*/)),
    _element: $ => choice(
      $._form,
      $.discard,
      $.comment,
      $.import,
      $.require,
      $.function,
      $.lambda,
      $.class,
      $.macro,
      $.reader,
      $.py,
    ),

    _form: $ => seq(optional($.sugar), choice($._identifier, $._sequence, $._string)),
    discard: $ => seq('#_', $._form),
    comment: _ => token(seq(';', /.*/)),

    sugar: _ => choice(
      '\'',
      '`',
      '~',
      '~@',
      '#*',
      '#**',
    ),
    _identifier: $ => choice(
      $._numeric_literal,
      $.keyword,
      $._symbol_or_dots,
      $.dotted_identifier,
    ),
    _sequence: $ => choice($.expression, $.list, $.tuple, $.set, $.dictionary),
    _string: $ => choice($.string, $.bracket_string),

    _numeric_literal: $ => choice($.integer, $.float, $.complex),
    keyword: $ => prec.right(seq(
      ':',
      optional($.immediate_symbol),
    )),
    _symbol_or_dots: $ => choice(
      $.symbol,
      $.dots,
    ),
    dotted_identifier: $ => choice(
      seq(
        /[.]+/,
        $.immediate_symbol,
        repeat(seq(token.immediate('.'), $.immediate_symbol)),
      ),
      seq(
        field("sym", $.symbol),
        repeat1(seq(token.immediate('.'), $.immediate_symbol))),
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

    string: _ => seq(
      /[rbf]*"/,
      field("content", /[^"]*/),
      '"'
    ),
    bracket_string: _ => seq(
      '#[[',
      field("content", /[^\]]*/),
      ']]'
    ),

    integer: $ => choice($._decinteger, $._bininteger, $._octinteger, $._hexinteger),
    float: _ => token(prec(1, seq(
      optional(plus_minus),
      choice(pointfloat, exponentfloat, 'Inf', 'NaN'),
    ))),
    complex: _ => token(prec(1, seq(
      optional(plus_minus),
      choice(pointfloat, exponentfloat, digitpart, 'Inf', 'NaN'),
      plus_minus,
      seq(
        choice(pointfloat, exponentfloat, digitpart, 'NaN', 'Inf'),
        choice('j', 'J'),
      ),
    ))),

    symbol: _ => token(seq(
      /[^()\[\]{};"'`~:.\d\u0009\u000A\u000B\u000C\u000D\u0020]/,
      repeat(/[^()\[\]{};"'`~.\u0009\u000A\u000B\u000C\u000D\u0020]/),
    )),
    immediate_symbol: _ => token.immediate(seq(
      /[^()\[\]{};"'`~:.\d\u0009\u000A\u000B\u000C\u000D\u0020]/,
      repeat(/[^()\[\]{};"'`~.\u0009\u000A\u000B\u000C\u000D\u0020]/),
    )),
    dots: _ => /[.]+/,

    _decinteger: _ => token(prec(1, seq(optional(plus_minus), /\d/, repeat(/[,_]*\d+/)))),
    _bininteger: _ => token(prec(1, seq('0', /[bB]/, repeat(/[,_]*[01]+/)))),
    _octinteger: _ => token(prec(1, seq('0', /[oO]/, repeat(/[,_]*[0-7]+/)))),
    _hexinteger: _ => token(prec(1, seq('0', /[xX]/, repeat(/[,_]*[\da-fA-F]+/)))),

    // STRUCTURED SYNTAX
    import: $ => seq(
      '(',
      'import',
      repeat1(
        choice(
          $.module_import,
          $.named_import,
        ),
      ),
      ')'
    ),
    require: $ => seq(
      '(',
      'require',
      repeat1(
        choice(
          $.module_import,
          $.named_import,
          $.namespace_require,
        ),
      ),
      ')'
    ),
    function: $ => seq(
      '(',
      'defn',
      optional(
        seq(
          ':',
          token.immediate('async'),
        )
      ),
      field('decorators', optional($.variable_list)),
      optional($.type_parameters),
      optional($.type_annotation),
      field('name', $.symbol),
      $.parameter_list,
      repeat($._element),
      ')',
    ),
    lambda: $ => seq(
      '(',
      'fn',
      optional(
        seq(
          ':',
          token.immediate('async'),
        )
      ),
      $.parameter_list,
      repeat($._element),
      ')',
    ),
    class: $ => seq(
      '(',
      'defclass',
      field('decorators', optional($.variable_list)),
      optional($.type_parameters),
      field('name', $.symbol),
      field('superclasses', $.variable_list),
      repeat($._element),
      ')',
    ),
    macro: $ => seq(
      '(',
      'defmacro',
      field('name', $.symbol),
      $.parameter_list,
      repeat($._element),
      ')',
    ),
    reader: $ => seq(
      '(',
      'defreader',
      field('name', $.symbol),
      repeat($._element),
      ')',
    ),
    py: $ => seq(
      '(',
      choice('py', 'pys'),
      '"',
      $.code,
      '"',
      ')',
    ),

    module_import: $ => seq(
      choice(
        seq($._variable, optional('*')),
        $.aliased_import,
      ),
    ),
    named_import: $ => seq(
      $._variable,
      seq(
        '[',
        repeat1(
          choice(
            $.symbol,
            $.aliased_import,
          ),
        ),
        ']',
      ),
    ),
    namespace_require: $ => seq(
      $._variable,
      choice(
        repeat1(
          seq(
            ':',
            choice(
              token.immediate('macros'),
              token.immediate('readers'),
            ),
            '[',
            repeat1(
              choice(
                $.symbol,
                $.aliased_import,
              ),
            ),
            ']',
          ),
        ),
        seq(
          $.keyword,
          '*',
        ),
      ),
    ),

    variable_list: $ => seq(
      '[',
      repeat1($._variable),
      ']',
    ),
    type_parameters: $ => seq(
      ':',
      token.immediate('tp'),
      '[',
      repeat1($._variable),
      ']',
    ),
    type_annotation: $ => seq(
      '#^',
      field('type', $._variable),
    ),
    parameter_list: $ => seq(
      '[',
      repeat(
        choice(
          $.symbol,
          seq(
            '[',
            $.symbol,
            $._form,
            ']',
          ),
          '/',
          '*',
          '#*',
          '#**',
        ),
      ),
      ']',
    ),

    code: _ => /[^"]*/,

    _variable: $ => choice(
      $.symbol,
      $.dotted_identifier,
    ),

    aliased_import: $ => seq(
      $._variable,
      ':',
      token.immediate('as'),
      $.symbol,
    ),
  }
});

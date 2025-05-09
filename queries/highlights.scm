; Variables
(symbol) @variable

(keyword) @property

; Symbol naming conventions
((symbol) @type
  (#lua-match? @type "^[A-Z].*[a-z]"))

((symbol) @constant
  (#lua-match? @constant "^[A-Z][A-Z0-9_-]*$"))

((symbol) @constant.builtin
  (#lua-match? @constant.builtin "^__[a-zA-Z0-9_-]*__$"))

((symbol) @constant.builtin
  (#any-of? @constant.builtin
    ; https://docs.python.org/3/library/constants.html
    "NotImplemented" "Ellipsis" "quit" "exit" "copyright" "credits" "license" "..."))

((symbol) @character.special
  (#eq? @character.special "_"))

; Function calls
(expression
  .
  (symbol) @function.call)

(expression
  .
  (dotted_identifier) @function.method.call)

;Function definitions
(expression
  .
  (symbol) @keyword.function
  (symbol) @function
  .
  (list
    (symbol)* @parameter)
  (#any-of? @keyword.function "defn" "defmacro"))

(expression
  .
  (symbol) @keyword.function
  .
  (list
    (symbol)* @parameter)
  (#any-of? @keyword.function "fn" "defreader"))

; Literals
((symbol) @constant.builtin
  (#eq? @constant.builtin "None"))

((symbol) @boolean
  (#any-of? @boolean "True" "False"))

[
  (integer)
  (complex)
] @number

(float) @number.float

[
  (string)
  (bracket_string)
] @string

(shebang) @keyword.directive

[
  (comment)
  (discard)
] @comment

; Keywords
(expression
  .
  (symbol) @keyword.operator
  (#any-of? @keyword.operator "and" "in" "is" "not" "or" "del" "is-not" "not-in"))

((symbol) @keyword
  (#any-of? @keyword "assert" "exec" "global" "nonlocal" "pass" "print" "with" "as"))

((symbol) @keyword.type
  (#eq? @keyword.type "type"))

((symbol) @keyword.coroutine
  (#eq? @keyword.coroutine "await"))

((symbol) @keyword.return
  (#any-of? @keyword.return "return" "yield"))

(expression
  .
  (symbol) @keyword.import
  .
  [
    (symbol)
    (dotted_identifier)
  ] @module
  ((keyword) @keyword
    .
    (symbol) @module
    (#eq? @keyword ":as"))?
  (#any-of? @keyword.import "import" "require"))

((symbol) @keyword.conditional
  (#any-of? @keyword.conditional "if" "when" "cond" "else" "match" "chainc"))

((symbol) @keyword.repeat
  (#any-of? @keyword.repeat "for" "while" "break" "continue" "lfor" "dfor" "gfor" "sfor"))

((symbol) @keyword.exception
  (#any-of? @keyword.exception "raise" "try"))

; Classes
(expression
  .
  (symbol) @keyword.type
  .
  (symbol) @type
  (#eq? @keyword.type "defclass"))

((symbol) @variable.builtin
  (#eq? @variable.builtin "self"))

(expression
  .
  (symbol) @_dot
  .
  (_)
  .
  (symbol) @variable.member
  (#eq? @_dot "."))

; Builtin functions
(expression
  .
  (symbol) @function.builtin
  (#any-of? @function.builtin
    "abs" "all" "any" "ascii" "bin" "bnot" "bool" "breakpoint" "bytearray" "bytes" "callable" "chr"
    "classmethod" "compile" "complex" "delattr" "dict" "dir" "divmod" "enumerate" "eval" "exec"
    "filter" "float" "format" "frozenset" "getattr" "globals" "hasattr" "hash" "help" "hex" "id"
    "input" "int" "isinstance" "issubclass" "iter" "len" "list" "locals" "map" "max" "memoryview"
    "min" "next" "object" "oct" "open" "ord" "pow" "print" "property" "range" "repr" "reversed"
    "round" "set" "setattr" "slice" "sorted" "staticmethod" "str" "sum" "super" "tuple" "type"
    "vars" "zip" "__import__"))

; Builtin macros
(expression
  .
  (symbol) @function.macro
  (#any-of? @function.macro
    "do" "do-mac" "eval-and-compile" "eval-when-compile" "py" "pys" "pragma" "quote" "quasiquote"
    "unquote" "unquote-splice" "setv" "setx" "let" "global" "nonlocal" "del" "annotate" "deftype"
    "." "unpack-iterable" "unpack-mapping" "with" "get-macro" "local-macros" "export" "get" "cut"
    "assert"))

; Tokens
((symbol) @operator
  (#any-of? @operator
    "-" "-=" "!=" "*" "**" "**=" "*=" "/" "//" "//=" "/=" "&" "&=" "%" "%=" "^" "^=" "+" "+=" "<"
    "<<" "<<=" "<=" "<>" "=" ">" ">=" ">>" ">>=" "@" "@=" "|" "|="))

[
  "#("
  "("
  ")"
  "["
  "]"
  "#{"
  "{"
  "}"
] @punctuation.bracket

[
  "'"
  "`"
  "~"
  "~@"
  "#*"
  "#**"
] @function.macro

(dotted_identifier
  "." @punctuation.delimiter)

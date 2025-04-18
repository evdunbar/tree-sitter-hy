; highlights.scm

; identifiers
(symbol) @variable

; literals
(string) @string
(bracket_string) @string
(integer) @number
(complex) @number
(float) @number.float

; types
(keyword) @property

; functions

; keywords
(shebang) @keyword.directive

; punctuation
(dotted_identifier "." @punctuation.delimiter)
["(" ")" "[" "]" "{" "}"] @punctuation.bracket

; comments
(comment) @comment

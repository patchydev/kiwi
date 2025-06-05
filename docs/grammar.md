# Kiwi Grammar

```
program := statement*

statement := variable_declaration
           | function_declaration
           | return_statement

variable_declaration := "let" identifier ":" type "=" expression ";"

function_declaration := "fn" identifier "(" parameter_list? ")" "->" type block

parameter_list := parameter ("," parameter)*

parameter := identifier ":" type

block := "{" statement* "}"

return_statement := "return" expression ";"

expression := additive_expression

additive_expression := multiplicative_expression (("+" | "-") multiplicative_expression)*

multiplicative_expression := primary_expression (("*" | "/") primary_expression)*

primary_expression := number | identifier | "(" expression ")"

type := "i32" | "TODO"

identifier := letter (letter | digit)*

number := digit+
```

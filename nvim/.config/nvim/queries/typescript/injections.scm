; extends

; Match calls like this.knex.raw(`...`) or knex.raw("...")
(call_expression
  function: [(await_expression) (member_expression)] @exp
  arguments: (arguments [
    (template_string (string_fragment) @injection.content)
  ])
  (#contains? @exp ".raw")
  (#set! injection.language "sql")
)


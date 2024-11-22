; extends

; this.knex.raw(`...`)
(call_expression
  function: [(await_expression) (member_expression)] @exp
  arguments: (arguments [
   (template_string (string_fragment) @injection.content)
   (string (string_fragment) @injection.content)
   ])
  (#contains? @exp ".raw")
  (#set! injection.language "sql")
  ; can do without this, but sort of prevents ugly highlighting in some cases
  (#match? @injection.content "(SELECT|INSERT|UPDATE|DELETE|select|insert|update|delete).+(FROM|INTO|VALUES|SET|from|into|values|set).*(WHERE|GROUP BY|where|group by)?")
)

(
    [
        (string_fragment)
    ] @injection.content
    (#match? @injection.content "(SELECT|INSERT|UPDATE|DELETE|select|insert|update|delete).+(FROM|INTO|VALUES|SET|from|into|values|set).*(WHERE|GROUP BY|where|group by)?")
    (#set! injection.language "sql")
)

(
    [
        (template_string)
    ] @injection.content
    (#match? @injection.content "(SELECT|INSERT|UPDATE|DELETE|select|insert|update|delete).+(FROM|INTO|VALUES|SET|from|into|values|set).*(WHERE|GROUP BY|where|group by)?")
    (#offset! @injection.content 0 1 0 -1)
    (#set! injection.language "sql")
)


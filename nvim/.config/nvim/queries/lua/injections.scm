; extends

;; For any table which has filetype key and query key, apply filetype value as query language
(table_constructor
    (field
      name: (identifier) @filetype_key (#eq? @filetype_key "filetype")
      value: (string
        (string_content) @injection.language))
    (field
      name: (identifier) @query_key (#eq? @query_key "query")
      value: (string
        (string_content) @injection.content))
)



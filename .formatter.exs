locals_without_parens = [defchart: 1, defchart: 2, defstate: 1, defstate: 2]

[
  import_deps: [:typed_struct, :stream_data],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: locals_without_parens,
  export: [locals_without_parens: locals_without_parens]
]

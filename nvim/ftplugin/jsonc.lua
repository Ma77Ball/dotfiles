-- JSONC buffers: <leader>cf pretty-prints the WHOLE file into a read-only scratch
-- split. Note: jq rejects // comments / trailing commas, so expansion works on
-- comment-free JSONC; you'll get a jq error notification otherwise. Non-destructive.
require("json_expand").map("buffer")

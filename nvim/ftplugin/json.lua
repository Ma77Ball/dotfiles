-- JSON buffers: <leader>cf pretty-prints the WHOLE file into a read-only scratch
-- split (a single document, unlike jsonl's one-object-per-line). Non-destructive
-- view; conform's format_on_save still formats the file itself on :w.
require("json_expand").map("buffer")

-- JSONL buffers: <leader>cf pretty-prints the record UNDER THE CURSOR into a
-- read-only scratch split, so you can read a 40K-char line without touching the
-- file on disk (the pipeline reads it strictly one-object-per-line; see
-- agent/src/server.ts writer + pipeline/tasks.py reader). Compacting still
-- happens on :w via conform's format_on_save (jqlines), keeping the file valid.
require("json_expand").map("line")

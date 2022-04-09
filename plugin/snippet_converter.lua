local snippet_converter = require("snippet_converter")

vim.api.nvim_add_user_command("ConvertSnippets", function(result)
  snippet_converter.convert_snippets(result.fargs)
end, { nargs = "*" })
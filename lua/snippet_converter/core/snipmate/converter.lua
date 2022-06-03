local NodeType = require("snippet_converter.core.node_type")
local base_converter = require("snippet_converter.core.converter")
local err = require("snippet_converter.utils.error")
local io = require("snippet_converter.utils.io")
local export_utils = require("snippet_converter.utils.export_utils")

local M = {
  node_visitor = {},
}

local create_node_visitor = function(opts)
  return {
    [NodeType.TRANSFORM] = function(node)
      return ("/%s/%s/%s"):format(node.regex, node.replacement, node.options)
    end,
    -- TODO: support Filename() inside ``
    [NodeType.VIMSCRIPT_CODE] = function(node)
      -- LuaSnip does not support VimScript code
      if opts.flavor == "luasnip" then
        err.raise_converter_error(NodeType.to_string(node.type))
      end
      return ("`%s`"):format(node.code)
    end,
    [NodeType.TEXT] = function(node)
      -- Escape ambiguous chars and backslashes
      return node.text:gsub([[\]], [[\\]]):gsub("%$", "\\%$"):gsub("`", "\\`")
    end,
  }
end

M.convert = function(snippet, opts)
  opts = opts or {}
  if snippet.options and snippet.options:match("r") then
    err.raise_converter_error("regex trigger")
  end
  local description = ""
  if snippet.description then
    -- Replace newline characters with spaces and remove trailing whitespace
    description = " " .. snippet.description:gsub("\n", " "):gsub("%s*$", "")
  end
  M.node_visitor = create_node_visitor(opts)
  M.visit_node = setmetatable(M.node_visitor, { __index = base_converter.visit_node(M.node_visitor) })

  local body = base_converter.convert_ast(snippet.body, M.visit_node)
  -- Prepend a tab to every line
  body = body:gsub("\n", "\n\t")
  -- LuaSnip supports snippet priorities
  local priority = opts.flavor == "luasnip"
      and snippet.priority
      and ("priority %s\n"):format(snippet.priority)
    or ""
  return string.format("%ssnippet %s%s\n\t%s", priority, snippet.trigger, description, body)
end

local HEADER_STRING =
  "# Generated by snippet-converter.nvim (https://github.com/smjonas/snippet-converter.nvim)"

-- Takes a list of converted snippets for a particular filetype,
-- separates them by newlines and exports them to a file.
-- @param converted_snippets string[] @A list of snippet tables where each item is a snippet table to be exported
-- @param filetype string @The filetype of the snippets
-- @param output_dir string @The absolute path to the directory to write the snippets to
M.export = function(converted_snippets, filetype, output_path)
  local snippet_lines = export_utils.snippet_strings_to_lines(
    converted_snippets,
    "",
    { HEADER_STRING, "" },
    nil
  )
  output_path = ("%s/%s.%s"):format(output_path, filetype, "snippets")
  io.write_file(snippet_lines, output_path)
  return output_path
end

return M

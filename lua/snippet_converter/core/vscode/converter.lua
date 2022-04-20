local M = {}

local NodeType = require("snippet_converter.core.node_type")
local base_converter = require("snippet_converter.core.converter")
local err = require("snippet_converter.utils.error")
local io = require("snippet_converter.utils.io")
local tbl = require("snippet_converter.utils.table")
local export_utils = require("snippet_converter.utils.export_utils")
local json_utils = require("snippet_converter.utils.json_utils")

M.node_visitor = {
  [NodeType.TABSTOP] = function(node)
    if not node.transform then
      return "$" .. node.int
    end
    return ("${%s/%s}"):format(node.int, M.node_visitor[NodeType.TRANSFORM](node.transform))
  end,
  [NodeType.TRANSFORM] = function(node)
    -- Can currently only convert VSCode to VSCode regex
    if node.regex_kind ~= NodeType.RegexKind.JAVASCRIPT then
      err.raise_converter_error(
        NodeType.RegexKind.to_string(node.regex_kind) .. " regex in transform node"
      )
    end
    -- ASCII conversion option
    if node.options:match("a") then
      err.raise_converter_error("option 'a' (ascii conversion) in transform node")
    end
    -- Only g, i and m options are valid - ignore the rest
    local converted_options = node.options:gsub("[^gim]", "")

    local replacements = {}
    for i, replacement in pairs(replacements) do
      -- Text or format nodes
      replacements[i] = M.node_visitor[replacement.type](replacement)
    end
    return ("%s/%s/%s"):format(node.regex, table.concat(replacements), converted_options)
  end,
  [NodeType.FORMAT] = function(node)
    if not node.format_modifier then
      return "$" .. node.int
    end
    -- TODO: handle if / else
    return ("${%s:/}"):format(node.format_modifier)
  end,
  [NodeType.VISUAL_PLACEHOLDER] = function(_)
    err.raise_converter_error(NodeType.to_string(NodeType.VISUAL_PLACEHOLDER))
  end,
  [NodeType.TEXT] = function(node)
    -- Escape '$' and '}' characters (see https://code.visualstudio.com/docs/editor/userdefinedsnippets#_grammar)
    return node.text:gsub("[%$}]", "\\%1")
  end,
}

M.visit_node = setmetatable(M.node_visitor, {
  __index = base_converter.visit_node(M.node_visitor),
})

---Creates package.json file contents as expected by VSCode and Luasnip.
---@name string the name that will be added at the top of the output
---@filetypes array an array of filetypes that determine the path attribute
---@return string the generated string to be written
local get_package_json_string = function(name, filetypes)
  local snippets = {}
  for i, filetype in ipairs(filetypes) do
    snippets[i] = {
      language = filetype,
      path = ("./%s.json"):format(filetype),
    }
  end
  local package_json = {
    name = name,
    description = "Generated by snippet-converter.nvim (https://github.com/smjonas/snippet-converter.nvim)",
    contributes = {
      snippets = snippets,
    },
  }
  return json_utils:pretty_print(
    package_json,
    { { "name", "description", "contributes" }, { "language", "path" } },
    true
  )
end

--TODO: from UltiSnips: $VISUAL with transform
M.convert = function(snippet, visit_node)
  if snippet.options and snippet.options:match("r") then
    err.raise_converter_error("regex trigger")
  end
  -- Prepare snippet for export
  snippet.body = vim.split(
    base_converter.convert_ast(snippet.body, visit_node or M.visit_node),
    "\n"
  )
  if #snippet.body == 1 then
    snippet.body = snippet.body[1]
  end
  snippet.scope = snippet.scope and table.concat(snippet.scope, ",")
  return snippet
end

-- Takes a list of converted snippets for a particular filetype and exports them to a JSON file.
-- @param converted_snippets table[] @A list of strings where each item is a snippet string to be exported
-- @param filetype string @The filetype of the snippets
-- @param output_dir string @The absolute path to the directory to write the snippets to
M.export = function(converted_snippets, filetype, output_path, _)
  local table_to_export = {}
  local order = { [1] = {}, [2] = { "prefix", "description", "scope", "body" } }
  for i, snippet in ipairs(converted_snippets) do
    local key = snippet.name or snippet.trigger
    order[1][i] = key
    -- Ignore any other fields
    table_to_export[key] = {
      prefix = snippet.trigger,
      description = snippet.description,
      scope = snippet.scope,
      body = snippet.body,
    }
  end
  local output_string = json_utils:pretty_print(table_to_export, order, true)
  output_path = export_utils.get_output_file_path(output_path, filetype, "json")
  io.write_file(vim.split(output_string, "\n"), output_path)
end

-- @param context []? @A table of additional snippet contexts optionally provided the source parser (e.g. extends directives from UltiSnips)
M.post_export = function(template, filetypes, output_path, context)
  -- print(vim.inspect(filetypes))
  local json_string = get_package_json_string(
    ("%s-snippets"):format(template.name),
    tbl.concat_arrays(filetypes, context.include_filetypes or {})
  )
  local lines = export_utils.snippet_strings_to_lines { json_string }
  -- print(io.get_containing_folder(output_path) .. "/package.json")
  io.write_file(lines, io.get_containing_folder(output_path) .. "/package.json")
end

return M

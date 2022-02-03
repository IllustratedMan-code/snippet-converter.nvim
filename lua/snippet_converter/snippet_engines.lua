local snippet_engines = {}

-- Contains a list of features that a snippet-engine may support.
-- If the target engine also supports that capability, the snippet
-- can be converted.
local capabilities = {
  VIMSCRIPT_INTERPOLATION = 1,
}

snippet_engines.capabilities = capabilities

snippet_engines.snipmate = {
  label = "SnipMate",
  extension = "snippets",
  parser = "snippet_converter.core.snipmate.parser",
  capabilities = {
    capabilities.VIMSCRIPT_INTERPOLATION,
  },
}

snippet_engines.ultisnips = {
  label = "UltiSnips",
  extension = "snippets",
  parser = "snippet_converter.core.ultisnips.parser",
  converter = "snippet_converter.core.ultisnips.converter",
}

snippet_engines.vscode = {
  label = "VSCode",
  extension = "json",
  parser = "snippet_converter.core.vscode.parser",
  converter = "snippet_converter.core.vscode.converter",
}

return snippet_engines

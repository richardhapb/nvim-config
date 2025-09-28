local plugins = { 'FormatDicts', 'LatexPreview', 'marp', 'mermaid', 'sqlquery', 'jn_watcher', "executor", "copilot",
  "aligner", "fuzzy", "autocompletion" }

for _, plugin in ipairs(plugins) do
  require('plugin.' .. plugin).setup()
end

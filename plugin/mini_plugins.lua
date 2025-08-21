local plugins = { 'FormatDicts', 'LatexPreview', 'marp', 'mermaid', 'sqlquery', 'jn_watcher', "executor", "copilot", "aligner" }

for _, plugin in ipairs(plugins) do
   require('plugin.' .. plugin).setup()
end


local plugins = { 'FormatDicts', 'LatexPreview', 'marp', 'mermaid', 'sqlquery' }

for _, plugin in ipairs(plugins) do
   require('plugin.' .. plugin).setup()
end


local plugins = { 'FormatDicts', 'LatexPreview', 'marp', 'mermaid', 'sqlquery', 'neospeller' }

for _, plugin in ipairs(plugins) do
   require('plugin.' .. plugin).setup()
end


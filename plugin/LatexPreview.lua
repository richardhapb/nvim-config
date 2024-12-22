
local function get_tex_path()
    local file_path = vim.fn.expand('%:p')
    local file_name = vim.fn.fnamemodify(file_path, ':t:r')
    return file_name .. '.tex'
end


vim.api.nvim_create_user_command('LatexBuild', '!xelatex % -output-directory=build', {})
vim.api.nvim_create_user_command('LatexPreview', function()
   local tex_path = get_tex_path()
   vim.fn.system('tmux new-session -d -s texpresso "texpresso ' .. tex_path .. '"')
end, {})
vim.api.nvim_create_user_command('LatexShutdown', function()
   vim.fn.system('tmux kill-session -t texpresso')
end, {})

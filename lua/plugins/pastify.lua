return {
   'TobinPalmer/pastify.nvim',
   cmd = { 'Pastify', 'PastifyAfter' },
   event = { 'BufReadPost' },
       keys = {
           {noremap = true, mode = "x", '<leader>p', "<cmd>PastifyAfter<CR>"},
           {noremap = true, mode = "n", '<leader>p', "<cmd>PastifyAfter<CR>"},
           {noremap = true, mode = "n", '<leader>P', "<cmd>Pastify<CR>"},
       },
   config = function()
      require('pastify').setup {
         opts = {
            absolute_path = false,
            apikey = '',
            local_path = '/assets/',
            save = 'local',
            filename = '',
            default_ft = 'markdown',
         },
         ft = {
            html = '<img src="$IMG$" alt="">',
            markdown = '![]($IMG$)',
            tex = [[\includegraphics[width=\linewidth]{$IMG$}]],
            css = 'background-image: url("$IMG$");',
            js = 'const img = new Image(); img.src = "$IMG$";',
            xml = '<image src="$IMG$" />',
            php = '<?php echo "<img src=\"$IMG$\" alt=\"\">"; ?>',
            python = '# $IMG$',
            java = '// $IMG$',
            c = '// $IMG$',
            cpp = '// $IMG$',
            swift = '// $IMG$',
            kotlin = '// $IMG$',
            go = '// $IMG$',
            typescript = '// $IMG$',
            ruby = '# $IMG$',
            vhdl = '-- $IMG$',
            verilog = '// $IMG$',
            systemverilog = '// $IMG$',
            lua = '-- $IMG$',
         },
      }
   end
}

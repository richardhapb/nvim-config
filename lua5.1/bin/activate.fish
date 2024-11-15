if functions -q deactivate-lua
    deactivate-lua
end

function deactivate-lua
    if test -x '/Users/richard/.config/nvim/lua5.1/bin/lua'
        eval ('/Users/richard/.config/nvim/lua5.1/bin/lua' '/Users/richard/.config/nvim/lua5.1/bin/get_deactivated_path.lua' --fish)
    end

    functions -e deactivate-lua
end

set -gx PATH '/Users/richard/.config/nvim/lua5.1/bin' $PATH

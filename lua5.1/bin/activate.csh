which deactivate-lua >&/dev/null && deactivate-lua

alias deactivate-lua 'if ( -x '\''/Users/richard/.config/nvim/lua5.1/bin/lua'\'' ) then; setenv PATH `'\''/Users/richard/.config/nvim/lua5.1/bin/lua'\'' '\''/Users/richard/.config/nvim/lua5.1/bin/get_deactivated_path.lua'\''`; rehash; endif; unalias deactivate-lua'

setenv PATH '/Users/richard/.config/nvim/lua5.1/bin':"$PATH"
rehash

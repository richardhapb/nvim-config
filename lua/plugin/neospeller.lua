local M = {}

local function check_spell(range)
  local buffer = vim.api.nvim_get_current_buf()
  local full_text = { "" }
  local text = ""
  local offset = 0

  -- Verify if there is a selecion, if there is, use it, else use the whole buffer
  if range.count > 1 then
    full_text = vim.api.nvim_buf_get_lines(buffer, range.line1 - 1, range.line2, false)
    text = table.concat(full_text, "\n")
    offset = range.line1 - 1
  else
    full_text = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
    text = table.concat(full_text, "\n")
  end

  if vim.fn.executable("neospeller") == 0 then
    vim.print("neospeller is not installed")
    return
  end

  local command = "neospeller"

  local job = vim.fn.jobstart({ command }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      local decoded = vim.json.decode(table.concat(data, "\n"))
      decoded = decoded.choices[1].message.content
      decoded = vim.json.decode(decoded)

      if decoded.comments then
        local to_append = ""
        for lineno, comment in pairs(decoded.comments) do
          lineno = tonumber(lineno) - 1
          local current_line = full_text[lineno + 1]
          local col = current_line:find("#") or 0
          col = col + 1

          if to_append ~= "" then
            comment = comment .. " " .. to_append
            to_append = ""
          end

          -- If the line is not a comment, add a new line
          -- if has text before the comment, append the comment to the last comment
          if not current_line:find('^%s*#.*$') then
            local indent = full_text[lineno - 1]:match('^%s*')
            vim.api.nvim_buf_set_lines(buffer, offset + lineno, offset + lineno, false, { indent .. '# ' .. comment })
          elseif current_line:find('^[^%s]+#.*$') then
            to_append = comment
          else
            vim.api.nvim_buf_set_text(buffer, offset + lineno, col, offset + lineno, -1, { comment })
          end
        end
      end

      if decoded.ml_comments then
        local last = { lineno = -1, indent = "" }
        for lineno, ml_comment in pairs(decoded.ml_comments) do
          lineno = tonumber(lineno) - 1
          local indent = ""
          if last.lineno == lineno + 1 then
            indent = last.indent
          else
            indent = full_text[lineno + 1]:match('^%s*')
          end

          last = { lineno = lineno, indent = indent }

          if full_text[lineno + 1]:find('^%s*""".*"""$') then
            ml_comment = '"""' .. ml_comment .. '"""'
          end

          -- If the next line is a closing triple quote, add a new line
          local next_line = lineno + 1
          if full_text[lineno + 1]:find('^%s*"""$') then
            next_line = lineno
          end
          vim.api.nvim_buf_set_lines(buffer, offset + lineno, offset + next_line, false, { indent .. ml_comment })
        end
      end
    end,
  })

  vim.fn.chansend(job, text)

  vim.fn.chanclose(job, "stdin")
end

M.setup = function()
  -- Accept a range
  vim.api.nvim_create_user_command('CheckSpell', function(range)
    check_spell(range)
  end, {
    range = 1,
  })
end

return M

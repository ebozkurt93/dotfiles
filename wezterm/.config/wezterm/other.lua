local wezterm = require 'wezterm'

local M = {}

-- attempt to attach to tmux session if session exists
function M.default_prog()
  local tmux_path = os.getenv("HOME") .. "/.nix-profile/bin/tmux"
  local has_tmux_session, _, _ = wezterm.run_child_process({ tmux_path, "has-session" })
  if has_tmux_session then
    return { tmux_path, "attach-session" }
  else
    return nil
  end
end

return M

-- Large file optimizations
-- Automatically applied for files >= M.config.size_threshold bytes
-- Can also be toggled manually with :LargeFile / :LargeFileOff

local M = {}

M.config = {
  size_threshold = 2 * 1024 * 1024, -- 2 MB; change with :LargeFileThreshold <MB>
}

local applied = {}

local function get_file_size(bufnr)
  local ok, stat = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(bufnr))
  if ok and stat then return stat.size end
  return 0
end

local function apply(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if vim.b[bufnr].large_file then return end
  vim.b[bufnr].large_file = true
  vim.b[bufnr].bigfile_disabled = nil

  local bo = vim.bo[bufnr]

  -- Binary mode: skips encoding conversion, BOM detection, EOL normalization
  bo.binary     = true
  bo.syntax     = "off"
  bo.synmaxcol  = 128
  bo.undofile   = false
  bo.undolevels = -1
  bo.swapfile   = false
  bo.bufhidden  = "unload"
  bo.matchpairs = ""

  -- Update all windows showing this buffer
  for _, winid in ipairs(vim.fn.win_findbuf(bufnr)) do
    pcall(function()
      vim.wo[winid].spell = false
      vim.wo[winid][bufnr].foldmethod = "manual"
      vim.wo[winid][bufnr].foldexpr   = ""
    end)
  end

  -- Plugin detaches
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then return end

    local ok_ts, ts_hl = pcall(require, "nvim-treesitter.highlight")
    if ok_ts then pcall(ts_hl.detach, bufnr) end

    local ok_ts_i, ts_indent = pcall(require, "nvim-treesitter.indent")
    if ok_ts_i then pcall(ts_indent.detach, bufnr) end

    -- Re-apply fold suppression for safety
    for _, winid in ipairs(vim.fn.win_findbuf(bufnr)) do
      pcall(function()
        vim.wo[winid][bufnr].foldmethod = "manual"
        vim.wo[winid][bufnr].foldexpr   = ""
      end)
    end

    for _, client in pairs(vim.lsp.get_active_clients({ bufnr = bufnr })) do
      vim.lsp.buf_detach_client(bufnr, client.id)
    end

    local ok_ufo, ufo = pcall(require, "ufo")
    if ok_ufo then pcall(ufo.detach, bufnr) end

    local ok_ill, ill = pcall(require, "illuminate.engine")
    if ok_ill then pcall(ill.stop_buf, bufnr) end

    local ok_ibl, ibl = pcall(require, "ibl")
    if ok_ibl then pcall(ibl.setup_buffer, bufnr, { enabled = false }) end

    local ok_col, col = pcall(require, "colorizer")
    if ok_col then pcall(col.detach_from_buffer, bufnr) end

    local size_mb = get_file_size(bufnr) / 1024 / 1024
    vim.notify(
      string.format("Large file mode (%.0f MB) — binary, syntax, LSP, treesitter, folding, undo disabled.", size_mb),
      vim.log.levels.INFO,
      { title = "BigFile", timeout = 4000 }
    )
  end)
end

local function revert(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.b[bufnr].large_file then return end
  vim.b[bufnr].large_file = nil

  local bo = vim.bo[bufnr]
  bo.binary     = false
  bo.syntax     = "on"
  bo.synmaxcol  = 0
  bo.undofile   = true
  bo.undolevels = vim.go.undolevels
  bo.swapfile   = vim.go.swapfile
  bo.bufhidden  = ""

  -- Restore window-local settings
  for _, winid in ipairs(vim.fn.win_findbuf(bufnr)) do
    pcall(function()
      vim.wo[winid].spell = true
      vim.wo[winid][bufnr].foldmethod = "syntax"
      vim.wo[winid][bufnr].foldexpr = ""
    end)
  end

  -- Re-enable plugins
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then return end

    vim.api.nvim_buf_call(bufnr, function()
      vim.cmd("filetype detect")
    end)

    local ok_ufo, ufo = pcall(require, "ufo")
    if ok_ufo then pcall(ufo.attach, bufnr) end

    local ok_ill, ill = pcall(require, "illuminate.engine")
    if ok_ill then pcall(ill.stop_buf, bufnr) end

    local ok_ibl, ibl = pcall(require, "ibl")
    if ok_ibl then pcall(ibl.setup_buffer, bufnr, { enabled = true }) end

    local ok_col, col = pcall(require, "colorizer")
    if ok_col then pcall(col.attach_to_buffer, bufnr) end
  end)

  vim.notify(
    "Large file mode disabled. Folding and plugins restored.",
    vim.log.levels.INFO,
    { title = "BigFile", timeout = 4000 }
  )
end

function M.setup()
  vim.api.nvim_create_autocmd("BufReadPre", {
    group = vim.api.nvim_create_augroup("bigfile_detect", { clear = true }),
    desc = "Disable heavy features for large files before they load",
    callback = function(args)
      if vim.b[args.buf].bigfile_disabled then
        return
      end

      local is_big = get_file_size(args.buf) >= M.config.size_threshold
      if is_big then
        apply(args.buf)

        -- Suppress FileType autocmds during read so no syntax/indent plugin
        -- fires while Vim is reading the file into memory
        vim.opt.eventignore:append("FileType")
        vim.api.nvim_create_autocmd("BufReadPost", {
          buffer = args.buf,
          once = true,
          callback = function()
            vim.opt.eventignore:remove("FileType")
            vim.bo[args.buf].filetype = ""
          end,
        })
      elseif vim.b[args.buf].large_file then
        revert(args.buf)
      end
    end,
  })

  -- Re-apply fold suppression when buffer enters a window (plugins may reset it)
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = vim.api.nvim_create_augroup("bigfile_win_enter", { clear = true }),
    desc = "Re-apply fold suppression for large-file buffers",
    callback = function(args)
      local bufnr = args.buf
      if not vim.b[bufnr].large_file then return end
      local wid = vim.api.nvim_get_current_win()
      local ok2, wo2 = pcall(function() return vim.wo[wid][bufnr] end)
      if ok2 and wo2 then
        pcall(function() wo2.foldmethod = "manual" end)
        pcall(function() wo2.foldexpr   = "" end)
      else
        pcall(vim.api.nvim_win_set_option, wid, "foldmethod", "manual")
        pcall(vim.api.nvim_win_set_option, wid, "foldexpr",   "")
      end
    end,
  })

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("bigfile_lsp_guard", { clear = true }),
    desc = "Detach LSP from large files",
    callback = function(args)
      if vim.b[args.buf] and vim.b[args.buf].large_file then
        vim.lsp.buf_detach_client(args.buf, args.data.client_id)
      end
    end,
  })

  vim.api.nvim_create_user_command("LargeFile", function()
    local bufnr = vim.api.nvim_get_current_buf()
    vim.b[bufnr].bigfile_disabled = nil
    apply(bufnr)
  end, { desc = "Enable large-file optimisations for current buffer" })

  vim.api.nvim_create_user_command("LargeFileOff", function()
    local bufnr = vim.api.nvim_get_current_buf()
    vim.b[bufnr].bigfile_disabled = true
    revert(bufnr)
  end, { desc = "Disable large-file optimisations for current buffer" })

  vim.api.nvim_create_user_command("LargeFileThreshold", function(opts)
    local mb = tonumber(opts.args)
    if not mb then
      vim.notify(
        string.format("Current threshold: %.1f MB", M.config.size_threshold / 1024 / 1024),
        vim.log.levels.INFO,
        { title = "BigFile" }
      )
      return
    end
    M.config.size_threshold = mb * 1024 * 1024
    vim.notify(
      string.format("Large-file threshold set to %.1f MB", mb),
      vim.log.levels.INFO,
      { title = "BigFile" }
    )

    -- Re-evaluate current buffer
    local bufnr = vim.api.nvim_get_current_buf()
    if not vim.b[bufnr].bigfile_disabled then
      if get_file_size(bufnr) >= M.config.size_threshold then
        apply(bufnr)
      elseif vim.b[bufnr].large_file then
        revert(bufnr)
      end
    end
  end, {
    nargs = "?",
    desc = "Get/set large-file threshold in MB (e.g. :LargeFileThreshold 1024)",
  })
end

return M

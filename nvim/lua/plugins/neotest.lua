-- Neotest progress notifications: "Running N tests…" at start, then a pass/fail summary.
-- (LazyVim's test.core extra provides neotest; this only adds a consumer.)

-- position_ids can overlap (a folder and the files in it), so count unique test ids.
local function count_tests(tree, ids)
  local seen, n = {}, 0
  for _, id in ipairs(ids) do
    local node = tree:get_key(id)
    if node then
      for _, pos in node:iter() do
        if pos.type == "test" and not seen[pos.id] then
          seen[pos.id], n = true, n + 1
        end
      end
    end
  end
  return n
end

---@type neotest.Consumer
local function progress(client)
  local started = {}

  client.listeners.run = function(adapter_id, _, position_ids)
    local tree = client:get_position(nil, { adapter = adapter_id })
    local n = tree and count_tests(tree, position_ids) or 0
    started[adapter_id] = vim.uv.hrtime()
    vim.schedule(function()
      vim.notify(("Running %d test%s…"):format(n, n == 1 and "" or "s"), vim.log.levels.INFO,
        { title = "Neotest", id = "neotest_progress" })
    end)
  end

  client.listeners.results = function(adapter_id, results, partial)
    if partial then return end
    local tree = client:get_position(nil, { adapter = adapter_id })
    if not tree then return end
    local counts = { passed = 0, failed = 0, skipped = 0 }
    for id, result in pairs(results) do
      local node = tree:get_key(id)
      if node and node:data().type == "test" and counts[result.status] then
        counts[result.status] = counts[result.status] + 1
      end
    end
    local secs = started[adapter_id] and (vim.uv.hrtime() - started[adapter_id]) / 1e9 or 0
    local msg = ("✓ %d passed"):format(counts.passed)
    if counts.failed > 0 then msg = msg .. ("   ✗ %d failed"):format(counts.failed) end
    if counts.skipped > 0 then msg = msg .. ("   ○ %d skipped"):format(counts.skipped) end
    msg = msg .. ("   (%.1fs)"):format(secs)
    local level = counts.failed > 0 and vim.log.levels.ERROR or vim.log.levels.INFO
    vim.schedule(function()
      vim.notify(msg, level, { title = "Neotest", id = "neotest_progress" })
    end)
  end

  return {}
end

return {
  "nvim-neotest/neotest",
  opts = function(_, opts)
    opts.consumers = opts.consumers or {}
    opts.consumers.progress = progress
  end,
}

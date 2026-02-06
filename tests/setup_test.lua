-- Tests for M.setup() config merging
-- Run with: nvim --headless -u NONE -l tests/setup_test.lua

local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h") .. "/helpers.lua")

-- 1. Config starts empty
local M = H.fresh_require()
H.assert_eq("config starts as empty table", vim.tbl_count(M.config), 0)

-- 2. Setup merges options
M = H.fresh_require()
M.setup({ model = "opus" })
H.assert_eq("setup sets a key", M.config.model, "opus")

-- 3. Setup with nil is safe
M = H.fresh_require()
M.setup(nil)
H.assert_eq("setup(nil) keeps empty config", vim.tbl_count(M.config), 0)

-- 4. Setup with no args is safe
M = H.fresh_require()
M.setup()
H.assert_eq("setup() keeps empty config", vim.tbl_count(M.config), 0)

-- 5. Second setup call merges, not replaces
M = H.fresh_require()
M.setup({ a = 1, b = 2 })
M.setup({ b = 3, c = 4 })
H.assert_eq("first key preserved", M.config.a, 1)
H.assert_eq("overlapping key overwritten", M.config.b, 3)
H.assert_eq("new key added", M.config.c, 4)

-- 6. Deep merge works for nested tables
M = H.fresh_require()
M.setup({ ui = { border = "rounded", width = 80 } })
M.setup({ ui = { width = 120 } })
H.assert_eq("nested: untouched key preserved", M.config.ui.border, "rounded")
H.assert_eq("nested: overwritten key updated", M.config.ui.width, 120)

H.summary()

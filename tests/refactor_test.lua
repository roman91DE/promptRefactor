-- Tests for M.refactor() — concurrency guard and full integration via mocked jobstart
-- Run with: nvim --headless -u NONE -l tests/refactor_test.lua

local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h") .. "/helpers.lua")

-- Capture vim.notify messages for assertion
local notifications = {}
local orig_notify = vim.notify
vim.notify = function(msg, level)
	table.insert(notifications, { msg = msg, level = level })
end

local function clear_notifications()
	notifications = {}
end

local function last_notification()
	return notifications[#notifications]
end

------------------------------------------------------------------------
-- Concurrency guard tests
------------------------------------------------------------------------

-- 1. Rejects when a job is already running
local M = H.fresh_require()
M._job_id = 999 -- simulate a running job
clear_notifications()
M.refactor("do something", 1, 1)
H.assert_eq(
	"rejects when job running",
	last_notification().msg,
	"PromptRefactor is already running"
)
H.assert_eq("rejects at WARN level", last_notification().level, vim.log.levels.WARN)

-- 2. _job_id is nil after fresh require
M = H.fresh_require()
H.assert_eq("_job_id starts nil", M._job_id, nil)

------------------------------------------------------------------------
-- Integration test: mock jobstart to simulate the full pipeline
------------------------------------------------------------------------

-- Helper: mock jobstart so we control the response without spawning a process.
-- Defers on_stdout/on_exit via vim.schedule so they run after refactor()
-- finishes setting M._job_id, matching real async behavior.
local function mock_refactor(module, mock_stdout, mock_exit_code)
	local captured_prompt = nil
	local orig_jobstart = vim.fn.jobstart
	local orig_chansend = vim.fn.chansend
	local orig_chanclose = vim.fn.chanclose
	local orig_schedule = vim.schedule

	-- Collect scheduled functions, run them manually after refactor() returns
	local deferred = {}
	vim.schedule = function(fn) table.insert(deferred, fn) end

	vim.fn.jobstart = function(cmd, opts)
		local on_stdout = opts.on_stdout
		local on_exit = opts.on_exit

		-- Simulate stdout data (buffered mode: array of lines)
		local stdout_lines = vim.split(mock_stdout, "\n", { plain = true })
		on_stdout(1, stdout_lines)

		-- on_exit calls vim.schedule internally, so it will be deferred
		on_exit(1, mock_exit_code or 0)

		return 1 -- fake job id
	end

	vim.fn.chansend = function(id, data)
		captured_prompt = data
	end
	vim.fn.chanclose = function() end

	-- Return: cleanup, get_prompt, flush (runs deferred callbacks)
	local function cleanup()
		vim.fn.jobstart = orig_jobstart
		vim.fn.chansend = orig_chansend
		vim.fn.chanclose = orig_chanclose
		vim.schedule = orig_schedule
	end

	local function flush()
		for _, fn in ipairs(deferred) do
			fn()
		end
		deferred = {}
	end

	return cleanup, function() return captured_prompt end, flush
end

-- 3. Full pipeline: buffer gets updated with fence-stripped response
M = H.fresh_require()
clear_notifications()

-- Set up a real buffer with Python code
local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(buf)
vim.bo[buf].filetype = "python"
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
	"def foo():",
	"    x = 1",
	"    return x",
})

-- Mock jobstart to return a fenced response (the bug scenario)
local cleanup, get_prompt, flush = mock_refactor(
	M,
	"Here's the refactored code:\n\n```python\ndef foo():\n    return 1\n```\n"
)

M.refactor("simplify", 1, 3)
flush()
cleanup()

local result_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
H.assert_eq("line 1 updated", result_lines[1], "def foo():")
H.assert_eq("line 2 updated", result_lines[2], "    return 1")
H.assert_eq("old line 3 removed", result_lines[3], nil)
H.assert_eq("job_id cleared after completion", M._job_id, nil)
H.assert_eq("notified completion", last_notification().msg, "Refactor complete")

-- 4. Prompt was sent to the CLI
local prompt = get_prompt()
H.assert_match("prompt contains user instruction", prompt, "simplify")
H.assert_match("prompt contains the code", prompt, "def foo%(%):")
H.assert_match("prompt contains filetype fence", prompt, "```python")

-- 5. CLI error: buffer is NOT modified
M = H.fresh_require()
clear_notifications()

local buf2 = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(buf2)
vim.bo[buf2].filetype = "python"
vim.api.nvim_buf_set_lines(buf2, 0, -1, false, { "original_code" })

local cleanup2, _, flush2 = mock_refactor(M, "something went wrong", 1) -- exit code 1
M.refactor("refactor", 1, 1)
flush2()
cleanup2()

local unchanged = vim.api.nvim_buf_get_lines(buf2, 0, -1, false)
H.assert_eq("buffer unchanged on CLI error", unchanged[1], "original_code")
H.assert_match("error notification shown", last_notification().msg, "Claude CLI error")

-- 6. Empty response: buffer is NOT modified
M = H.fresh_require()
clear_notifications()

local buf3 = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(buf3)
vim.bo[buf3].filetype = "python"
vim.api.nvim_buf_set_lines(buf3, 0, -1, false, { "keep_this" })

local cleanup3, _, flush3 = mock_refactor(M, "   \n\n  ") -- whitespace-only response
M.refactor("refactor", 1, 1)
flush3()
cleanup3()

local unchanged3 = vim.api.nvim_buf_get_lines(buf3, 0, -1, false)
H.assert_eq("buffer unchanged on empty response", unchanged3[1], "keep_this")
H.assert_eq("empty response warning", last_notification().msg, "Empty response from Claude CLI")

-- 7. Partial range replacement (only middle lines)
M = H.fresh_require()
clear_notifications()

local buf4 = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(buf4)
vim.bo[buf4].filetype = "python"
vim.api.nvim_buf_set_lines(buf4, 0, -1, false, {
	"# header",
	"def old():",
	"    pass",
	"# footer",
})

local cleanup4, _, flush4 = mock_refactor(M, "```python\ndef new():\n    return 42\n```")
M.refactor("rename", 2, 3) -- only replace lines 2-3
flush4()
cleanup4()

local result4 = vim.api.nvim_buf_get_lines(buf4, 0, -1, false)
H.assert_eq("header preserved", result4[1], "# header")
H.assert_eq("replaced line 1", result4[2], "def new():")
H.assert_eq("replaced line 2", result4[3], "    return 42")
H.assert_eq("footer preserved", result4[4], "# footer")

------------------------------------------------------------------------
-- Restore
------------------------------------------------------------------------
vim.notify = orig_notify

H.summary()

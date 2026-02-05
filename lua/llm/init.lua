local M = {}

M.config = {}
M._job_id = nil

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

function M.refactor(prompt, line1, line2)
	if M._job_id then
		vim.notify("PromptRefactor is already running", vim.log.levels.WARN)
		return
	end

	-- Capture buffer identity at call time
	local bufnr = vim.api.nvim_get_current_buf()

	-- Get target lines
	local lines = vim.api.nvim_buf_get_lines(bufnr, line1 - 1, line2, false)
	local code = table.concat(lines, "\n")

	-- Get filetype for syntax hint
	local filetype = vim.bo.filetype
	if filetype == "" then
		filetype = "text"
	end

	-- Construct the full prompt
	local full_prompt = prompt
		.. "\n\n"
		.. "Refactor the following code. Return ONLY the refactored code, no explanations:\n\n"
		.. "```"
		.. filetype
		.. "\n"
		.. code
		.. "\n"
		.. "```"

	-- Show thinking notification
	vim.notify("Thinking...", vim.log.levels.INFO)

	-- Collect stdout chunks
	local stdout_chunks = {}
	local stderr_chunks = {}

	-- Run claude CLI async, passing prompt via stdin
	local job_id = vim.fn.jobstart({ "claude", "-p" }, {
		stdin = "pipe",
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			if data then
				for _, chunk in ipairs(data) do
					table.insert(stdout_chunks, chunk)
				end
			end
		end,
		on_stderr = function(_, data)
			if data then
				for _, chunk in ipairs(data) do
					table.insert(stderr_chunks, chunk)
				end
			end
		end,
		on_exit = function(_, exit_code)
			vim.schedule(function()
				M._job_id = nil

				if exit_code ~= 0 then
					local stderr = table.concat(stderr_chunks, "\n")
					vim.notify("Claude CLI error: " .. stderr, vim.log.levels.ERROR)
					return
				end

				if not vim.api.nvim_buf_is_valid(bufnr) then
					vim.notify("Buffer was closed before refactor completed", vim.log.levels.WARN)
					return
				end

				-- Join stdout chunks (buffered mode gives array of lines)
				local response = table.concat(stdout_chunks, "\n")

				-- Strip leading/trailing whitespace
				response = response:match("^%s*(.-)%s*$")

				-- Strip markdown code fences if present
				response = response:gsub("^```[^\n]*\n", ""):gsub("\n?```%s*$", "")

				if response == "" then
					vim.notify("Empty response from Claude CLI", vim.log.levels.WARN)
					return
				end

				-- Split response into lines for buffer replacement
				local new_lines = vim.split(response, "\n", { plain = true })

				-- Replace the target lines with the response (undojoin for atomic undo)
				vim.api.nvim_buf_call(bufnr, function()
					vim.cmd("undojoin")
					vim.api.nvim_buf_set_lines(bufnr, line1 - 1, line2, false, new_lines)
				end)

				vim.notify("Refactor complete", vim.log.levels.INFO)
			end)
		end,
	})

	if job_id <= 0 then
		vim.notify("Failed to start claude CLI. Is it installed?", vim.log.levels.ERROR)
		return
	end

	M._job_id = job_id

	-- Send prompt via stdin and close
	vim.fn.chansend(job_id, full_prompt)
	vim.fn.chanclose(job_id, "stdin")
end

return M

-- Tests for M._build_prompt
-- Run with: nvim --headless -u NONE -l tests/build_prompt_test.lua

local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h") .. "/helpers.lua")
local M = H.fresh_require()

-- 1. Basic prompt structure
local result = M._build_prompt("make it faster", "def foo():\n    pass", "python")
H.assert_match("contains user prompt", result, "make it faster")
H.assert_match("contains instruction", result, "Return ONLY the refactored code")
H.assert_match("opens code fence with filetype", result, "```python\n")
H.assert_match("contains the code", result, "def foo%(%):\n    pass")
H.assert_match("closes code fence", result, "\n```$")

-- 2. Empty filetype defaults to "text"
local result2 = M._build_prompt("refactor", "x = 1", "")
H.assert_match("empty filetype becomes text", result2, "```text\n")

-- 3. Nil filetype defaults to "text"
local result3 = M._build_prompt("refactor", "x = 1", nil)
H.assert_match("nil filetype becomes text", result3, "```text\n")

-- 4. Different filetypes
local result4 = M._build_prompt("refactor", "fn main() {}", "rust")
H.assert_match("rust filetype tag", result4, "```rust\n")

-- 5. Multi-line code is preserved
local code = "def foo():\n    x = 1\n    y = 2\n    return x + y"
local result5 = M._build_prompt("optimize", code, "python")
H.assert_true("multi-line code preserved", result5:find(code, 1, true))

-- 6. Prompt with special characters
local result6 = M._build_prompt("rename % to pct", "x = 100", "python")
H.assert_match("special chars in prompt preserved", result6, "rename %% to pct")

-- 7. Code containing backticks is not mangled
local code7 = 'cmd = f"echo `hostname`"'
local result7 = M._build_prompt("refactor", code7, "python")
H.assert_match("backticks in code preserved", result7, "echo `hostname`")

-- 8. Prompt and code are separated by the instruction block
local result8 = M._build_prompt("do it", "code_here", "lua")
-- Verify ordering: prompt comes first, then instruction, then code
local prompt_pos = result8:find("do it")
local instr_pos = result8:find("Refactor the following code")
local code_pos = result8:find("code_here")
H.assert_true("prompt before instruction", prompt_pos < instr_pos)
H.assert_true("instruction before code", instr_pos < code_pos)

H.summary()

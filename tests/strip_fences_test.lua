-- Test suite for M._strip_markdown_fences
-- Run with: nvim --headless -u NONE -l tests/strip_fences_test.lua

-- Add plugin to Lua path so require("llm") works
local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
package.path = plugin_root .. "/lua/?.lua;" .. plugin_root .. "/lua/?/init.lua;" .. package.path

local M = require("llm")
local strip = M._strip_markdown_fences

local pass = 0
local fail = 0

local function test(name, input, expected)
	local actual = strip(input)
	if actual == expected then
		pass = pass + 1
		print("PASS: " .. name)
	else
		fail = fail + 1
		print("FAIL: " .. name)
		print("  expected: " .. vim.inspect(expected))
		print("  actual:   " .. vim.inspect(actual))
	end
end

-- 1. No fences at all — return as-is
test(
	"plain code without fences",
	"def foo():\n    return 42",
	"def foo():\n    return 42"
)

-- 2. Entire response is a single fenced block
test(
	"single fenced block",
	"```python\ndef foo():\n    return 42\n```",
	"def foo():\n    return 42"
)

-- 3. Fenced block with no language tag
test(
	"fenced block no language",
	"```\ndef foo():\n    return 42\n```",
	"def foo():\n    return 42"
)

-- 4. Preamble text before the code block
test(
	"preamble before fence",
	"Here's the refactored code:\n\n```python\ndef foo():\n    return 42\n```",
	"def foo():\n    return 42"
)

-- 5. Trailing explanation after the code block
test(
	"trailing text after fence",
	"```python\ndef foo():\n    return 42\n```\n\nI renamed the variable for clarity.",
	"def foo():\n    return 42"
)

-- 6. Both preamble and trailing text
test(
	"preamble and trailing text",
	"Here's the code:\n\n```python\ndef foo():\n    return 42\n```\n\nChanges made:\n- renamed x to y",
	"def foo():\n    return 42"
)

-- 7. Closing fence with trailing whitespace
test(
	"closing fence with trailing spaces",
	"```python\ndef foo():\n    return 42\n```   ",
	"def foo():\n    return 42"
)

-- 8. Four-backtick fence (e.g., ````python)
test(
	"four-backtick fence",
	"````python\ndef foo():\n    return 42\n````",
	"def foo():\n    return 42"
)

-- 9. Empty code block
test(
	"empty code block",
	"```python\n```",
	""
)

-- 10. Code containing triple-backtick in a string (mid-line, not a fence)
test(
	"backticks inside code on non-fence line",
	'```python\nmarkdown = "```hello```"\ndef foo():\n    return markdown\n```',
	'markdown = "```hello```"\ndef foo():\n    return markdown'
)

-- 11. Single line of code in a fence
test(
	"single line fenced",
	"```python\nreturn 42\n```",
	"return 42"
)

-- 12. Only opening fence, no closing fence — return unchanged
test(
	"opening fence only, no close",
	"```python\ndef foo():\n    return 42",
	"```python\ndef foo():\n    return 42"
)

-- 13. Multi-line code preserves internal blank lines
test(
	"preserves internal blank lines",
	"```python\ndef foo():\n    pass\n\ndef bar():\n    pass\n```",
	"def foo():\n    pass\n\ndef bar():\n    pass"
)

-- 14. Multiple code blocks — extracts from first open to last close
test(
	"multiple code blocks",
	"```python\ndef foo():\n    pass\n```\n\nAnd also:\n\n```python\ndef bar():\n    pass\n```",
	"def foo():\n    pass\n```\n\nAnd also:\n\n```python\ndef bar():\n    pass"
)

-- 15. Only closing fence, no opening — return unchanged
test(
	"closing fence only, no open",
	"def foo():\n    return 42\n```",
	"def foo():\n    return 42\n```"
)

-- 16. Fence with language tag containing extras (e.g., ```python title="example")
test(
	"fence with extended info string",
	'```python title="example"\ndef foo():\n    return 42\n```',
	"def foo():\n    return 42"
)

-- 17. Windows-style line endings (\r\n) — should not break extraction
test(
	"windows line endings",
	"```python\r\ndef foo():\r\n    return 42\r\n```",
	"def foo():\r\n    return 42\r"
)

-- 18. Code with indented triple backticks (not fences)
test(
	"indented backticks are not fences",
	"```python\ndef render():\n    return '''\n    ```\n    code\n    ```\n    '''\n```",
	"def render():\n    return '''\n    ```\n    code\n    ```\n    '''"
)

-- 19. Response is just whitespace around a fence
test(
	"whitespace around fenced block",
	"\n\n```python\ndef foo():\n    pass\n```\n\n",
	"def foo():\n    pass"
)

-- 20. Deeply nested: four-backtick fence wrapping content with triple-backtick examples
test(
	"four-backtick wrapping triple-backtick content",
	"````python\ndef render_markdown():\n    return \"\"\"```\\ncode\\n```\"\"\"\n````",
	'def render_markdown():\n    return \"\"\"```\\ncode\\n```\"\"\"'
)

-- Summary
print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then
	os.exit(1)
end

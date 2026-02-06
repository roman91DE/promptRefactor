-- Shared test helpers
-- Adds plugin to Lua path and provides assertion utilities.

local H = {}

-- Set up Lua path so require("llm") resolves to the plugin
local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
package.path = plugin_root .. "/lua/?.lua;" .. plugin_root .. "/lua/?/init.lua;" .. package.path

H.pass = 0
H.fail = 0

function H.test(name, input, expected, fn)
	local actual = fn(input)
	if actual == expected then
		H.pass = H.pass + 1
		print("PASS: " .. name)
	else
		H.fail = H.fail + 1
		print("FAIL: " .. name)
		print("  expected: " .. vim.inspect(expected))
		print("  actual:   " .. vim.inspect(actual))
	end
end

function H.assert_eq(name, actual, expected)
	if actual == expected then
		H.pass = H.pass + 1
		print("PASS: " .. name)
	else
		H.fail = H.fail + 1
		print("FAIL: " .. name)
		print("  expected: " .. vim.inspect(expected))
		print("  actual:   " .. vim.inspect(actual))
	end
end

function H.assert_match(name, actual, pattern)
	if type(actual) == "string" and actual:find(pattern) then
		H.pass = H.pass + 1
		print("PASS: " .. name)
	else
		H.fail = H.fail + 1
		print("FAIL: " .. name)
		print("  expected match: " .. vim.inspect(pattern))
		print("  actual:         " .. vim.inspect(actual))
	end
end

function H.assert_true(name, value)
	if value then
		H.pass = H.pass + 1
		print("PASS: " .. name)
	else
		H.fail = H.fail + 1
		print("FAIL: " .. name)
		print("  expected truthy, got: " .. vim.inspect(value))
	end
end

function H.summary()
	print(string.format("\n%d passed, %d failed", H.pass, H.fail))
	if H.fail > 0 then
		os.exit(1)
	end
end

--- Return a fresh require of the llm module (clears cached state).
function H.fresh_require()
	package.loaded["llm"] = nil
	package.loaded["llm.init"] = nil
	return require("llm")
end

return H

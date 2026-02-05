if vim.g.loaded_llm then
  return
end
vim.g.loaded_llm = true

vim.api.nvim_create_user_command("PromptRefactor", function(opts)
  require("llm").refactor(opts.args, opts.line1, opts.line2)
end, {
  nargs = "+",
  range = "%",
  desc = "Refactor code with Claude Code CLI",
})

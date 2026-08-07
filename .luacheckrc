std = "luajit"
cache = true

exclude_files = {
  ".tests",
}

globals = {
  "vim",
}

read_globals = {
  "assert",
  "describe",
  "it",
  "before_each",
  "after_each",
}

ignore = {
  "212", -- unused argument
  "631", -- line is too long
}

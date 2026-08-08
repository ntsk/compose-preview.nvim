-- Renders sample/ end to end and fails loudly if anything about the output is
-- wrong. Unlike the unit tests this needs a JDK, the Android SDK and network
-- access, so it is a separate target: `make e2e`.
--
-- It exists to catch the one failure the unit tests structurally cannot: a
-- renderer and layoutlib pair that load fine but produce broken images.

local EXPECTED_PREVIEWS = 7

local root = vim.fn.fnamemodify(vim.fn.resolve(debug.getinfo(1, 'S').source:sub(2)), ':p:h:h')
local cache = vim.fs.joinpath(root, '.tests', 'cache')

vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:prepend(vim.fs.joinpath(root, '.tests'))

local function die(message)
  io.stderr:write('e2e: ' .. message .. '\n')
  os.exit(1)
end

local function find_results()
  local matches = vim.fn.glob(vim.fs.joinpath(cache, 'work', '*', 'results.json'), false, true)
  return matches[1]
end

local messages = {}
vim.notify = function(message)
  table.insert(messages, message)
  print(message)
end

local preview = require('compose-preview')
preview.setup({ cache_dir = cache, open_cmd = { 'true' } })

vim.cmd.edit(vim.fs.joinpath(root, 'sample/app/src/main/java/com/example/sample/Greeting.kt'))
preview.open()

local finished = vim.wait(20 * 60 * 1000, function()
  for _, message in ipairs(messages) do
    if message:match('rendered %d+ previews') or message:match('previews failed') or message:match('not ') then
      return true
    end
  end
  return false
end, 200)

if not finished then
  die('timed out waiting for the render to finish')
end

local results_path = find_results()
if not results_path then
  die('no results.json was produced')
end

local results = require('compose-preview.results').parse(table.concat(vim.fn.readfile(results_path), '\n'))
if not results then
  die('results.json could not be parsed')
end

if results.global_error then
  die('the renderer reported a global error: ' .. results.global_error)
end

if #results.previews ~= EXPECTED_PREVIEWS then
  die(('expected %d previews, got %d'):format(EXPECTED_PREVIEWS, #results.previews))
end

-- A renderer and layoutlib that disagree still exit zero, but every composable
-- is replaced by a grey placeholder and the classes that failed to load are
-- reported as an error alongside the image. `ok` is false in that case, which
-- is the check that makes this whole target worth running.
for _, item in ipairs(results.previews) do
  if not item.ok then
    local detail = item.error and item.error.message or 'unknown'
    local broken = item.error and item.error.missing_classes or {}
    if #broken > 0 then
      detail = detail .. ' (missing: ' .. table.concat(broken, ', ') .. ')'
    end
    die(('%s failed: %s'):format(item.preview_id, detail))
  end

  if not item.image_path then
    die(item.preview_id .. ' produced no image')
  end
end

print(('e2e: %d previews rendered cleanly'):format(#results.previews))

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

  -- Whatever went wrong, the detail is in the log rather than the notification.
  -- CI throws the workspace away, so print it here or it is lost.
  local log_path = require('compose-preview').log_path()
  if vim.fn.filereadable(log_path) == 1 then
    io.stderr:write('e2e: --- ' .. log_path .. ' ---\n')
    for _, line in ipairs(vim.fn.readfile(log_path)) do
      io.stderr:write(line .. '\n')
    end
  end

  os.exit(1)
end

local function find_results()
  local matches = vim.fn.glob(vim.fs.joinpath(cache, 'work', '*', 'results.json'), false, true)
  return matches[1]
end

-- Anything the plugin reports as an error ends the run. Matching on message
-- text instead would quietly turn a real failure into a timeout.
local failure, done
vim.notify = function(message, level)
  print(message)
  if level == vim.log.levels.ERROR then
    failure = message
  elseif message:match('rendered %d+ previews') or message:match('previews failed') then
    done = true
  end
end

local preview = require('compose-preview')
preview.setup({ cache_dir = cache, open_cmd = { 'true' } })

vim.cmd.edit(vim.fs.joinpath(root, 'sample/app/src/main/java/com/example/sample/Greeting.kt'))
preview.open()

local finished = vim.wait(20 * 60 * 1000, function()
  return failure ~= nil or done == true
end, 200)

if failure then
  die(failure)
end

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

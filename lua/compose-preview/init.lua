local gradle = require('compose-preview.gradle')
local html = require('compose-preview.html')
local log = require('compose-preview.log')
local renderer = require('compose-preview.renderer')
local scanner = require('compose-preview.scanner')
local settings = require('compose-preview.settings')
local toolchain = require('compose-preview.toolchain')
local view = require('compose-preview.view')

local M = {}

local OUTPUT_DIR_NAME = 'out'
local PROGRESS_INTERVAL_NS = 2e9

M.config = {
  java = nil,
  gradle_java_home = nil,
  variant = nil,
  cache_dir = nil,
  open_cmd = nil,
  timeout = renderer.DEFAULT_TIMEOUT_MS,
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})
end

function M.log_path()
  return log.default_path()
end

local function notify(message, level)
  log.write(level == vim.log.levels.ERROR and 'ERROR' or 'INFO', message)
  vim.notify('[compose-preview] ' .. message, level or vim.log.levels.INFO)
end

local function fail(message)
  notify(message .. ' (see :ComposePreviewLog)', vim.log.levels.ERROR)
end

local function write(path, content)
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  vim.fn.writefile(vim.split(content, '\n'), path)
end

local function open_in_browser(path)
  if not M.config.open_cmd then
    return vim.ui.open(path)
  end

  local cmd = vim.list_extend(vim.deepcopy(M.config.open_cmd), { path })
  vim.system(cmd, { detach = true })
end

local function progress_reporter()
  local last = 0

  return function(task)
    log.info('task ' .. task)

    local now = vim.uv.hrtime()
    if now - last > PROGRESS_INTERVAL_NS then
      last = now
      vim.notify('[compose-preview] ' .. task, vim.log.levels.INFO)
    end
  end
end

--- Resolves the buffer into everything the pipeline needs, or an error.
local function prepare(bufnr)
  local file = vim.api.nvim_buf_get_name(bufnr)
  if not file:match('%.kt$') then
    return nil, 'not a Kotlin file'
  end

  local source = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
  local previews = scanner.scan(source, file)
  if #previews == 0 then
    return nil, 'no @Preview found in this file'
  end

  local root = gradle.find_project_root(file)
  if not root then
    return nil, 'gradlew not found'
  end

  local module = gradle.find_module(root, file)
  if not module then
    return nil, 'build.gradle not found'
  end

  local work = vim.fs.joinpath(
    M.config.cache_dir or toolchain.default_cache_dir(),
    'work',
    vim.fn.sha256(root .. module):sub(1, 16)
  )

  return {
    file = file,
    title = vim.fs.basename(file),
    previews = previews,
    root = root,
    module = module,
    work = work,
    output = vim.fs.joinpath(work, OUTPUT_DIR_NAME),
    metadata = vim.fs.joinpath(work, 'meta'),
    page = vim.fs.joinpath(work, 'index.html'),
    info_path = vim.fs.joinpath(work, 'gradle-info.json'),
    results_path = vim.fs.joinpath(work, 'results.json'),
    settings_path = vim.fs.joinpath(work, 'settings.json'),
  }
end

local function write_settings(job, paths, info)
  vim.fn.delete(job.output, 'rf')
  vim.fn.mkdir(job.output, 'p')
  vim.fn.mkdir(job.metadata, 'p')
  vim.fn.delete(job.results_path)

  local built, dropped = settings.build({
    previews = job.previews,
    layoutlib_path = paths.layoutlib_dir,
    output_dir = job.output,
    metadata_dir = job.metadata,
    results_path = job.results_path,
    namespace = info.namespace,
    resource_apk_path = info.resourceApkPath,
    class_path = info.classPath,
    project_class_path = info.projectClassPath,
  })

  for _, entry in ipairs(dropped) do
    log.write(
      'WARN',
      ('%s: dropped unresolvable @Preview attributes: %s'):format(
        entry.method_fqn,
        table.concat(entry.attributes, ', ')
      )
    )
  end

  write(job.settings_path, vim.json.encode(built))
end

local function publish(job, results)
  local items = view.items(job.previews, results, OUTPUT_DIR_NAME)
  local token = tostring(vim.uv.hrtime())

  write(vim.fs.joinpath(job.work, 'token.js'), html.token_script(token))
  write(
    job.page,
    html.build({
      title = job.title,
      items = items,
      global_error = results.global_error,
      generated_at = os.date('%H:%M:%S'),
      token = token,
    })
  )

  local failed = #vim.tbl_filter(function(item)
    return not item.ok
  end, items)

  if failed > 0 then
    notify(('%d of %d previews failed'):format(failed, #items), vim.log.levels.WARN)
  else
    notify(('rendered %d previews'):format(#items))
  end

  open_in_browser(job.page)
end

function M.open(bufnr)
  local job, err = prepare(bufnr or vim.api.nvim_get_current_buf())
  if not job then
    return fail(err)
  end

  vim.fn.mkdir(job.work, 'p')
  log.info(('open: file=%s root=%s module=%s previews=%d'):format(job.file, job.root, job.module, #job.previews))

  local java = M.config.java or renderer.find_java()

  local function render(paths, info)
    write_settings(job, paths, info)

    notify(('rendering %d previews...'):format(#job.previews))
    renderer.render({
      java = java,
      classpath = paths.classpath,
      settings_path = job.settings_path,
      results_path = job.results_path,
      timeout = M.config.timeout,
    }, function(render_err, results)
      if render_err then
        return fail(render_err)
      end
      publish(job, results)
    end)
  end

  local function inspect(paths)
    notify(('building %s...'):format(job.module == '' and ':' or job.module))

    gradle.build_and_inspect({
      root = job.root,
      module = job.module,
      variant = M.config.variant,
      info_path = job.info_path,
      java_home = M.config.gradle_java_home,
      fallback_java_home = renderer.java_home(java),
      on_progress = progress_reporter(),
    }, function(gradle_err, info)
      if gradle_err then
        return fail(gradle_err)
      end
      render(paths, info)
    end)
  end

  notify('preparing toolchain...')
  toolchain.install({ cache_dir = M.config.cache_dir }, function(install_err, paths)
    if install_err then
      return fail(install_err)
    end
    inspect(paths)
  end)
end

return M

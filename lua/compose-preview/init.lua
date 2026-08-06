local gradle = require('compose-preview.gradle')
local html = require('compose-preview.html')
local renderer = require('compose-preview.renderer')
local scanner = require('compose-preview.scanner')
local settings = require('compose-preview.settings')
local toolchain = require('compose-preview.toolchain')
local view = require('compose-preview.view')

local M = {}

local OUTPUT_DIR_NAME = 'out'

M.config = {
  java = nil,
  variant = nil,
  cache_dir = nil,
  open_cmd = nil,
  timeout = renderer.DEFAULT_TIMEOUT_MS,
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})
end

local function notify(message, level)
  vim.notify('[compose-preview] ' .. message, level or vim.log.levels.INFO)
end

local function fail(message)
  notify(message, vim.log.levels.ERROR)
end

local function work_dir(root, module)
  local key = vim.fn.sha256(root .. (module or ''))
  return vim.fs.joinpath(M.config.cache_dir or toolchain.default_cache_dir(), 'work', key:sub(1, 16))
end

local function write(path, content)
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  vim.fn.writefile(vim.split(content, '\n'), path)
end

local function open_in_browser(path)
  if M.config.open_cmd then
    vim.system(vim.list_extend(vim.deepcopy(M.config.open_cmd), { path }), { detach = true })
  else
    vim.ui.open(path)
  end
end

local function publish(previews, results, dirs, title)
  local items = view.items(previews, results, OUTPUT_DIR_NAME)
  local token = tostring(vim.uv.hrtime())

  write(vim.fs.joinpath(dirs.work, 'token.js'), html.token_script(token))
  write(
    dirs.page,
    html.build({
      title = title,
      items = items,
      global_error = results.global_error,
      generated_at = os.date('%H:%M:%S'),
      token = token,
    })
  )

  local failed = 0
  for _, item in ipairs(items) do
    if not item.ok then
      failed = failed + 1
    end
  end

  if failed > 0 then
    notify(('%d of %d previews failed'):format(failed, #items), vim.log.levels.WARN)
  else
    notify(('rendered %d previews'):format(#items))
  end

  open_in_browser(dirs.page)
end

function M.open(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(bufnr)

  if not file:match('%.kt$') then
    return fail('not a Kotlin file')
  end

  local source = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
  local previews = scanner.scan(source, file)
  if #previews == 0 then
    return fail('no @Preview found in this file')
  end

  local root = gradle.find_project_root(file)
  if not root then
    return fail('gradlew not found')
  end

  local module = gradle.find_module(root, file)
  if not module then
    return fail('build.gradle not found')
  end

  local dirs = {}
  dirs.work = work_dir(root, module)
  dirs.output = vim.fs.joinpath(dirs.work, OUTPUT_DIR_NAME)
  dirs.metadata = vim.fs.joinpath(dirs.work, 'meta')
  dirs.page = vim.fs.joinpath(dirs.work, 'index.html')

  local title = vim.fs.basename(file)

  notify('preparing toolchain...')
  toolchain.install({ cache_dir = M.config.cache_dir }, function(install_err, paths)
    if install_err then
      return fail(install_err)
    end

    notify(('building %s...'):format(module == '' and ':' or module))
    gradle.build_and_inspect({ root = root, module = module, variant = M.config.variant }, function(gradle_err, info)
      if gradle_err then
        return fail(gradle_err)
      end

      vim.fn.mkdir(dirs.output, 'p')
      vim.fn.mkdir(dirs.metadata, 'p')

      local results_path = vim.fs.joinpath(dirs.work, 'results.json')
      local settings_path = vim.fs.joinpath(dirs.work, 'settings.json')

      vim.fn.delete(results_path)
      write(
        settings_path,
        vim.json.encode(settings.build({
          previews = previews,
          layoutlib_path = paths.layoutlib_dir,
          output_dir = dirs.output,
          metadata_dir = dirs.metadata,
          results_path = results_path,
          namespace = info.namespace,
          resource_apk_path = info.resourceApkPath,
          class_path = info.classPath,
          project_class_path = info.projectClassPath,
        }))
      )

      notify(('rendering %d previews...'):format(#previews))
      renderer.render({
        java = M.config.java,
        classpath = paths.classpath,
        settings_path = settings_path,
        results_path = results_path,
        timeout = M.config.timeout,
      }, function(render_err, results)
        if render_err then
          return fail(render_err)
        end
        publish(previews, results, dirs, title)
      end)
    end)
  end)
end

return M

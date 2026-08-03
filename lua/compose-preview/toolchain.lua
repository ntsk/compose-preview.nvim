local M = {}

M.RENDERER_VERSION = '0.0.1-alpha16'
M.LAYOUTLIB_VERSION = '17.0.1'

local MAVEN_BASE = 'https://dl.google.com/dl/android/maven2'
local RENDERER_GROUP = 'com.android.tools.compose'
local RENDERER_ARTIFACT = 'compose-preview-renderer'
local LAYOUTLIB_GROUP = 'com.android.tools.layoutlib'
local LAYOUTLIB_ARTIFACT = 'layoutlib-runtime'

function M.artifact_url(group, artifact, version)
  return table.concat({
    MAVEN_BASE,
    group:gsub('%.', '/'),
    artifact,
    version,
    artifact .. '-' .. version .. '.jar',
  }, '/')
end

function M.default_cache_dir()
  return vim.fs.joinpath(vim.fn.stdpath('cache'), 'compose-preview')
end

function M.paths(opts)
  opts = opts or {}
  local cache_dir = opts.cache_dir or M.default_cache_dir()
  local renderer_version = opts.renderer_version or M.RENDERER_VERSION
  local layoutlib_version = opts.layoutlib_version or M.LAYOUTLIB_VERSION

  return {
    cache_dir = cache_dir,
    renderer_version = renderer_version,
    layoutlib_version = layoutlib_version,
    renderer_jar = vim.fs.joinpath(cache_dir, RENDERER_ARTIFACT .. '-' .. renderer_version .. '.jar'),
    layoutlib_dir = vim.fs.joinpath(cache_dir, 'layoutlib-' .. layoutlib_version),
    renderer_url = M.artifact_url(RENDERER_GROUP, RENDERER_ARTIFACT, renderer_version),
    layoutlib_url = M.artifact_url(LAYOUTLIB_GROUP, LAYOUTLIB_ARTIFACT, layoutlib_version),
  }
end

function M.is_installed(opts)
  local paths = M.paths(opts)
  return vim.fn.filereadable(paths.renderer_jar) == 1
    and vim.fn.isdirectory(vim.fs.joinpath(paths.layoutlib_dir, 'data', 'fonts')) == 1
end

local function run(cmd, on_done)
  vim.system(cmd, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        on_done(('%s の実行に失敗しました (exit %d): %s'):format(cmd[1], result.code, result.stderr or ''))
      else
        on_done(nil)
      end
    end)
  end)
end

local function download(url, dest, on_done)
  run({ 'curl', '-fsSL', '--create-dirs', '-o', dest, url }, function(err)
    on_done(err and ('%s のダウンロードに失敗しました: %s'):format(url, err) or nil)
  end)
end

function M.install(opts, on_done)
  local paths = M.paths(opts)

  local function finish(err)
    on_done(err, paths)
  end

  local function install_layoutlib()
    if vim.fn.isdirectory(vim.fs.joinpath(paths.layoutlib_dir, 'data', 'fonts')) == 1 then
      return finish(nil)
    end

    local archive = paths.layoutlib_dir .. '.jar'
    download(paths.layoutlib_url, archive, function(err)
      if err then
        return finish(err)
      end
      run({ 'unzip', '-q', '-o', archive, '-d', paths.layoutlib_dir }, function(unzip_err)
        vim.fn.delete(archive)
        finish(unzip_err)
      end)
    end)
  end

  if vim.fn.filereadable(paths.renderer_jar) == 1 then
    return install_layoutlib()
  end

  vim.fn.mkdir(paths.cache_dir, 'p')
  download(paths.renderer_url, paths.renderer_jar, function(err)
    if err then
      return finish(err)
    end
    install_layoutlib()
  end)
end

return M

local M = {}

M.RENDERER_VERSION = '0.0.1-alpha16'
M.LAYOUTLIB_VERSION = '17.0.0'
M.LAYOUTLIB_DATA_VERSION = '17.0.1'

local MAVEN_BASE = 'https://dl.google.com/dl/android/maven2'
local RENDERER_GROUP = 'com.android.tools.compose'
local RENDERER_ARTIFACT = 'compose-preview-renderer'
local LAYOUTLIB_GROUP = 'com.android.tools.layoutlib'

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
  local layoutlib_data_version = opts.layoutlib_data_version or M.LAYOUTLIB_DATA_VERSION

  local renderer_jar = vim.fs.joinpath(cache_dir, RENDERER_ARTIFACT .. '-' .. renderer_version .. '.jar')
  local layoutlib_jar = vim.fs.joinpath(cache_dir, 'layoutlib-' .. layoutlib_version .. '.jar')
  local layoutlib_dir = vim.fs.joinpath(cache_dir, 'layoutlib-data-' .. layoutlib_data_version)

  return {
    cache_dir = cache_dir,
    renderer_version = renderer_version,
    layoutlib_version = layoutlib_version,
    layoutlib_data_version = layoutlib_data_version,
    renderer_jar = renderer_jar,
    layoutlib_jar = layoutlib_jar,
    layoutlib_dir = layoutlib_dir,
    framework_res_jar = vim.fs.joinpath(layoutlib_dir, 'data', 'framework_res.jar'),
    classpath = renderer_jar .. ':' .. layoutlib_jar,
    renderer_url = M.artifact_url(RENDERER_GROUP, RENDERER_ARTIFACT, renderer_version),
    layoutlib_url = M.artifact_url(LAYOUTLIB_GROUP, 'layoutlib', layoutlib_version),
    layoutlib_data_url = M.artifact_url(LAYOUTLIB_GROUP, 'layoutlib-runtime', layoutlib_data_version),
    framework_res_url = M.artifact_url(LAYOUTLIB_GROUP, 'layoutlib-resources', layoutlib_data_version),
  }
end

function M.is_installed(opts)
  local paths = M.paths(opts)
  return vim.fn.filereadable(paths.renderer_jar) == 1
    and vim.fn.filereadable(paths.layoutlib_jar) == 1
    and vim.fn.filereadable(paths.framework_res_jar) == 1
    and vim.fn.isdirectory(vim.fs.joinpath(paths.layoutlib_dir, 'data', 'fonts')) == 1
end

local function run(cmd, on_done)
  vim.system(cmd, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        on_done(('%s failed (exit %d): %s'):format(cmd[1], result.code, result.stderr or ''))
      else
        on_done(nil)
      end
    end)
  end)
end

local function download(url, dest, on_done)
  run({ 'curl', '-fsSL', '--create-dirs', '-o', dest, url }, function(err)
    on_done(err and ('failed to download %s: %s'):format(url, err) or nil)
  end)
end

local function download_if_missing(url, dest, on_done)
  if vim.fn.filereadable(dest) == 1 then
    return on_done(nil)
  end
  download(url, dest, on_done)
end

function M.install(opts, on_done)
  local paths = M.paths(opts)

  local function finish(err)
    on_done(err, paths)
  end

  local function install_framework_res()
    download_if_missing(paths.framework_res_url, paths.framework_res_jar, finish)
  end

  local function install_layoutlib_data()
    if vim.fn.isdirectory(vim.fs.joinpath(paths.layoutlib_dir, 'data', 'fonts')) == 1 then
      return install_framework_res()
    end

    local archive = paths.layoutlib_dir .. '.jar'
    download(paths.layoutlib_data_url, archive, function(err)
      if err then
        return finish(err)
      end
      run({ 'unzip', '-q', '-o', archive, '-d', paths.layoutlib_dir }, function(unzip_err)
        vim.fn.delete(archive)
        if unzip_err then
          return finish(unzip_err)
        end
        install_framework_res()
      end)
    end)
  end

  vim.fn.mkdir(paths.cache_dir, 'p')

  download_if_missing(paths.renderer_url, paths.renderer_jar, function(err)
    if err then
      return finish(err)
    end
    download_if_missing(paths.layoutlib_url, paths.layoutlib_jar, function(layoutlib_err)
      if layoutlib_err then
        return finish(layoutlib_err)
      end
      install_layoutlib_data()
    end)
  end)
end

return M

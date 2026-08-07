local params = require('compose-preview.params')

local M = {}

function M.preview_ids(previews)
  local counters = {}
  local ids = {}

  for _, preview in ipairs(previews) do
    local index = counters[preview.method_fqn] or 0
    counters[preview.method_fqn] = index + 1
    table.insert(ids, preview.method_fqn .. '_' .. index)
  end

  return ids
end

local function screenshots(previews)
  local ids = M.preview_ids(previews)
  local result = {}
  local dropped = {}

  for index, preview in ipairs(previews) do
    local resolved, unresolvable = params.normalize(preview.params)
    if #unresolvable > 0 then
      table.insert(dropped, { method_fqn = preview.method_fqn, attributes = unresolvable })
    end

    local screenshot = {
      methodFQN = preview.method_fqn,
      previewId = ids[index],
      previewParams = resolved,
    }

    if preview.method_params and #preview.method_params > 0 then
      screenshot.methodParams = preview.method_params
    end

    table.insert(result, screenshot)
  end

  return result, dropped
end

function M.build(opts)
  local built, dropped = screenshots(opts.previews)

  return {
    layoutlibPath = opts.layoutlib_path,
    outputFolder = opts.output_dir,
    metaDataFolder = opts.metadata_dir,
    resultsFilePath = opts.results_path,
    namespace = opts.namespace,
    resourceApkPath = opts.resource_apk_path,
    classPath = opts.class_path,
    projectClassPath = opts.project_class_path,
    screenshots = built,
  },
    dropped
end

return M

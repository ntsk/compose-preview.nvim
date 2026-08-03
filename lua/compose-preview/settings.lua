local M = {}

local function screenshots(previews)
  local counters = {}
  local result = {}

  for _, preview in ipairs(previews) do
    local index = counters[preview.method_fqn] or 0
    counters[preview.method_fqn] = index + 1

    table.insert(result, {
      methodFQN = preview.method_fqn,
      previewId = preview.method_fqn .. '_' .. index,
      previewParams = preview.params or {},
    })
  end

  return result
end

function M.build(opts)
  return {
    layoutlibPath = opts.layoutlib_path,
    outputFolder = opts.output_dir,
    metaDataFolder = opts.metadata_dir,
    resultsFilePath = opts.results_path,
    namespace = opts.namespace,
    resourceApkPath = opts.resource_apk_path,
    classPath = opts.class_path,
    projectClassPath = opts.project_class_path,
    screenshots = screenshots(opts.previews),
  }
end

return M

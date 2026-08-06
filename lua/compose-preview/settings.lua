local log = require('compose-preview.log')
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

  for index, preview in ipairs(previews) do
    local resolved, dropped = params.normalize(preview.params)
    if #dropped > 0 then
      log.write('WARN', ('%s: dropped unresolvable @Preview attributes: %s')
        :format(preview.method_fqn, table.concat(dropped, ', ')))
    end

    table.insert(result, {
      methodFQN = preview.method_fqn,
      previewId = ids[index],
      previewParams = resolved,
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

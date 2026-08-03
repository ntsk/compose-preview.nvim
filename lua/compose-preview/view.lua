local settings = require('compose-preview.settings')

local M = {}

function M.items(previews, results, output_dir_name)
  local ids = settings.preview_ids(previews)

  local by_id = {}
  for _, result in ipairs(results.previews or {}) do
    by_id[result.preview_id] = result
  end

  local items = {}
  for index, preview in ipairs(previews) do
    local result = by_id[ids[index]]
    local params = preview.params or {}
    local item = {
      name = preview.name,
      label = params.name or preview.name,
      line = preview.line,
      preview_id = ids[index],
    }

    if result and result.ok and result.image_path then
      item.ok = true
      item.image_src = output_dir_name .. '/' .. result.image_path
    else
      item.ok = false
      item.error = result and result.error or { message = 'レンダリング結果がありません' }
    end

    table.insert(items, item)
  end

  return items
end

return M

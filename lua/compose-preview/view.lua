local settings = require('compose-preview.settings')

local M = {}

local MISSING = { error = { message = 'no render result' } }

local function group_by_preview_id(results)
  local grouped = {}

  for _, result in ipairs(results.previews or {}) do
    local bucket = grouped[result.preview_id] or {}
    table.insert(bucket, result)
    grouped[result.preview_id] = bucket
  end

  return grouped
end

function M.items(previews, results, output_dir_name)
  local ids = settings.preview_ids(previews)
  local grouped = group_by_preview_id(results)
  local items = {}

  for index, preview in ipairs(previews) do
    local label = (preview.params or {}).name or preview.name
    local matched = grouped[ids[index]] or { MISSING }

    for position, result in ipairs(matched) do
      local ok = result.ok == true and result.image_path ~= nil

      table.insert(items, {
        name = preview.name,
        label = #matched > 1 and ('%s (%d/%d)'):format(label, position, #matched) or label,
        line = preview.line,
        preview_id = ids[index],
        ok = ok,
        image_src = ok and (output_dir_name .. '/' .. result.image_path) or nil,
        error = not ok and (result.error or MISSING.error) or nil,
      })
    end
  end

  return items
end

return M

local settings = require('compose-preview.settings')

local M = {}

function M.items(previews, results, output_dir_name)
  local ids = settings.preview_ids(previews)

  local by_id = {}
  for _, result in ipairs(results.previews or {}) do
    local bucket = by_id[result.preview_id]
    if not bucket then
      bucket = {}
      by_id[result.preview_id] = bucket
    end
    table.insert(bucket, result)
  end

  local items = {}
  for index, preview in ipairs(previews) do
    local params = preview.params or {}
    local label = params.name or preview.name
    local matched = by_id[ids[index]] or {}

    if #matched == 0 then
      table.insert(items, {
        name = preview.name,
        label = label,
        line = preview.line,
        preview_id = ids[index],
        ok = false,
        error = { message = 'no render result' },
      })
    else
      for position, result in ipairs(matched) do
        local item = {
          name = preview.name,
          label = #matched > 1 and ('%s (%d/%d)'):format(label, position, #matched) or label,
          line = preview.line,
          preview_id = ids[index],
        }

        if result.ok and result.image_path then
          item.ok = true
          item.image_src = output_dir_name .. '/' .. result.image_path
        else
          item.ok = false
          item.error = result.error or { message = 'no render result' }
        end

        table.insert(items, item)
      end
    end
  end

  return items
end

return M

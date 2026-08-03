local M = {}

local function value(raw)
  if raw == nil or raw == vim.NIL then
    return nil
  end
  return raw
end

local function normalize_error(raw)
  local err = value(raw)
  if not err then
    return nil
  end

  return {
    status = value(err.status),
    message = value(err.message),
    stack_trace = value(err.stackTrace),
    missing_classes = value(err.missingClasses) or {},
  }
end

local function normalize_preview(raw)
  local err = normalize_error(raw.error)

  return {
    preview_id = value(raw.previewId),
    method_fqn = value(raw.methodFQN),
    image_path = value(raw.imagePath),
    error = err,
    ok = err == nil,
  }
end

function M.parse(json)
  local ok, decoded = pcall(vim.json.decode, json)
  if not ok then
    return nil, tostring(decoded)
  end
  if type(decoded) ~= 'table' then
    return nil, 'results.json のトップレベルがオブジェクトではありません'
  end

  local previews = {}
  for _, raw in ipairs(value(decoded.screenshotResults) or {}) do
    table.insert(previews, normalize_preview(raw))
  end

  return {
    global_error = value(decoded.globalError),
    previews = previews,
  }
end

return M

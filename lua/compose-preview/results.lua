local M = {}

local function value(raw)
  if raw == nil or raw == vim.NIL then
    return nil
  end
  return raw
end

local function strip_html(text)
  local stripped = tostring(text):gsub('<[^>]*>', '')
  return vim.trim(stripped:gsub('%s*%(Details%)%s*$', ''))
end

local function normalize_problems(raw)
  local problems = {}

  for _, problem in ipairs(value(raw) or {}) do
    local message = value(problem.html)
    table.insert(problems, {
      message = message and strip_html(message) or nil,
      stack_trace = value(problem.stackTrace),
    })
  end

  return problems
end

local function present(text)
  if text and text ~= '' then
    return text
  end
  return nil
end

local function normalize_error(raw)
  local err = value(raw)
  if not err then
    return nil
  end

  local problems = normalize_problems(err.problems)
  local message = present(value(err.message))
    or (problems[1] and present(problems[1].message))
    or present(value(err.status))

  return {
    status = value(err.status),
    message = message,
    stack_trace = present(value(err.stackTrace)),
    problems = problems,
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
    return nil, 'top level of results.json is not an object'
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

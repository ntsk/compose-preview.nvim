local M = {}

local CONSTANTS = {
  UI_MODE_NIGHT_UNDEFINED = 0x00,
  UI_MODE_NIGHT_NO = 0x10,
  UI_MODE_NIGHT_YES = 0x20,
  UI_MODE_NIGHT_MASK = 0x30,
  UI_MODE_TYPE_UNDEFINED = 0x00,
  UI_MODE_TYPE_NORMAL = 0x01,
  UI_MODE_TYPE_DESK = 0x02,
  UI_MODE_TYPE_CAR = 0x03,
  UI_MODE_TYPE_TELEVISION = 0x04,
  UI_MODE_TYPE_APPLIANCE = 0x05,
  UI_MODE_TYPE_WATCH = 0x06,
  UI_MODE_TYPE_VR_HEADSET = 0x07,
  UI_MODE_TYPE_MASK = 0x0f,
  NONE = -1,
  RED_DOMINATED = 0,
  GREEN_DOMINATED = 1,
  BLUE_DOMINATED = 2,
  YELLOW_DOMINATED = 3,
}

local function strip_digit_separators(text)
  return (vim.trim(tostring(text)):gsub('_', ''))
end

local function resolve_term(term)
  term = vim.trim(term)
  if term == '' then
    return nil
  end

  local negative = false
  local body = term:match('^%-%s*(.+)$')
  if body then
    negative, term = true, body
  end

  local literal = strip_digit_separators(term)
  local value = tonumber(literal)
  if not value and literal:match('^0[xX]%x+$') then
    value = tonumber(literal:sub(3), 16)
  end

  if not value then
    local symbol = term:match('([%w_]+)%s*$')
    value = symbol and CONSTANTS[symbol] or nil
  end

  if not value then
    return nil
  end

  return negative and -value or value
end

function M.resolve_number(expression)
  if expression == nil then
    return nil
  end

  local normalized = tostring(expression):gsub('%f[%w]or%f[%W]', '|')
  local total, seen = 0, false

  for piece in normalized:gmatch('[^|]+') do
    local value = resolve_term(piece)
    if not value then
      return nil
    end
    total = seen and bit.bor(total, value) or value
    seen = true
  end

  if not seen then
    return nil
  end

  return tostring(math.floor(total))
end

function M.resolve_float(expression)
  if expression == nil then
    return nil
  end

  local text = strip_digit_separators(expression):gsub('[fFdD]$', '')
  local value = tonumber(text)
  if not value then
    return nil
  end

  if value == math.floor(value) then
    return ('%.1f'):format(value)
  end

  return tostring(value)
end

local RESOLVERS = {
  apiLevel = M.resolve_number,
  widthDp = M.resolve_number,
  heightDp = M.resolve_number,
  uiMode = M.resolve_number,
  wallpaper = M.resolve_number,
  backgroundColor = M.resolve_number,
  fontScale = M.resolve_float,
}

function M.normalize(raw)
  local resolved = {}
  local dropped = {}

  for key, value in pairs(raw or {}) do
    local resolve = RESOLVERS[key]

    if not resolve then
      resolved[key] = value
    else
      local normalized = resolve(value)
      if normalized then
        resolved[key] = normalized
      else
        table.insert(dropped, key)
      end
    end
  end

  table.sort(dropped)

  return resolved, dropped
end

return M

local M = {}

M.CONSTANTS = {
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

M.INT_ATTRIBUTES = {
  apiLevel = true,
  widthDp = true,
  heightDp = true,
  uiMode = true,
  wallpaper = true,
  backgroundColor = true,
}

M.FLOAT_ATTRIBUTES = {
  fontScale = true,
}

local function clean(text)
  return vim.trim(tostring(text)):gsub('_', '')
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

  local literal = clean(term)
  local value = tonumber(literal)
  if not value and literal:match('^0[xX]%x+$') then
    value = tonumber(literal:sub(3), 16)
  end

  if not value then
    local symbol = term:match('([%w_]+)%s*$')
    value = symbol and M.CONSTANTS[symbol] or nil
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

  local text = clean(expression):gsub('[fFdD]$', '')
  local value = tonumber(text)
  if not value then
    return nil
  end

  if value == math.floor(value) then
    return ('%.1f'):format(value)
  end

  return tostring(value)
end

function M.normalize(raw)
  local resolved = {}
  local dropped = {}

  for key, value in pairs(raw or {}) do
    if M.INT_ATTRIBUTES[key] then
      local number = M.resolve_number(value)
      if number then
        resolved[key] = number
      else
        table.insert(dropped, key)
      end
    elseif M.FLOAT_ATTRIBUTES[key] then
      local number = M.resolve_float(value)
      if number then
        resolved[key] = number
      else
        table.insert(dropped, key)
      end
    else
      resolved[key] = value
    end
  end

  table.sort(dropped)

  return resolved, dropped
end

return M

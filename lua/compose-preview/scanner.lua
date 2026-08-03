local M = {}

local function text(node, source)
  return vim.treesitter.get_node_text(node, source)
end

local function last_type_identifier(node, source)
  local found
  local function walk(n)
    if n:type() == 'type_identifier' then
      found = text(n, source)
    end
    for child in n:iter_children() do
      walk(child)
    end
  end
  walk(node)
  return found
end

local function argument_value(node, source)
  if node:type() == 'string_literal' then
    for child in node:iter_children() do
      if child:type() == 'string_content' then
        return text(child, source)
      end
    end
    return ''
  end
  return text(node, source)
end

local function parse_arguments(value_arguments, source)
  local params = {}
  if not value_arguments then
    return params
  end

  for argument in value_arguments:iter_children() do
    if argument:type() == 'value_argument' then
      local key, value, seen_equals
      for child in argument:iter_children() do
        if child:type() == '=' then
          seen_equals = true
        elseif seen_equals then
          value = child
        else
          key = child
        end
      end
      if key and value then
        params[text(key, source)] = argument_value(value, source)
      end
    end
  end

  return params
end

local function annotation_parts(annotation, source)
  for child in annotation:iter_children() do
    local kind = child:type()
    if kind == 'user_type' then
      return last_type_identifier(child, source), nil
    elseif kind == 'constructor_invocation' then
      local name, value_arguments
      for grandchild in child:iter_children() do
        if grandchild:type() == 'user_type' then
          name = last_type_identifier(grandchild, source)
        elseif grandchild:type() == 'value_arguments' then
          value_arguments = grandchild
        end
      end
      return name, value_arguments
    end
  end
end

local function preview_annotations(declaration, source)
  local found = {}
  for child in declaration:iter_children() do
    if child:type() == 'modifiers' then
      for modifier in child:iter_children() do
        if modifier:type() == 'annotation' then
          local name, value_arguments = annotation_parts(modifier, source)
          if name == 'Preview' then
            table.insert(found, parse_arguments(value_arguments, source))
          end
        end
      end
    end
  end
  return found
end

local function function_name_node(declaration)
  local seen_fun
  for child in declaration:iter_children() do
    if child:type() == 'fun' then
      seen_fun = true
    elseif seen_fun and child:type() == 'simple_identifier' then
      return child
    end
  end
end

local function package_name(root, source)
  for child in root:iter_children() do
    if child:type() == 'package_header' then
      for grandchild in child:iter_children() do
        if grandchild:type() == 'identifier' then
          return text(grandchild, source)
        end
      end
    end
  end
end

local function file_class_name(filename)
  local stem = vim.fn.fnamemodify(filename, ':t:r')
  return stem:sub(1, 1):upper() .. stem:sub(2) .. 'Kt'
end

function M.scan(source, filename)
  local parser = vim.treesitter.get_string_parser(source, 'kotlin')
  local root = parser:parse()[1]:root()

  local prefix = package_name(root, source)
  local class_name = file_class_name(filename)
  local qualifier = prefix and (prefix .. '.' .. class_name) or class_name

  local previews = {}
  for child in root:iter_children() do
    if child:type() == 'function_declaration' then
      local name_node = function_name_node(child)
      if name_node then
        local name = text(name_node, source)
        for _, params in ipairs(preview_annotations(child, source)) do
          table.insert(previews, {
            name = name,
            method_fqn = qualifier .. '.' .. name,
            line = name_node:start() + 1,
            params = params,
          })
        end
      end
    end
  end

  return previews
end

return M

local multipreview = require('compose-preview.multipreview')

local M = {}

local function text(node, source)
  return vim.treesitter.get_node_text(node, source)
end

--- Iterates the direct children of `node` whose type is `kind`.
local function children(node, kind)
  return coroutine.wrap(function()
    for node_child in node:iter_children() do
      if node_child:type() == kind then
        coroutine.yield(node_child)
      end
    end
  end)
end

--- Returns the first direct child of `node` whose type is `kind`.
local function child(node, kind)
  for node_child in node:iter_children() do
    if node_child:type() == kind then
      return node_child
    end
  end
end

local function last_type_identifier(node, source)
  local found

  local function walk(current)
    if current:type() == 'type_identifier' then
      found = text(current, source)
    end
    for descendant in current:iter_children() do
      walk(descendant)
    end
  end

  walk(node)
  return found
end

local function argument_value(node, source)
  if node:type() ~= 'string_literal' then
    return text(node, source)
  end

  local content = child(node, 'string_content')
  return content and text(content, source) or ''
end

local function parse_arguments(value_arguments, source)
  local params = {}
  if not value_arguments then
    return params
  end

  for argument in children(value_arguments, 'value_argument') do
    local key, value, seen_equals
    for node in argument:iter_children() do
      if node:type() == '=' then
        seen_equals = true
      elseif seen_equals then
        value = node
      else
        key = node
      end
    end
    if key and value then
      params[text(key, source)] = argument_value(value, source)
    end
  end

  return params
end

local function annotation_parts(annotation, source)
  local bare = child(annotation, 'user_type')
  if bare then
    return last_type_identifier(bare, source), nil
  end

  local invocation = child(annotation, 'constructor_invocation')
  if not invocation then
    return nil
  end

  local name = child(invocation, 'user_type')
  return name and last_type_identifier(name, source), child(invocation, 'value_arguments')
end

local function preview_annotations(declaration, source)
  local found = {}

  for modifiers in children(declaration, 'modifiers') do
    for annotation in children(modifiers, 'annotation') do
      local name, value_arguments = annotation_parts(annotation, source)
      if name == 'Preview' then
        table.insert(found, parse_arguments(value_arguments, source))
      else
        vim.list_extend(found, multipreview.expand(name) or {})
      end
    end
  end

  return found
end

local function function_name_node(declaration)
  local seen_fun
  for node in declaration:iter_children() do
    if node:type() == 'fun' then
      seen_fun = true
    elseif seen_fun and node:type() == 'simple_identifier' then
      return node
    end
  end
end

local function imports(root, source)
  local by_simple_name = {}

  for list in children(root, 'import_list') do
    for header in children(list, 'import_header') do
      local identifier = child(header, 'identifier')
      if identifier then
        local fqn = text(identifier, source)
        by_simple_name[fqn:match('([^.]+)$')] = fqn
      end
    end
  end

  return by_simple_name
end

local function provider_reference(value_arguments, source)
  if not value_arguments then
    return nil
  end

  for argument in children(value_arguments, 'value_argument') do
    for node in argument:iter_children() do
      local kind = node:type()
      if kind == 'callable_reference' or kind == 'navigation_expression' then
        local reference = text(node, source)
        if reference:match('::%s*class%s*$') then
          return (reference:gsub('%s*::%s*class%s*$', ''))
        end
      end
    end
  end
end

local function resolve_provider(reference, context)
  if not reference or reference == '' then
    return nil
  end

  if reference:find('%.') then
    return reference
  end

  local imported = context.imports[reference]
  if imported then
    return imported
  end

  if context.package then
    return context.package .. '.' .. reference
  end

  return reference
end

local function preview_parameter(annotation, source, context)
  local name, value_arguments = annotation_parts(annotation, source)
  if name ~= 'PreviewParameter' then
    return nil
  end

  local provider = resolve_provider(provider_reference(value_arguments, source), context)
  if not provider then
    return nil
  end

  local entry = { provider = provider }
  local arguments = parse_arguments(value_arguments, source)
  if arguments.limit then
    entry.limit = arguments.limit
  end

  return entry
end

local function method_params(declaration, source, context)
  local found = {}

  for parameters in children(declaration, 'function_value_parameters') do
    for modifiers in children(parameters, 'parameter_modifiers') do
      for annotation in children(modifiers, 'annotation') do
        local entry = preview_parameter(annotation, source, context)
        if entry then
          table.insert(found, entry)
        end
      end
    end
  end

  return found
end

local function package_name(root, source)
  local header = child(root, 'package_header')
  local identifier = header and child(header, 'identifier')
  return identifier and text(identifier, source) or nil
end

local function file_class_name(filename)
  local stem = vim.fn.fnamemodify(filename, ':t:r')
  return stem:sub(1, 1):upper() .. stem:sub(2) .. 'Kt'
end

function M.scan(source, filename, language)
  language = language or 'kotlin'

  local ok, parser = pcall(vim.treesitter.get_string_parser, source, language)
  if not ok then
    return nil, ('the %s treesitter parser is not available (try :TSInstall %s)'):format(language, language)
  end

  local root = parser:parse()[1]:root()

  local prefix = package_name(root, source)
  local class_name = file_class_name(filename)
  local qualifier = prefix and (prefix .. '.' .. class_name) or class_name
  local context = { package = prefix, imports = imports(root, source) }

  local previews = {}

  for declaration in children(root, 'function_declaration') do
    local name_node = function_name_node(declaration)
    if name_node then
      local name = text(name_node, source)
      local parameters = method_params(declaration, source, context)

      for _, params in ipairs(preview_annotations(declaration, source)) do
        table.insert(previews, {
          name = name,
          method_fqn = qualifier .. '.' .. name,
          line = name_node:start() + 1,
          params = params,
          method_params = parameters,
        })
      end
    end
  end

  return previews
end

return M

local assets = require('compose-preview.assets')

local M = {}

local ENTITIES = {
  ['&'] = '&amp;',
  ['<'] = '&lt;',
  ['>'] = '&gt;',
  ['"'] = '&quot;',
  ["'"] = '&#39;',
}

function M.escape(text)
  return (tostring(text):gsub('[&<>"\']', ENTITIES))
end

local function render_card(item)
  local title = M.escape(item.label or item.name or '(unnamed)')
  local body

  if item.ok and item.image_src then
    body = ('<div class="card-body"><img src="%s" alt="%s"></div>'):format(M.escape(item.image_src), title)
  else
    local err = item.error or {}
    local problems = err.problems or {}
    local headline = err.message
    if not headline or headline == '' then
      headline = problems[1] and problems[1].message or err.status or 'rendering failed'
    end

    local parts = { '<div class="error">' }
    table.insert(parts, ('<strong>%s</strong>'):format(M.escape(headline)))

    if err.stack_trace and err.stack_trace ~= '' then
      table.insert(parts, ('<pre>%s</pre>'):format(M.escape(err.stack_trace)))
    end

    for index, problem in ipairs(problems) do
      local text = problem.message or ''
      if index > 1 or text ~= headline then
        table.insert(parts, ('<p>%s</p>'):format(M.escape(text)))
      end
      if problem.stack_trace and problem.stack_trace ~= '' then
        table.insert(
          parts,
          ('<details><summary>stack trace</summary><pre>%s</pre></details>'):format(M.escape(problem.stack_trace))
        )
      end
    end

    if err.missing_classes and #err.missing_classes > 0 then
      table.insert(parts, ('<pre>Missing classes:\n%s</pre>'):format(M.escape(table.concat(err.missing_classes, '\n'))))
    end

    table.insert(parts, '</div>')
    body = table.concat(parts)
  end

  return ('<div class="card"><div class="card-title">%s</div>%s</div>'):format(title, body)
end

function M.build(opts)
  local items = opts.items or {}
  local parts = {}

  local function add(line)
    table.insert(parts, line)
  end

  add('<!doctype html>')
  add('<html lang="en"><head><meta charset="utf-8">')
  add(('<title>%s - Compose Preview</title>'):format(M.escape(opts.title or 'Compose Preview')))
  add('<meta name="viewport" content="width=device-width, initial-scale=1">')
  add(('<style>%s</style>'):format(assets.style()))
  add('</head><body>')

  add('<header>')
  add(('<h1>%s</h1>'):format(M.escape(opts.title or 'Compose Preview')))
  add(('<span class="meta">%d previews</span>'):format(#items))
  if opts.generated_at then
    add(('<span class="meta">%s</span>'):format(M.escape(opts.generated_at)))
  end
  add('</header>')

  if opts.global_error then
    add(('<div class="banner">%s</div>'):format(M.escape(opts.global_error)))
  end

  if #items == 0 then
    add('<p class="empty">No @Preview to show.</p>')
  else
    add('<div class="grid">')
    for _, item in ipairs(items) do
      add(render_card(item))
    end
    add('</div>')
  end

  if opts.token then
    add(('<script>window.__composePreviewToken = "%s";</script>'):format(M.escape(opts.token)))
    add(('<script>%s</script>'):format(assets.script()))
  end

  add('</body></html>')

  return table.concat(parts, '\n')
end

function M.token_script(token)
  return ('window.__composePreviewLatest = "%s";'):format(M.escape(token))
end

return M

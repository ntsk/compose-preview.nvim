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

local STYLE = [[
:root {
  --bg: #ffffff;
  --fg: #1f2328;
  --muted: #656d76;
  --border: #d1d9e0;
  --card: #f6f8fa;
  --error-bg: #fff1f0;
  --error-fg: #b32b28;
  --error-border: #ffb3b0;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #0d1117;
    --fg: #e6edf3;
    --muted: #8b949e;
    --border: #30363d;
    --card: #161b22;
    --error-bg: #2b1214;
    --error-fg: #ff8d85;
    --error-border: #6b2a2a;
  }
}
* { box-sizing: border-box; }
body {
  margin: 0;
  padding: 24px;
  background: var(--bg);
  color: var(--fg);
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
  line-height: 1.5;
}
header {
  display: flex;
  align-items: baseline;
  gap: 12px;
  flex-wrap: wrap;
  border-bottom: 1px solid var(--border);
  padding-bottom: 12px;
  margin-bottom: 24px;
}
h1 { font-size: 18px; margin: 0; font-weight: 600; }
.meta { color: var(--muted); font-size: 13px; }
.grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 20px;
}
.card {
  border: 1px solid var(--border);
  border-radius: 8px;
  overflow: hidden;
  background: var(--card);
}
.card-title {
  padding: 8px 12px;
  font-size: 13px;
  font-weight: 600;
  border-bottom: 1px solid var(--border);
  word-break: break-all;
}
.card-body {
  padding: 12px;
  display: flex;
  justify-content: center;
  background-image:
    linear-gradient(45deg, rgba(128,128,128,.12) 25%, transparent 25%),
    linear-gradient(-45deg, rgba(128,128,128,.12) 25%, transparent 25%),
    linear-gradient(45deg, transparent 75%, rgba(128,128,128,.12) 75%),
    linear-gradient(-45deg, transparent 75%, rgba(128,128,128,.12) 75%);
  background-size: 16px 16px;
  background-position: 0 0, 0 8px, 8px -8px, -8px 0;
}
.card-body img { max-width: 100%; height: auto; display: block; }
.banner, .error {
  background: var(--error-bg);
  color: var(--error-fg);
  border: 1px solid var(--error-border);
  border-radius: 6px;
  padding: 12px;
  font-size: 13px;
}
.banner { margin-bottom: 20px; }
.error { border: none; border-radius: 0; }
.error pre {
  margin: 8px 0 0;
  overflow-x: auto;
  font-size: 12px;
  white-space: pre-wrap;
  word-break: break-word;
}
.empty { color: var(--muted); }
]]

local SCRIPT = [[
(function () {
  var current = window.__composePreviewToken;
  if (!current) return;
  var key = 'compose-preview-scroll';
  var saved = sessionStorage.getItem(key);
  if (saved) window.scrollTo(0, parseInt(saved, 10) || 0);
  window.addEventListener('scroll', function () {
    sessionStorage.setItem(key, String(window.scrollY));
  });
  setInterval(function () {
    var probe = document.createElement('script');
    probe.src = 'token.js?t=' + Date.now();
    probe.onload = function () {
      if (window.__composePreviewLatest && window.__composePreviewLatest !== current) {
        location.reload();
      }
      probe.remove();
    };
    probe.onerror = function () { probe.remove(); };
    document.head.appendChild(probe);
  }, 1500);
})();
]]

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
        table.insert(parts, ('<details><summary>stack trace</summary><pre>%s</pre></details>')
          :format(M.escape(problem.stack_trace)))
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
  add(('<style>%s</style>'):format(STYLE))
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
    add(('<script>%s</script>'):format(SCRIPT))
  end

  add('</body></html>')

  return table.concat(parts, '\n')
end

function M.token_script(token)
  return ('window.__composePreviewLatest = "%s";'):format(M.escape(token))
end

return M

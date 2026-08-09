local log = require('compose-preview.log')

describe('log.format', function()
  it('joins timestamp, level and message into one line', function()
    local line = log.format('ERROR', 'build failed', '2026-08-06 22:00:00')

    assert.are.equal('[2026-08-06 22:00:00] ERROR build failed', line)
  end)

  it('indents continuation lines of a multi-line message', function()
    local line = log.format('ERROR', 'a\nb', '2026-08-06 22:00:00')

    assert.are.equal('[2026-08-06 22:00:00] ERROR a\n    b', line)
  end)
end)

describe('log.write', function()
  it('appends to the given file', function()
    local path = vim.fn.tempname()

    log.write('INFO', 'first', { path = path })
    log.write('ERROR', 'second', { path = path })

    local lines = vim.fn.readfile(path)
    assert.are.equal(2, #lines)
    assert.is_truthy(lines[1]:find('first', 1, true))
    assert.is_truthy(lines[2]:find('ERROR', 1, true))
    assert.is_truthy(lines[2]:find('second', 1, true))
  end)

  it('creates the parent directory when missing', function()
    local path = vim.fs.joinpath(vim.fn.tempname(), 'nested', 'compose-preview.log')

    log.write('INFO', 'x', { path = path })

    assert.are.equal(1, vim.fn.filereadable(path))
  end)

  it('writes a multi-line message as multiple lines', function()
    local path = vim.fn.tempname()

    log.write('ERROR', 'line1\nline2', { path = path })

    assert.are.equal(2, #vim.fn.readfile(path))
  end)

  it('starts the file over once it grows past the size limit', function()
    local path = vim.fn.tempname()

    log.write('INFO', ('x'):rep(200), { path = path, max_bytes = 100 })
    log.write('INFO', 'after rotation', { path = path, max_bytes = 100 })

    local lines = vim.fn.readfile(path)
    assert.are.equal(1, #lines)
    assert.is_truthy(lines[1]:find('after rotation', 1, true))
  end)

  it('keeps appending below the size limit', function()
    local path = vim.fn.tempname()

    log.write('INFO', 'first', { path = path, max_bytes = 100 })
    log.write('INFO', 'second', { path = path, max_bytes = 100 })

    assert.are.equal(2, #vim.fn.readfile(path))
  end)

  it('tolerates non-string messages', function()
    local path = vim.fn.tempname()

    log.write('INFO', 42, { path = path })

    assert.is_truthy(vim.fn.readfile(path)[1]:find('42', 1, true))
  end)
end)

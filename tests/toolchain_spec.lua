local toolchain = require('compose-preview.toolchain')

local function tmpdir()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, 'p')
  return dir
end

describe('toolchain.artifact_url', function()
  it('group のドットをスラッシュに変換して Google Maven の URL を組み立てる', function()
    local url = toolchain.artifact_url('com.android.tools.compose', 'compose-preview-renderer', '0.0.1-alpha16')

    assert.are.equal(
      'https://dl.google.com/dl/android/maven2/com/android/tools/compose/'
        .. 'compose-preview-renderer/0.0.1-alpha16/compose-preview-renderer-0.0.1-alpha16.jar',
      url
    )
  end)

  it('layoutlib-runtime の URL も同じ規則で組み立てる', function()
    local url = toolchain.artifact_url('com.android.tools.layoutlib', 'layoutlib-runtime', '17.0.1')

    assert.are.equal(
      'https://dl.google.com/dl/android/maven2/com/android/tools/layoutlib/'
        .. 'layoutlib-runtime/17.0.1/layoutlib-runtime-17.0.1.jar',
      url
    )
  end)
end)

describe('toolchain.paths', function()
  it('バージョンごとに異なるパスへ配置する', function()
    local a = toolchain.paths({ cache_dir = '/cache', renderer_version = '0.0.1-alpha16', layoutlib_version = '17.0.1' })
    local b = toolchain.paths({ cache_dir = '/cache', renderer_version = '0.0.1-alpha15', layoutlib_version = '17.0.1' })

    assert.are_not.equal(a.renderer_jar, b.renderer_jar)
  end)

  it('renderer は jar、layoutlib は展開先ディレクトリを指す', function()
    local paths = toolchain.paths({ cache_dir = '/cache', renderer_version = '0.0.1-alpha16', layoutlib_version = '17.0.1' })

    assert.are.equal('/cache/compose-preview-renderer-0.0.1-alpha16.jar', paths.renderer_jar)
    assert.are.equal('/cache/layoutlib-17.0.1', paths.layoutlib_dir)
  end)

  it('バージョン未指定なら既定バージョンを使う', function()
    local paths = toolchain.paths({ cache_dir = '/cache' })

    assert.are.equal('/cache/compose-preview-renderer-' .. toolchain.RENDERER_VERSION .. '.jar', paths.renderer_jar)
    assert.are.equal('/cache/layoutlib-' .. toolchain.LAYOUTLIB_VERSION, paths.layoutlib_dir)
  end)
end)

describe('toolchain.is_installed', function()
  it('何も無ければ false', function()
    assert.is_false(toolchain.is_installed({ cache_dir = tmpdir() }))
  end)

  it('jar だけあっても layoutlib が展開されていなければ false', function()
    local dir = tmpdir()
    local paths = toolchain.paths({ cache_dir = dir })
    vim.fn.writefile({ '' }, paths.renderer_jar)

    assert.is_false(toolchain.is_installed({ cache_dir = dir }))
  end)

  it('jar と展開済み layoutlib が揃っていれば true', function()
    local dir = tmpdir()
    local paths = toolchain.paths({ cache_dir = dir })
    vim.fn.writefile({ '' }, paths.renderer_jar)
    vim.fn.mkdir(paths.layoutlib_dir .. '/data/fonts', 'p')

    assert.is_true(toolchain.is_installed({ cache_dir = dir }))
  end)
end)

describe('toolchain.install', function()
  it('インストール済みならダウンロードせず paths を返す', function()
    local dir = tmpdir()
    local paths = toolchain.paths({ cache_dir = dir })
    vim.fn.writefile({ '' }, paths.renderer_jar)
    vim.fn.mkdir(paths.layoutlib_dir .. '/data/fonts', 'p')

    local done, received_err, received_paths = false, 'unset', nil
    toolchain.install({ cache_dir = dir }, function(err, result)
      done, received_err, received_paths = true, err, result
    end)
    vim.wait(1000, function()
      return done
    end)

    assert.is_true(done)
    assert.is_nil(received_err)
    assert.are.equal(paths.renderer_jar, received_paths.renderer_jar)
  end)
end)

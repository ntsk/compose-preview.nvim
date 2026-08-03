local toolchain = require('compose-preview.toolchain')

local function tmpdir()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, 'p')
  return dir
end

local function install_fake(dir)
  local paths = toolchain.paths({ cache_dir = dir })
  vim.fn.mkdir(vim.fs.dirname(paths.renderer_jar), 'p')
  vim.fn.writefile({ '' }, paths.renderer_jar)
  vim.fn.writefile({ '' }, paths.layoutlib_jar)
  vim.fn.mkdir(paths.layoutlib_dir .. '/data/fonts', 'p')
  vim.fn.writefile({ '' }, paths.framework_res_jar)
  return paths
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
end)

describe('toolchain の既定バージョン', function()
  it('layoutlib のクラスは 17.0.0 を使う', function()
    assert.are.equal('17.0.0', toolchain.LAYOUTLIB_VERSION)
  end)

  it('layoutlib のデータとリソースは 17.0.1 を使う', function()
    assert.are.equal('17.0.1', toolchain.LAYOUTLIB_DATA_VERSION)
  end)
end)

describe('toolchain.paths', function()
  it('レンダラと layoutlib クラスの jar、layoutlib データの展開先を返す', function()
    local paths = toolchain.paths({ cache_dir = '/cache' })

    assert.are.equal('/cache/compose-preview-renderer-' .. toolchain.RENDERER_VERSION .. '.jar', paths.renderer_jar)
    assert.are.equal('/cache/layoutlib-' .. toolchain.LAYOUTLIB_VERSION .. '.jar', paths.layoutlib_jar)
    assert.are.equal('/cache/layoutlib-data-' .. toolchain.LAYOUTLIB_DATA_VERSION, paths.layoutlib_dir)
  end)

  it('framework リソースは layoutlib データ内の data/framework_res.jar を指す', function()
    local paths = toolchain.paths({ cache_dir = '/cache' })

    assert.are.equal(paths.layoutlib_dir .. '/data/framework_res.jar', paths.framework_res_jar)
  end)

  it('バージョンごとに異なるパスへ配置する', function()
    local a = toolchain.paths({ cache_dir = '/cache', renderer_version = '0.0.1-alpha16' })
    local b = toolchain.paths({ cache_dir = '/cache', renderer_version = '0.0.1-alpha15' })

    assert.are_not.equal(a.renderer_jar, b.renderer_jar)
  end)

  it('レンダラ実行時の -cp はレンダラと layoutlib クラスの両方を含む', function()
    local paths = toolchain.paths({ cache_dir = '/cache' })

    assert.are.equal(paths.renderer_jar .. ':' .. paths.layoutlib_jar, paths.classpath)
  end)
end)

describe('toolchain.is_installed', function()
  it('何も無ければ false', function()
    assert.is_false(toolchain.is_installed({ cache_dir = tmpdir() }))
  end)

  it('layoutlib クラスの jar が欠けていれば false', function()
    local dir = tmpdir()
    local paths = install_fake(dir)
    vim.fn.delete(paths.layoutlib_jar)

    assert.is_false(toolchain.is_installed({ cache_dir = dir }))
  end)

  it('framework_res.jar が欠けていれば false', function()
    local dir = tmpdir()
    local paths = install_fake(dir)
    vim.fn.delete(paths.framework_res_jar)

    assert.is_false(toolchain.is_installed({ cache_dir = dir }))
  end)

  it('4つすべて揃っていれば true', function()
    local dir = tmpdir()
    install_fake(dir)

    assert.is_true(toolchain.is_installed({ cache_dir = dir }))
  end)
end)

describe('toolchain.install', function()
  it('インストール済みならダウンロードせず paths を返す', function()
    local dir = tmpdir()
    local expected = install_fake(dir)

    local done, received_err, received_paths = false, 'unset', nil
    toolchain.install({ cache_dir = dir }, function(err, result)
      done, received_err, received_paths = true, err, result
    end)
    vim.wait(1000, function()
      return done
    end)

    assert.is_true(done)
    assert.is_nil(received_err)
    assert.are.equal(expected.renderer_jar, received_paths.renderer_jar)
  end)
end)

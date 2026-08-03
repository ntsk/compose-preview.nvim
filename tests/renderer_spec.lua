local renderer = require('compose-preview.renderer')

describe('renderer.parse_java_version', function()
  it('新しい形式のバージョンからメジャー番号を取り出す', function()
    assert.are.equal(21, renderer.parse_java_version('openjdk version "21.0.10" 2026-01-20'))
    assert.are.equal(17, renderer.parse_java_version('openjdk version "17.0.2" 2022-01-18'))
  end)

  it('1.x 形式は 2 番目の数字をメジャー番号とみなす', function()
    assert.are.equal(8, renderer.parse_java_version('java version "1.8.0_301"'))
  end)

  it('複数行の出力でも 1 行目から取り出す', function()
    local output = table.concat({
      'openjdk version "21.0.10" 2026-01-20',
      'OpenJDK Runtime Environment Corretto-21.0.10.7.1',
      'OpenJDK 64-Bit Server VM',
    }, '\n')

    assert.are.equal(21, renderer.parse_java_version(output))
  end)

  it('解析できなければ nil を返す', function()
    assert.is_nil(renderer.parse_java_version('command not found'))
  end)
end)

describe('renderer.MINIMUM_JAVA_VERSION', function()
  it('layoutlib の要求に合わせて 21 を要求する', function()
    assert.are.equal(21, renderer.MINIMUM_JAVA_VERSION)
  end)
end)

describe('renderer.command', function()
  it('レンダラと layoutlib を -cp に並べて main クラスを呼ぶ', function()
    local cmd = renderer.command({
      java = '/jdk21/bin/java',
      classpath = '/cache/renderer.jar:/cache/layoutlib.jar',
      settings_path = '/work/settings.json',
    })

    assert.are.same({
      '/jdk21/bin/java',
      '-cp',
      '/cache/renderer.jar:/cache/layoutlib.jar',
      'com.android.tools.render.common.MainKt',
      '/work/settings.json',
    }, cmd)
  end)
end)

describe('renderer.render', function()
  it('java が見つからなければエラーを返す', function()
    local done, received_err = false, nil
    renderer.render({
      java = '/nonexistent/java',
      classpath = '/cache/renderer.jar',
      settings_path = '/work/settings.json',
      results_path = '/work/results.json',
    }, function(err)
      done, received_err = true, err
    end)
    vim.wait(5000, function()
      return done
    end)

    assert.is_true(done)
    assert.is_string(received_err)
  end)
end)

local params = require('compose-preview.params')

describe('params.resolve_number', function()
  it('passes decimal literals through', function()
    assert.are.equal('320', params.resolve_number('320'))
  end)

  it('resolves hex literals to decimal', function()
    assert.are.equal('255', params.resolve_number('0xFF'))
  end)

  it('ignores underscores in literals', function()
    assert.are.equal('1000', params.resolve_number('1_000'))
  end)

  it('keeps negative literals', function()
    assert.are.equal('-1', params.resolve_number('-1'))
  end)

  it('resolves a qualified Configuration constant', function()
    assert.are.equal('32', params.resolve_number('Configuration.UI_MODE_NIGHT_YES'))
  end)

  it('resolves a bare constant name', function()
    assert.are.equal('16', params.resolve_number('UI_MODE_NIGHT_NO'))
  end)

  it('resolves a fully qualified constant', function()
    assert.are.equal('32', params.resolve_number('android.content.res.Configuration.UI_MODE_NIGHT_YES'))
  end)

  it('folds a Kotlin "or" expression', function()
    assert.are.equal(
      '33',
      params.resolve_number('Configuration.UI_MODE_NIGHT_YES or Configuration.UI_MODE_TYPE_NORMAL')
    )
  end)

  it('folds a pipe expression', function()
    assert.are.equal('33', params.resolve_number('Configuration.UI_MODE_NIGHT_YES|Configuration.UI_MODE_TYPE_NORMAL'))
  end)

  it('resolves Wallpapers constants', function()
    assert.are.equal('-1', params.resolve_number('Wallpapers.NONE'))
    assert.are.equal('0', params.resolve_number('Wallpapers.RED_DOMINATED'))
  end)

  it('returns nil for an unknown symbol', function()
    assert.is_nil(params.resolve_number('MyOwnConstants.WHATEVER'))
  end)
end)

describe('params.resolve_float', function()
  it('strips the Kotlin float suffix', function()
    assert.are.equal('2.0', params.resolve_float('2f'))
    assert.are.equal('1.5', params.resolve_float('1.5f'))
  end)

  it('accepts a plain number', function()
    assert.are.equal('1.25', params.resolve_float('1.25'))
  end)

  it('returns nil for an unknown symbol', function()
    assert.is_nil(params.resolve_float('SomeScale.BIG'))
  end)
end)

describe('params.normalize', function()
  it('leaves string and boolean attributes untouched', function()
    local resolved = params.normalize({ name = 'Dark', showBackground = 'true', device = 'id:pixel_4' })

    assert.are.equal('Dark', resolved.name)
    assert.are.equal('true', resolved.showBackground)
    assert.are.equal('id:pixel_4', resolved.device)
  end)

  it('resolves uiMode constants to numbers', function()
    local resolved = params.normalize({ uiMode = 'Configuration.UI_MODE_NIGHT_YES' })

    assert.are.equal('32', resolved.uiMode)
  end)

  it('normalizes fontScale to a plain float', function()
    local resolved = params.normalize({ fontScale = '2f' })

    assert.are.equal('2.0', resolved.fontScale)
  end)

  it('resolves backgroundColor hex literals', function()
    local resolved = params.normalize({ backgroundColor = '0xFF0000' })

    assert.are.equal('16711680', resolved.backgroundColor)
  end)

  it('drops numeric attributes it cannot resolve', function()
    local resolved, dropped = params.normalize({ uiMode = 'MyConstants.NIGHT', name = 'Dark' })

    assert.is_nil(resolved.uiMode)
    assert.are.equal('Dark', resolved.name)
    assert.are.same({ 'uiMode' }, dropped)
  end)

  it('reports nothing dropped when everything resolves', function()
    local _, dropped = params.normalize({ widthDp = '320' })

    assert.are.same({}, dropped)
  end)
end)

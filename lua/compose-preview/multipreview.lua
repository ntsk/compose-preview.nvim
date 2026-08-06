local M = {}

local PHONE = 'spec:id=reference_phone,shape=Normal,width=411,height=891,unit=dp,dpi=420'
local PHONE_LANDSCAPE = 'spec:width = 411dp, height = 891dp, orientation = landscape, dpi = 420'
local FOLDABLE = 'spec:id=reference_foldable,shape=Normal,width=673,height=841,unit=dp,dpi=420'
local TABLET = 'spec:id=reference_tablet,shape=Normal,width=1280,height=800,unit=dp,dpi=240'
local DESKTOP = 'spec:id=reference_desktop,shape=Normal,width=1920,height=1080,unit=dp,dpi=160'

M.ANNOTATIONS = {
  PreviewLightDark = {
    { name = 'Light' },
    { name = 'Dark', uiMode = '33' },
  },
  PreviewFontScale = {
    { name = '85%', fontScale = '0.85' },
    { name = '100%', fontScale = '1.0' },
    { name = '115%', fontScale = '1.15' },
    { name = '130%', fontScale = '1.3' },
    { name = '150%', fontScale = '1.5' },
    { name = '180%', fontScale = '1.8' },
    { name = '200%', fontScale = '2.0' },
  },
  PreviewDynamicColors = {
    { name = 'Red', wallpaper = '0' },
    { name = 'Blue', wallpaper = '2' },
    { name = 'Green', wallpaper = '1' },
    { name = 'Yellow', wallpaper = '3' },
  },
  PreviewScreenSizes = {
    { name = 'Phone', showSystemUi = 'true', device = PHONE },
    { name = 'Phone - Landscape', showSystemUi = 'true', device = PHONE_LANDSCAPE },
    { name = 'Unfolded Foldable', showSystemUi = 'true', device = FOLDABLE },
    { name = 'Tablet', showSystemUi = 'true', device = TABLET },
    { name = 'Desktop', showSystemUi = 'true', device = DESKTOP },
  },
}

function M.expand(annotation_name)
  local entries = M.ANNOTATIONS[annotation_name]
  if not entries then
    return nil
  end

  return vim.deepcopy(entries)
end

return M

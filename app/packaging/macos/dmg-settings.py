# dmgbuild settings for the SimUtil drag-to-install DMG.
#   pip install dmgbuild
#   dmgbuild -s dmg-settings.py -D app=path/to/SimUtil.app \
#     -D background=dmg-background.tiff SimUtil SimUtil.dmg
# dmgbuild writes .DS_Store itself (no Finder scripting), so it works on
# headless CI. Finder may still open the window slightly wider; the
# background bleeds to 800x500 to cover that.
# Regenerate the background after editing dmg-background.svg:
#   rsvg-convert -w 800 dmg-background.svg -o bg.png
#   rsvg-convert -w 1600 dmg-background.svg -o bg@2x.png
#   tiffutil -cathidpicheck bg.png bg@2x.png -out dmg-background.tiff
import os.path

# dmgbuild injects `defines` and gives no path for this file.
app = defines["app"]  # noqa: F821
background = defines["background"]  # noqa: F821
name = os.path.basename(app)

format = "UDZO"
files = [app]
symlinks = {"Applications": "/Applications"}
icon = os.path.join(app, "Contents/Resources/AppIcon.icns")
hide_extensions = [name]

window_rect = ((200, 120), (660, 400))
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
default_view = "icon-view"
icon_size = 112
text_size = 13
# Slots match the arrow drawn in dmg-background.svg.
icon_locations = {name: (170, 236), "Applications": (490, 236)}

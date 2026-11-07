import os
app = defines['app']; guide = defines['guide']
files = [app, guide]
symlinks = {}
badge_icon = None
icon = 'assets/.VolumeIcon.icns'
background = 'assets/CD_window.tiff'
format = 'UDZO'
compression_level = 9
window_rect = ((200, 120), (546, 343))
default_view = 'icon-view'
show_icon_preview = False
show_toolbar = False; show_status_bar = False; show_pathbar = False; show_sidebar = False
icon_size = 96; text_size = 12
icon_locations = {os.path.basename(app): (150, 230), os.path.basename(guide): (400, 230)}

# minatok20 Game Mode install-time setup
ui_print "- minatok20 Game Mode"
ui_print "- Edit games.txt to choose which apps trigger game mode:"
ui_print "    /data/adb/modules/minatok20_gamemode/games.txt"
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755

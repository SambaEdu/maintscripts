#!/bin/bash

# A tester:

mkdir -p /root/.config/Terminal
if [ -e /root/.config/Terminal/terminalrc ]; then
cp /root/.config/Terminal/terminalrc /root/.config_Terminal_terminalrc.$(date +%Y%m%d%H%M%S)
fi

echo '[Configuration]
AccelNewTab=<control><shift>t
AccelNewWindow=<control><shift>n
AccelDetachTab=<control><shift>d
AccelCloseTab=<control><shift>w
AccelCloseWindow=<control><shift>q
AccelCopy=<control><shift>c
AccelPaste=<control><shift>v
AccelPreferences=Disabled
AccelShowMenubar=Disabled
AccelShowToolbars=Disabled
AccelShowBorders=Disabled
AccelSetTitle=Disabled
AccelReset=Disabled
AccelResetAndClear=Disabled
AccelPrevTab=<control>Page_Up
AccelNextTab=<control>Page_Down
BackgroundImageFile=
ColorCursor=#ffffffffffff
ColorSelection=White
FontName=Fixed 13
MiscAlwaysShowTabs=FALSE
MiscBell=FALSE
MiscBordersDefault=TRUE
MiscCursorBlinks=FALSE
MiscDefaultGeometry=80x24
MiscInheritGeometry=FALSE
MiscMenubarDefault=TRUE
MiscMouseAutohide=FALSE
MiscToolbarsDefault=TRUE
MiscConfirmClose=TRUE
MiscCycleTabs=TRUE
MiscTabCloseButtons=TRUE
MiscTabPosition=GTK_POS_TOP
MiscHighlightUrls=TRUE
ScrollingLines=32768
ShortcutsNoMenukey=TRUE
VteWorkaroundTitleBug=TRUE
MiscCursorShape=TERMINAL_CURSOR_SHAPE_BLOCK
MiscTabCloseMiddleClick=TRUE
' > /root/.config/Terminal/terminalrc


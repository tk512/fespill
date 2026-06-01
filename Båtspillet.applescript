-- Båtspillet launcher (AppleScript) — double-click, no Terminal window.
--
-- HOW TO TURN THIS INTO A DOUBLE-CLICK APP (do this ON the machine you'll play
-- on — e.g. the Yosemite Mac — so the app is native to that macOS):
--   1. Open  /Applications/Utilities/Script Editor.app
--   2. File > Open... and choose this file (Båtspillet.applescript).
--   3. File > Export...  ->  File Format: "Application"  ->  save it as
--      "Båtspillet"  INSIDE the game folder (next to main.lua).
--   4. Double-click the resulting Båtspillet.app to play.
--
-- It is self-locating: it launches whatever game folder the app sits in, so it
-- keeps working if you move/copy the folder. It assumes LÖVE is installed at
-- /Applications/love.app.

on run
    -- folder that contains this app (= the game folder with main.lua)
    set gameFolder to (container of (path to me)) as alias
    set gamePosix to POSIX path of gameFolder
    set lovePath to "/Applications/love.app/Contents/MacOS/love"
    -- launch detached so this launcher quits immediately
    do shell script quoted form of lovePath & " " & quoted form of gamePosix & " > /dev/null 2>&1 &"
end run

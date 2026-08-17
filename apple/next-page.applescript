on run argv
	tell application (item 1 of argv) to activate
	tell application "System Events"
		key code 124 # right arrow — move to next page
	end tell
end run

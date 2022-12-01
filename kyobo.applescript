set bookName to "book"
set dFolder to "~/Desktop/" & bookName & "/"

do shell script ("mkdir -p " & dFolder)

set page to 0
repeat page times
	tell application "KEL" to activate # active to kyobo library
	tell application "System Events"
		delay 1
		do shell script ("screencapture -R 111,68,723,911 " & dFolder & bookName & "-" & i & ".png")
		set page to page + 1
		key code 124 # move next page
	end tell
end repeat

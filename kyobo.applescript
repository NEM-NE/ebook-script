set bookName to "Study_Linux_Structure_With_Practice_And_Picture" # Set your Book Name
set dFolder to "~/Desktop/" & bookName & "/"

do shell script ("mkdir -p " & dFolder)

set page to 306 # Set Book Page
set i to 1
repeat page times
	tell application "KEL" to activate # active to kyobo library
	tell application "System Events"
		delay 1
		do shell script ("screencapture -R 100,164,904,1109 " & dFolder & bookName & "-" & i & ".png") # you have to input X,Y,W,H in -R Option 
		set i to i + 1
		key code 124 # move next page
	end tell
end repeat
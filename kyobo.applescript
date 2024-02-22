# set bookName to "Study_Linux_Structure_With_Practice_And_Picture" # Set your Book Name
# set pageLength
on run argv
	set bookName to item 1 of argv
	set pageLength to item 2 of argv
	set pos_x to item 3 of argv
	set pos_y to item 4 of argv
	set pos_w to item 5 of argv
	set pos_h to item 6 of argv
	set dFolder to "~/Desktop/" & bookName & "/"
	set pos to "\"" & pos_x & "," & pos_y & "," & pos_w & "," & pos_h & "\""
	do shell script ("echo " & pos)
	do shell script ("mkdir -p " & dFolder)
	
	set page to pageLength
	set i to 1
	repeat page times
		tell application "KEL" to activate # active to kyobo library
		tell application "System Events"
			delay 1
			do shell script ("screencapture -R" & pos & " " & dFolder & bookName & "-" & i & ".png") # you have to input X,Y,W,H in -R Option 
			set i to i + 1
			key code 124 # move next page
		end tell
	end repeat	
end run
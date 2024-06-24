on run argv
	set bookName to item 1 of argv
	set pageLength to item 2 of argv
	set pos_x to item 3 of argv
	set pos_y to item 4 of argv
	set pos_w to item 5 of argv
	set pos_h to item 6 of argv
    set application_name to item 7 of argv
	set dFolder to "~/Desktop/" & bookName & "/"
	set pos to "\"" & pos_x & "," & pos_y & "," & pos_w & "," & pos_h & "\""
	do shell script ("echo " & pos)
	do shell script ("mkdir -p " & dFolder)
	
    script FormattingHelper
        to formatNumberWithLeadingZeros(numberToFormat, totalLength)
            set formattedNumber to numberToFormat as string
            set currentLength to length of formattedNumber
            repeat until currentLength = totalLength
                set formattedNumber to "0" & formattedNumber
                set currentLength to length of formattedNumber
            end repeat
            return formattedNumber
        end formatNumberWithLeadingZeros
    end script

	set page to pageLength
	set i to 1
	repeat page times
		tell application application_name to activate # active to kyobo library
		tell application "System Events"
			delay 1.5
            set formattedNumber to formatNumberWithLeadingZeros(i, 5) of FormattingHelper
			do shell script ("screencapture -R" & pos & " " & dFolder & bookName & "-" & formattedNumber & ".png") # you have to input X,Y,W,H in -R Option 
			set i to i + 1
			key code 124 # move next page
		end tell
	end repeat	

    do shell script "bash ./merge.sh " & bookName
end run

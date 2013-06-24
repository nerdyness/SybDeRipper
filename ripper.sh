#!/bin/bash

# depenencies: dialog, lsdvd, mencoder (plus my menocder profiles), grep, sed, awk

# put your stuff somewhere
TMPDIR="`mktemp -d`"
# used to retrieve feedback from dialog
OUTPUT="$TMPDIR/tmp.output"
# used to store data the will be sent to dialog
INPUT="$TMPDIR/tmp.input"
MYDIR="`dirname $0`"

cd $MYDIR

# create empty file
>$OUTPUT

# cleanup - add a trap that will remove $TMPDIR
# if any of the signals are received.
trap "rm -rf $TMPDIR; exit" SIGHUP SIGINT SIGTERM SIGABRT SIGQUIT SIGKILL
 
welcome() {
	dialog  --title "SybDeRipper" \
		--backtitle "Welcome to SybDeRipper"\
		--yesno "
Welcome to SybDeRipper\n\nYou've got the option to copy a DVD to an iso file or RIP an iso file to a single movie file.\n\nAre you trying to copy a DVD?" 14 40
	TRUE="$?"
	if [ "$TRUE" == "0" ]; then #yes
		copyDVD
	elif [ "$TRUE" == "1" ]; then #no
		getTitle
	elif [ "$TRUE" == "255" ]; then #ESC
		end
	else
		echo "I dunno what you did"
	fi
}

setDVDName() {
	dialog  --title "SybDeRipper" \
		--backtitle "SybDeRipper" \
		--inputbox "What should the file be called?\n(try to avoid spaces in the file name)" 8 44 "DVD_NAME.iso" 2>$OUTPUT
	DVD_NAME="$(<$OUTPUT)"

	#check that the file ending ".iso" has been entered.
	echo $DVD_NAME | grep -iqe '\.iso$'
	TRUE="$?"
	if [ "$TRUE" == "1" ]; then #no .iso entered
		DVD_NAME="${DVD_NAME}.iso"
	fi

	#get a .log file as well
	DVD_LOG="`echo $DVD_NAME | sed -e 's/\.iso/\.log/'`"
}

copyDVD() {
	#Fill DVD_NAME and DVD_LOG
	setDVDName

	#Is the movie player running?
	pidof totem mplayer vlc
	RETVAL="$?"
	if [ "$RETVAL" == "1" ]; then #not running
		dialog  --title "SybDeRipper" \
			--backtitle "Just FYI" \
			--msgbox "\nI can't see the movie player running. For me to be able to copy the DVD it should be playing the menu. Please start it before pressing OK.\n\nI won't check again so you're on your own from here :)" 14 50
	fi

	#copy DVD
	# FIXME doesn't return 1 so this script won't jump back to the beginning. Remove FIXME and use the comment below
	FIXME # ddrescue /dev/sr0 "$DVD_NAME" "$DVD_LOG" 2>"$OUTPUT" 1>/dev/null
	RETVAL="$?"
	if [ "$RETVAL" == "1" ]; then #died somehow
		dialog  --title "SybDeRipper" \
			--backtitle "Erma Gerd!!!" \
			--msgbox "\nSomething bad happened to our little script. You probably don't have a $DVD_NAME file, if you do it might be corrupt. These are the last few lines from ddrescue:\n\n`tail $OUTPUT`" 25 60
		welcome
	else
		dialog  --title "SybDeRipper" \
			--backtitle "Continue to rip this copy?"\
			--yesno "Select yes to also rip this copy" 14 40 #2> $OUTPUT
		TRUE="$?"
		if [ "$TRUE" == "0" ]; then #yes
			getTitle "$DVD_NAME"
		elif [ "$TRUE" == "1" ]; then #no
			welcome
		else
			echo "I dunno what you did"
		fi
	fi
}

getTitle() {
 	#Ask for iso NAME if unset or not exist.
	if [ ! -e "$DVD_NAME" ]; then
		# load all iso files in an array
		FILES=( *.iso )
		COUNT=0
		echo "" > "$INPUT"
		for FILE in "${FILES[@]}"; do
			COUNT="$(($COUNT+1))"
			echo "\"$COUNT\" \"$FILE\"" >> "$INPUT"
		done
	
		dialog  --title "SybDeRipper" \
			--backtitle "Choose a DVD to rip" \
			--menu "\nPlease select a file to be ripped from the following options" 30 60 25 --file "$INPUT" 2>"$OUTPUT"
		RETVAL="$?"
		if [ "$RETVAL" == "1" ]; then #cancel pressed
			DVD_NAME=""
			welcome
			end
		fi
		DVD_INDEX="$(($(<$OUTPUT)-1))"
		DVD_NAME="${FILES[$DVD_INDEX]}"
	fi

	#How many titles on disk?
	#########################
	COUNT=0
	#Reset temp input
	echo "" > "$INPUT"

	#temporarily fill the INPUT buffer
	#Black voodooo!! It's in your scripts!
	while read line
	do
		COUNT="$(($COUNT+1))"
		echo "\"$COUNT\" \"$line\"" >> "$INPUT"
	done < <(grep -e '^Title\|track' ./lsdvd.out)
	#done < <(lsdvd "./$DVD_NAME" | sed -e 's/,\ Cells[[:print:]]*//' | grep '^Title\|track')

	#get longest track (last line) and trim leading zeros.
	LONGEST_TRACK="`tail -n 1 "$INPUT" | awk -F':' '{ print $2 }' | sed -e 's/[^[[:digit:]]*\([[:digit:]]*\)[^[[:digit:]]*/\1/' | sed -e 's/^0*//'`"
	LENGTH=`wc -l "$INPUT" | awk '{ print $1 }'`
	echo "`head -n $(($LENGTH-1)) $INPUT`" > "$INPUT"

	#reuse last line as default selection.
	# --default-item string
	dialog  --title "SybDeRipper" \
		--backtitle "Choose a DVD title rip" \
 		--default-item "$LONGEST_TRACK" \
		--menu "\nPlease select one of the following titles to be ripped:" 30 60 25 --file "$INPUT" 2>$OUTPUT
	RETVAL="$?"
	if [ "$RETVAL" == "1" ]; then #cancel pressed
		DVD_NAME=""
		getTitle
		end
	fi
	DVD_TITLE="$(<$OUTPUT)"

	#Wanna play a title?
	dialog  --title "SybDeRipper" \
		--backtitle "Play the selected title first?" \
		--yesno "\nDid you want to play the title first to be sure?" 14 40
	TRUE="$?"
	if [ "$TRUE" == "0" ]; then #yes
		playTitle "$DVD_NAME" "$DVD_TITLE"
	elif [ "$TRUE" == "1" ]; then #no
		ripTitle "$DVD_NAME" "$DVD_TITLE"
	else
		echo "I dunno what you did"
	fi
}

playTitle() {
	#Press q to exit
	dialog  --title "SybDeRipper" \
		--backtitle "Just FYI" \
		--msgbox "\nJust so you know, you can quit this via the \"q\" key." 10 40
	mplayer -dvd-device "$DVD_NAME" dvd://"$DVD_TITLE" -alang en -slang 999

	
	#Was this the right track? RipDVD "$DVD_NAME", ripTitle "name" "title"
	dialog  --title "SybDeRipper" \
		--backtitle "Right track?" \
		--yesno "\nIs this the track you want to use?" 14 40
	TRUE="$?"
	if [ "$TRUE" == "0" ]; then #yes
		ripTitle "$DVD_NAME" "$DVD_TITLE"
	elif [ "$TRUE" == "1" ]; then #no
		DVD_TITLE=""
		getTitle "$DVD_NAME"
	else
		echo "I dunno what you did"
	fi
}

ripTitle() {
	#ideally we ask here whether it's a cartoon or loud enough.
	getProfile
	# Change into TMPDIR due to divx2pass.log
	#cd "$TMPDIR"
	mencoder -dvd-device "$DVD_NAME" dvd://"$DVD_TITLE" -profile "$PROFILE" -xvidencopts pass=1 -o /dev/null
	mencoder -dvd-device "$DVD_NAME" dvd://"$DVD_TITLE" -profile "$PROFILE" -xvidencopts pass=2 -o "`echo $DVD_NAME.$DVD_TITLE| sed -e 's/\.iso//'`".avi

	DVD_LOG="`echo $DVD_NAME | sed -e 's/\.iso/\.log/'`"
	#cd -
}

getProfile() {
	dialog  --title "SybDeRipper" \
		--backtitle "Select your profile"\
		--checklist "Is the track you are trying to RIP" 10 40 40 \
		c "a cartoon" c q "too quiet" q 2> $OUTPUT
	RETVAL="$?"
	if [ "$RETVAL" == "1" ]; then #cancel pressed
		DVD_NAME=""
		welcome
		end
	fi

	OPTIONS="$(<$OUTPUT)"
	VOLUME_NEEDED=false
	CARTOON=false
	for i in $OPTIONS; do
		if [ "$i" == '"l"' ]; then
			VOLUME_NEEDED=true
		elif [ "$i" == '"c"' ]; then
			CARTOON=true
		fi
	done

	# Possible values include:
	# mpeg4
	# mpeg4_default_volume
	# mpeg4_cartoon
	# mpeg4_cartoon_default_volume

	PROFILE="mpeg4"
	if [ "$CARTOON" == "true" ]; then
		PROFILE="${PROFILE}_cartoon"
	fi
	if [ "$VOLUME_NEEDED" == "false" ]; then
		PROFILE="${PROFILE}_default_volume"
	fi
	PROFILE="${PROFILE}"
}

end () { 
	rm -rf $TMPDIR
	exit 0
}

welcome
end

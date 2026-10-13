-- rekordbox batch analyze
-- https://github.com/adamsmithkipnis/rekordbox-batch-analyze
--
-- rekordbox only analyzes streaming tracks (Spotify, TIDAL, ...) when they are
-- loaded onto a deck. This script walks down a playlist and loads each track
-- onto a deck in turn, rotating through the decks so several tracks analyze
-- in parallel, until the whole playlist has BPM, key and beatgrid data.
--
-- How it works:
--  * Sends "load to deck" and "next track" back to back. rekordbox ignores
--    keystrokes while it finishes an analysis, so the two either both land or
--    both get dropped; tracks are never loaded twice or skipped.
--  * If another app or a system popup takes focus, it brings rekordbox back.
--  * Keeps the Mac awake while it runs.
--  * When it stops, the reason shows in Script Editor's Result pane.
--
-- BEFORE RUNNING
-- 1. In rekordbox: Preferences > Keyboard, assign:
--      Load to Deck 1 = Control + 1
--      Load to Deck 2 = Control + 2
--      Load to Deck 3 = Control + 3   (needs the 4-deck layout)
-- 2. System Settings > Privacy & Security > Accessibility: allow Script Editor.
-- 3. Sort the playlist by a column that won't change during analysis
--    (Title, Artist, or #). NOT by BPM or Key.
-- 4. Click the first track you want analyzed.
-- 5. Run this script and don't touch the keyboard or mouse.
--
-- TO STOP: click into the Script Editor window (or press its Stop button).
-- The script stops at the next track.

-------------------- SETTINGS --------------------
property totalTracks : 500 -- how many load attempts this run
property secondsPerTrack : 12 -- wait between loads
property batchSize : 40 -- pause after this many tracks
property batchPauseSeconds : 300 -- length of that pause (5 min)
property limitCooldownSeconds : 120 -- wait after hitting the streaming limit
property maxRetriesPerTrack : 3 -- stop if one track keeps hitting the limit
property maxFocusLosses : 20 -- stop if focus keeps getting taken away
property startDelay : 5 -- seconds to get ready before it starts

-- Decks to rotate through. Key codes: 1 = 18, 2 = 19, 3 = 20
-- 2-deck layout: {18, 19}     4-deck layout: {18, 19, 20}
property deckKeyCodes : {18, 19, 20}

property downArrow : 125
property upArrow : 126
property returnKey : 36
--------------------------------------------------

-- Sends one key press + release as a hardware-style keyboard event.
-- flagsHex: "0x40000" = Control held, "0xA00000" = arrow-key flags, "0" = none.
on postKey(kc, flagsHex)
	set js to "ObjC.import('CoreGraphics');" & ¬
		"var f = " & flagsHex & ";" & ¬
		"[true, false].forEach(function (isDown) {" & ¬
		"  var e = $.CGEventCreateKeyboardEvent(null, " & kc & ", isDown);" & ¬
		"  $.CGEventSetFlags(e, f);" & ¬
		"  $.CGEventPost(0, e);" & ¬
		"});"
	run script js in "JavaScript"
end postKey

-- Load the selected track, then immediately move to the next one.
on loadAndAdvance(deckIndex)
	my postKey(item deckIndex of deckKeyCodes, "0x40000") -- Control + 1/2/3
	delay 0.5
	my postKey(downArrow, "0xA00000")
end loadAndAdvance

on frontAppName()
	try
		tell application "System Events"
			return name of first application process whose frontmost is true
		end tell
	on error
		return "unknown"
	end try
end frontAppName

-- Looks for the streaming-limit message in rekordbox's windows and sheets.
-- Returns false if the message isn't readable by macOS.
on limitMessageShowing()
	try
		tell application "System Events"
			set rb to first application process whose name contains "rekordbox"
			repeat with w in (windows of rb)
				set texts to {}
				try
					set texts to texts & (value of static texts of w)
				end try
				try
					set texts to texts & (name of w)
				end try
				try
					repeat with s in (sheets of w)
						set texts to texts & (value of static texts of s)
					end repeat
				end try
				repeat with t in texts
					try
						set tt to t as text
						if tt contains "streaming limit" or tt contains "exceeded" then return true
					end try
				end repeat
			end repeat
		end tell
	end try
	return false
end limitMessageShowing

on finish(msg)
	try
		do shell script "pkill -f 'caffeinate -dimsu -t 86400' || true"
	end try
	display notification msg with title "rekordbox batch loader"
	return msg
end finish

-- Keep the Mac (and display) awake while the script runs.
do shell script "caffeinate -dimsu -t 86400 > /dev/null 2>&1 &"

tell application "rekordbox" to activate
display notification "Starting in " & startDelay & " seconds. Click Script Editor to stop." with title "rekordbox batch loader"
delay startDelay

set deckCount to count of deckKeyCodes
set processed to 0
set limitHits to 0
set focusLosses to 0
set focusThieves to {}

repeat with i from 1 to totalTracks
	-- Make sure rekordbox is in front before sending keys.
	set frontApp to my frontAppName()
	if frontApp is not "rekordbox" and frontApp does not contain "rekordbox" then
		if frontApp is "Script Editor" then
			return my finish("Stopped by you after " & processed & " tracks.")
		end if
		set focusLosses to focusLosses + 1
		if focusThieves does not contain frontApp then set end of focusThieves to frontApp
		if focusLosses > maxFocusLosses then
			set AppleScript's text item delimiters to ", "
			set thieves to focusThieves as text
			set AppleScript's text item delimiters to ""
			return my finish("Stopped after " & processed & " tracks: rekordbox kept losing focus to " & thieves & ".")
		end if
		delay 3
		tell application "rekordbox" to activate
		delay 2
	end if

	set deckIndex to ((i - 1) mod deckCount) + 1
	set retries to 0
	set loadedOK to false

	repeat until loadedOK
		my loadAndAdvance(deckIndex)
		delay secondsPerTrack

		if my limitMessageShowing() then
			set limitHits to limitHits + 1
			set retries to retries + 1
			my postKey(returnKey, "0") -- dismiss the message
			delay 0.5
			my postKey(upArrow, "0xA00000") -- go back to the track that didn't load
			if retries > maxRetriesPerTrack then
				return my finish("Stopped after " & processed & " tracks: hit the Spotify streaming limit repeatedly. Try again later.")
			end if
			display notification "Streaming limit hit. Waiting " & limitCooldownSeconds & "s, then retrying." with title "rekordbox batch loader"
			delay limitCooldownSeconds
			tell application "rekordbox" to activate
			delay 1
		else
			set loadedOK to true
		end if
	end repeat

	set processed to i

	if (i mod batchSize) = 0 and i < totalTracks then
		display notification (i as text) & " tracks done. Pausing " & batchPauseSeconds & "s." with title "rekordbox batch loader"
		delay batchPauseSeconds
		tell application "rekordbox" to activate
		delay 1
	end if
end repeat

return my finish("Done: " & processed & " load attempts, " & limitHits & " limit hits, " & focusLosses & " focus interruptions.")

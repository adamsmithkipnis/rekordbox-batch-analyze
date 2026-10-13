# rekordbox batch analyze

Analyze an entire Spotify or TIDAL playlist in rekordbox without loading every track by hand.

rekordbox only analyzes streaming tracks (BPM, key, beatgrid, waveform) when a track is loaded onto a deck, so preparing a big streaming library means dragging thousands of songs onto decks one at a time. This AppleScript does that for you: it walks down a playlist, loads each track onto a deck, and rotates through your decks so several tracks analyze in parallel. Start it, walk away, and come back to an analyzed library.

Tested with **Spotify** and **TIDAL** in rekordbox on macOS. Other streaming services that rekordbox supports should work the same way.

## Requirements

- macOS
- rekordbox (Performance mode), signed in to your streaming service
- Script Editor (built into macOS)

## Setup (one time)

1. **Assign the load shortcuts in rekordbox.** Open **Preferences → Keyboard** and set:
   | Function | Shortcut |
   |---|---|
   | Load to Deck 1 | Control + 1 |
   | Load to Deck 2 | Control + 2 |
   | Load to Deck 3 | Control + 3 |

   Deck 3 needs the **4-deck layout**. If you use 2 decks, see [Settings](#settings).

2. **Let Script Editor control your keyboard.** Open **System Settings → Privacy & Security → Accessibility** and turn on **Script Editor**.

3. **Turn off STEMS on your decks.** Stems aren't available for streaming tracks, and the warning rekordbox shows can get in the way.

4. **Turn on Cloud Analysis** (optional but recommended). rekordbox can pull analysis for popular tracks from AlphaTheta's servers, which is much faster than analyzing locally.

## Running it

1. Download [`rekordbox-batch-analyze.applescript`](rekordbox-batch-analyze.applescript) and open it in Script Editor.
2. In rekordbox, open the playlist you want to analyze.
3. **Sort the playlist by a column that won't change during analysis**, such as **#**, Title or Artist. Don't sort by BPM or Key, because rows move as tracks get analyzed and the script will lose its place.
4. Click the first track you want analyzed.
5. Click **Run** in Script Editor, then leave the keyboard and mouse alone.

The script brings rekordbox to the front, waits 5 seconds, and starts loading tracks.

**To stop:** click into the Script Editor window, or press its **Stop** button.

**To resume later:** click the first track that hasn't been loaded yet and run the script again.

When the script ends, the reason appears in Script Editor's **Result** pane and as a notification.

## Settings

The settings are at the top of the script.

| Setting | Default | What it does |
|---|---|---|
| `totalTracks` | 500 | How many tracks to load in one run |
| `secondsPerTrack` | 12 | Wait between loads. Raise it if you see tracks without BPM/key. |
| `batchSize` | 40 | Pause after this many tracks |
| `batchPauseSeconds` | 300 | Length of that pause, to stay under streaming limits |
| `limitCooldownSeconds` | 120 | Wait after a "streaming limit" message before retrying |
| `deckKeyCodes` | `{18, 19, 20}` | Decks to rotate through. Use `{18, 19}` for the 2-deck layout. |

## Things to know

- **Streaming limits.** Spotify limits how fast tracks can be loaded. If you see *"You have exceeded the track streaming limit"*, increase `secondsPerTrack` and `batchPauseSeconds`. Loading at high speed for long periods may get your streaming account flagged, so err on the side of slower.
- **Speed.** At the defaults, expect roughly 180 tracks an hour, including the batch pauses. A library of a few thousand tracks takes several overnight runs.
- **Spot-check beatgrids.** Automatic analysis isn't perfect. Check the grids on tracks you plan to play.
- **Laptop only.** Streaming tracks can't be exported to USB for CDJs/XDJs, so this helps when you DJ from rekordbox on your computer.

## How it works

rekordbox ignores keystrokes for a moment while it finishes analyzing a track. If the script pressed the down arrow on its own several seconds after loading, it often got dropped and the same track loaded twice. Instead, the script sends **load** and **next track** half a second apart, so either both land or both are ignored. A dropped pair only costs one cycle; tracks are never loaded twice or skipped.

Keys are sent as low-level keyboard events (the same kind a physical keyboard produces) so rekordbox treats them like real key presses.

## Troubleshooting

| Problem | Fix |
|---|---|
| Nothing loads | Check the Control + 1/2/3 shortcuts in rekordbox, and that Script Editor is allowed under Accessibility. |
| Deck 3 never gets a track | Switch rekordbox to the 4-deck layout, or set `deckKeyCodes` to `{18, 19}`. |
| Tracks load but show no BPM/key | Raise `secondsPerTrack`. |
| Script stops early | Read the reason in Script Editor's Result pane. |

## License

[MIT](LICENSE)

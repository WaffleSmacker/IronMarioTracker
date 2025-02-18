# IronMarioTracker
![image](https://github.com/user-attachments/assets/600140ac-6c05-4884-890e-0fe145800843)

# Download
Check out the [releases page](https://github.com/WaffleSmacker/IronMarioTracker/releases) to get the most recent version of the tracker.
Download the IronMarioTracker.zip file.

# Usage
Unzip and load this script into the Lua Console of Bizhawk after you load the IronMario ROM.
To toggle the song title display, press L+R+A+B.

# Notes
The font size of the tracker is determined by the game's resolution. If the tracker looks blurry, go to the N64 menu in Bizhawk, click Plugins, and set the video resolution to at least 1024 x 768.

# About
This tracker was put together to support streamers and gamers alike who are taking on the IronMario challenge.
To date it can help you by keeping track of your best PB, warp mapping, and tracking where you got your stars.

# Changelog

## v1.0.2u2 - 2025-02-18

### IronMario Version: v1.0.2

### Interface

- Changed star count display to something BETTER.
- Set minimum font size.
- Removed taint (sorry, DGR...)

## v1.0.2u1 - 2025-02-17

### IronMario Version: v1.0.2

### Performance

- Tracker now only draws once per second, should alleviate any framerate issues. (Thanks to Derrek for testing this!)

### Interface

- Fixed infinite resize glitch. (Thanks to Derrek for testing this, too!)
- Rewrote tracker render code. Better font, adaptive font sizing, Windows display scaling compatibility, and probably a lot more.
- Added the IronMario logo!

### Features

- For the music-enabled version, song name display can be toggled at any time via L+R+A+B.
- Version compatibility check. Because the tracker code is IronMario version specific, mismatched versions will just show garbage in the tracker. Now, it checks this.

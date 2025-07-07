# IronMarioTracker
![image](https://github.com/user-attachments/assets/8143aa9a-f2e9-446b-b36a-e82dae823064)


# Download
Check out the [releases page](https://github.com/WaffleSmacker/IronMarioTracker/releases) to get the most recent version of the tracker.
Download the IronMarioTracker.zip file.

# Requirements
This script is fully supported only on the latest version of Bizhawk.

If you want to use this tracker on PJ64 or Parallel please check out [aglab2's awesome tool](https://github.com/aglab2/LuaEmuPlayer/releases/) and follow the instructions there.
![image](https://github.com/user-attachments/assets/0fa1b19b-852d-4c5d-b2a1-fba6e13edb9f)


# Usage
Unzip and load this script into the Lua Console of Bizhawk after you load the IronMario ROM.
To toggle the song title display, press L+R+A+B.

# Notes
The font size of the tracker is determined by the game's resolution. If the tracker looks blurry, go to the N64 menu in Bizhawk, click Plugins, and set the video resolution to at least 1024 x 768.

# About
This tracker was put together to support streamers and gamers alike who are taking on the IronMario challenge.
To date it can help you by keeping track of your best PB, warp mapping, and tracking where you got your stars.
**For Streamers** 3 files are auto-generated when you play:
![image](https://github.com/user-attachments/assets/62816dd9-54c0-4d8b-b31f-a50b800a052f)
You can use these to auto populate any on stream stats if you would like to.

# Credits

WaffleSmacker for basically everything.
KaaniDog for supporting with re-creating the structure to make the code load more smoothly and extra features!

# Changelog

## v1.201 - 2025-07-07
This version is now compatible with IronMario64 V1.2
- Timer was removed as it caused lag for some people
- "Cap Timer" was added to help players understand when their cap will end
- Added a few extra backgrounds and fixed the sizes so they are no longer crunched

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

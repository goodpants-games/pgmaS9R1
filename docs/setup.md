# Setup (Windows)
To build and run the project you need:

- Python 3
- LÖVE 11.5
- Aseprite
- Tiled (maybe?)

This document describes how to install each tool and also how to launch the
game.

## Installing the requirements
### Python 3
First, check if you already have Python 3 installed. To do so, press WIN+R,
type `cmd`, and then press ENTER. In the command prompt window, type `python`
and then press ENTER. This should open the Python REPL; if an error message 
pops up instead, then you do not have Python installed.

To install Python 3, download and run the installer from here:
https://www.python.org/downloads/ (or you can download it from the Microsoft
Store). **IMPORTANT!** When setting up the installation, make sure to check the
"Add python.exe to PATH" option.

### LÖVE
Provided in the tools folder is a custom patch[^1] of LÖVE 11.5. Unzip it and
place it into a folder named "love" under the root directory of the project
(next to CREDITS.txt and LICENSE). **IMPORTANT:** It is crucial that it is
unzipped such that "lovec_l52.exe" is directly within the "love" folder, not
within a subfolder. This is because the game launcher helper script (described
later) will look for this file. There are no folders inside the .zip file
itself, so you only need to specify the path to the "love" folder that the unzip
GUI will make.

You may also download LOVE from their website: https://love2d.org/. However, I
already have a helper script in this repo to run LOVE given that you followed
the above instructions, so, unless you already have LOVE on your system it is
easier to follow those instructions.

### Aseprite
I'm assuming you already have Aseprite.

### Tiled
(Skip this section, unless you plan on doing level editing.)

If we decide to need levels for this game, we will most likely make levels using
Tiled. It can be installed from here: https://thorbjorn.itch.io/tiled. The
installer downloadable from that page should install Tiled into the standard
location (`C:\Program Files\Tiled\tiled.exe`). If it doesn't, then the asset
exporter script will not work.

## Running the game launcher helper script
In order to run the game, you can run the game launcher helper script from a
PowerShell prompt. There are two ways to open PowerShell with the session's
current directory set to the project root:
1. Open the project folder in File Explorer. Click on an empty spot in the
   location bar to begin typing into it. Type `powershell` and press ENTER.
2. Press WIN+R and type in `powershell` to open a new PowerShell window with the
   current directory set to your user folder. Then, to properly set the current
   directory, type:
   ```powershell
   cd 'C:\Path\To\Project\Dir'
   ```
   (`cd` stands for "change directory"; the given path above is an example)

The game launcher helper cmdlet (`tools/run.ps1`) runs the asset exporter and
then launches the game using the unzipped custom version of LOVE 11.5. But
before running it, you need to do something to let the asset exporter know where
Aseprite is located. This is because it uses the Aseprite command-line interface
for automated spritesheet exports, and the location of the executable is
different depending on how/where you installed it (e.g. Steam vs. non-Steam
installation vs. compiled from source), so I can't have the script properly
assume the location of Aseprite.

There are two ways to do this:
### 1. Modify the system PATH environment variable
The PATH variable is a system-wide variable containing a list of directories
that Command Prompt/PowerShell uses to resolve command names to executables. For
example, if you wrote `python tools\assetexport.py`, the shell looks through
each folder specified in PATH for a file named "python.exe", and runs that
executable with the given command arguments. (And then, for a program--in this
case, the asset exporter script--to launch another executable, it must do so
through Command Prompt.)

To add the Aseprite folder to this variable:
1. Open the Windows start menu and search for and open "Edit the system
   environment variables".
2. This will open you to the "Advanced" tab of System Properties. Press the
   "Environment Variables..." button on the bottom-right.
3. In the new window that opens, locate and click the entry for "Path" in the
   "System Variables" list. After it has been selected, click the "Edit" button
   located on the bottom-right.
4. This opens a new window of a list containing the entries of the PATH
   variable. Make sure you have the path to the folder containing aseprite.exe
   in your clipboard. Press the "New" button located on the right, paste the
   path, and then press ENTER.
5. Press "OK" for each window until every window has been closed.

### 2. Set a session environment variable
In your PowerShell session, type out this command, replacing the given path with
your path to aseprite.exe:
```powershell
$env:ASEPRITE = "C:\Program Files\Aseprite\aseprite.exe"
```
Then, press ENTER. The asset export script will read this environment variable
to determine the location of Aseprite. The caveat of this method is that you
must do this every time you make a new PowerShell session.

### Execute the launcher cmdlet
Afterwards, to run the launcher cmdlet you simply type:
```powershell
powershell -ExecutionPolicy Bypass -File tools\run.ps1
```
By default, Windows disables running cmdlets downloaded from the Internet for
security reasons. The `-ExecutionPolicy Bypass` part is to force it to run the
cmdlet regardless. There is a way to disable it, so that you only need to type
`tools\run.ps1` to run the cmdlet, but I'm too lazy to figure out how.

----

[^1]: The only thing I changed in my custom patch of LOVE is the Lua
(programming language) version: my version uses Lua 5.2, whereas the official
builds use LuaJIT. This is for better parity with the web build: LuaJIT
cannot run on the web, so Lua 5.2 is the closest that we can get. The game is
programmed so that the difference in Lua version does not matter.
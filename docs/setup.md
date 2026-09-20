# Setup (Windows)
To build and run the project you need:

- Python 3
- LÖVE 11.5
- Aseprite
- Tiled (maybe?)

## Installing the requirements
### Python 3
First, check if you already have Python 3 installed. To do so, press WIN+R,
type `cmd`, and then press ENTER. In the command prompt window, type `python`
and then press ENTER. This should open the Python REPL; if an error message 
pops up instead, then you do not have Python installed.

To install Python 3, download the installer from here:
https://www.python.org/downloads/. Run the installer. **IMPORTANT!** When
setting up the installation, make sure to check the "Add python.exe to PATH"
option.

### LÖVE
Provided in the tools folder is a custom patch of LÖVE 11.5. Unzip it and place
it into a folder named "love" under the root directory of the project.

### Aseprite
I'm assuming you already have Aseprite.

### Tiled
(Skip this section for now.)

If we decide to need levels for this game, we will most likely make levels using
Tiled. It can be installed from here: https://thorbjorn.itch.io/tiled. The
installer downloadable from that page should install Tiled into the standard
location (`C:\Program Files\Tiled\tiled.exe`).

## Running the game
In order to run the game, you must do so from a PowerShell session within the
project root. There are two ways to open PowerShell with the session's current
directory set to the project root:
1. Open the project folder in File Explorer. Click on an empty spot in the
   location bar. Type `powershell` and press ENTER.
2. Press WIN+R and type in `powershell` to open a new PowerShell window with the
   current directory set to your user folder. Then, to properly set the current
   directory, type:
   ```powershell
   cd 'C:\Path\To\Project\Dir'
   ```
   (`cd` stands for "change directory"; the given path above is an example)

Once you have a PowerShell session open, you need to set a session variable to
store the location of the Aseprite executable. This is because the location is
different depending on how/where you installed it (e.g. Steam vs. non-Steam
installation vs. compile from source).

Type out this command, replacing the given path with your path to aseprite.exe:
```powershell
$env:ASEPRITE = "C:\Program Files\Aseprite\aseprite.exe"
```
Then, press ENTER. You must do this every time you make a new PowerShell session
(a bit annoying, I know...)

Afterwards, to run the game you simply type:
```powershell
powershell -ExecutionPolicy Bypass -File tools\run.ps1
```
This is a PowerShell cmdlet I made to run the asset builder Python script and
then launch LOVE from the unzipped LOVE folder that is assumed to exist.

By default, Windows disables running cmdlets downloaded from the Internet for
security reasons. The "-ExecutionPolicy Bypass" part is to force it to run the
cmdlet anyway.
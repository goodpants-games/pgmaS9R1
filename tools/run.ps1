$ErrorActionPreference = 'Stop'

$env:TILED = "C:\Program Files\Tiled\tiled.exe"
python tools\assetexport.py
lovec_l52 root --debug $args
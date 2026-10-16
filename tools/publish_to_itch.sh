#!/bin/bash
set -e

cd exports
butler push lovejs pumkinhead/monoware:html5 --if-changed
butler push win-x64 pumkinhead/monoware:win-x64 --if-changed
butler push monoware.love pumkinhead/monoware:love --if-changed
cd ..
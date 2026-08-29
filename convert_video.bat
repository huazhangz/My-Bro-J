@echo off
setlocal
set "SRC="
if exist "steve3.mp4" set "SRC=steve3.mp4"
if exist "Steve3.mp4" set "SRC=Steve3.mp4"
if "%SRC%"=="" (
  echo Missing steve3.mp4 in the project folder: %CD%
  echo Put C:\Users\ASUS\My-Bro-J\steve3.mp4 here, then run this bat again.
  pause
  exit /b 1
)
echo Converting %SRC% to Ogg Theora for Godot...
ffmpeg -y -i "%SRC%" -vf "fps=24,scale=460:-2" -c:v libtheora -q:v 8 -an assets/videos/steve.ogv
if errorlevel 1 (
  echo libtheora failed, retrying with -c:v theora...
  ffmpeg -y -i "%SRC%" -vf "fps=24,scale=460:-2" -c:v theora -qscale:v 7 -an assets/videos/steve.ogv
)
if errorlevel 1 (
  echo Conversion failed. Is ffmpeg on PATH?
  pause
  exit /b 1
)
echo Conversion complete: assets\videos\steve.ogv
echo You can now press F5 in Godot.
pause

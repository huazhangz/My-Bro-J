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
for %%A in ("assets\videos\steve.ogv") do set "OGV_SIZE=%%~zA"
echo Conversion complete: assets\videos\steve.ogv  (%OGV_SIZE% bytes)
if %OGV_SIZE% LEQ 80000 (
  echo WARNING: output is still a tiny placeholder. Check that %SRC% is the real green-screen take.
  pause
  exit /b 2
)

if exist "hanyiyongzixiaoxiongmao.ttf" copy /Y "hanyiyongzixiaoxiongmao.ttf" "assets\fonts\hanyiyongzixiaoxiongmao.ttf" >nul
if exist "HYYongZiXiaoXiongMao-W.ttf" copy /Y "HYYongZiXiaoXiongMao-W.ttf" "assets\fonts\hanyiyongzixiaoxiongmao.ttf" >nul
if exist "assets\fonts\hanyiyongzixiaoxiongmao.ttf" echo Copied authorized Hanyi font into assets\fonts\

echo You can now press F5 in Godot.
pause

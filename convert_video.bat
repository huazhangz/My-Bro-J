@echo off
echo Converting Steve1.mp4 to Ogg Theora format for Godot...
ffmpeg -y -i Steve1.mp4 -c:v theora -qscale:v 7 -an assets/videos/steve.ogv
echo Conversion complete! You can now run the game in Godot.
pause

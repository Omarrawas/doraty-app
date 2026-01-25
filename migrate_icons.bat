@echo off
if not exist android\app\src\main\res\mipmap-mdpi mkdir android\app\src\main\res\mipmap-mdpi
move /Y android\app\src\main\res\drawable-mdpi\ic_launcher.png android\app\src\main\res\mipmap-mdpi\ic_launcher.png

if not exist android\app\src\main\res\mipmap-hdpi mkdir android\app\src\main\res\mipmap-hdpi
move /Y android\app\src\main\res\drawable-hdpi\ic_launcher.png android\app\src\main\res\mipmap-hdpi\ic_launcher.png

if not exist android\app\src\main\res\mipmap-xhdpi mkdir android\app\src\main\res\mipmap-xhdpi
move /Y android\app\src\main\res\drawable-xhdpi\ic_launcher.png android\app\src\main\res\mipmap-xhdpi\ic_launcher.png

if not exist android\app\src\main\res\mipmap-xxhdpi mkdir android\app\src\main\res\mipmap-xxhdpi
move /Y android\app\src\main\res\drawable-xxhdpi\ic_launcher.png android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png

if not exist android\app\src\main\res\mipmap-xxxhdpi mkdir android\app\src\main\res\mipmap-xxxhdpi
move /Y android\app\src\main\res\drawable-xxxhdpi\ic_launcher.png android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png

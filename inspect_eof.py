
import os

file_path = r'c:\Users\omarr\Downloads\D\doraty\lib\screens\lesson\lesson_screen.dart'

with open(file_path, 'rb') as f:
    f.seek(0, os.SEEK_END)
    size = f.tell()
    f.seek(max(0, size - 100))
    data = f.read()
    print(data)

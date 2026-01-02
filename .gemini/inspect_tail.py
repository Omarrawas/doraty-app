
with open(r'c:\Users\omarr\Downloads\D\doraty\lib\screens\lesson\lesson_screen.dart', 'rb') as f:
    f.seek(-100, 2)
    tail = f.read()
    print(tail)

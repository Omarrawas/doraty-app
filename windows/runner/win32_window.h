#ifndef RUNNER_WIN32_WINDOW_H_
#define RUNNER_WIN32_WINDOW_H_

#include <windows.h>

#include <string>
#include <vector>

// A class abstraction for a high DPI-aware Win32 window. Intended to be
// inherited from by classes that wish to customize with custom logic in
// MessageHandler.
class Win32Window {
 public:
  struct Point {
    unsigned int x;
    unsigned int y;
    Point(unsigned int x, unsigned int y) : x(x), y(y) {}
  };

  struct Size {
    unsigned int width;
    unsigned int height;
    Size(unsigned int width, unsigned int height)
        : width(width), height(height) {}
  };

  Win32Window();
  virtual ~Win32Window();

  // Creates a Win32 window of |size| with |title|, and |origin|.
  // Returns true if the window was created successfully.
  bool Create(const std::wstring& title, const Point& origin, const Size& size);

  // Show the current window. Returns true if the window was successfully shown.
  bool Show();

  // Release OS resources associated with window.
  void Destroy();

  // Inserts |content| into the window tree.
  void SetChildContent(HWND content);

  // Returns the client area of the window.
  RECT GetClientArea();

  // Returns the handle of the window.
  HWND GetHandle();

  // If true, closing this window will quit the application.
  void SetQuitOnClose(bool quit_on_close);

 protected:
  // Processes and routes Windows messages to appropriate methods, or to
  // DefWindowProc if not handled.
  virtual LRESULT MessageHandler(HWND window,
                                 UINT const message,
                                 WPARAM const wparam,
                                 LPARAM const lparam) noexcept;

  // Called when Create is completed.
  virtual bool OnCreate();

  // Called when Destroy is completed.
  virtual void OnDestroy();

 private:
  friend class WindowClassRegistrar;

  // OS callback that receives messages for the window.
  static LRESULT CALLBACK WndProc(HWND window,
                                  UINT message,
                                  WPARAM wparam,
                                  LPARAM lparam) noexcept;

  // Retrieves a class instance pointer for |window|, if one was saved.
  static Win32Window* GetThisFromHandle(HWND window) noexcept;

  // Update the window theme that matches the system theme.
  void UpdateTheme(HWND window);

  bool quit_on_close_ = false;

  // window handle for this window.
  HWND window_handle_ = nullptr;

  // window handle of child content, if any.
  HWND child_content_ = nullptr;
};

#endif  // RUNNER_WIN32_WINDOW_H_

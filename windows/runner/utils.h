#ifndef RUNNER_UTILS_H_
#define RUNNER_UTILS_H_

#include <string>
#include <vector>

// Creates a console for the process, and redirects stdout and stderr to
// it for both the runner and the Flutter library.
void CreateAndAttachConsole();

// Takes the command line arguments and returns them as a vector of UTF-8
// strings.
void GetCommandLineArguments(std::vector<std::string>* out);

#endif  // RUNNER_UTILS_H_

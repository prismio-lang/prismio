#ifndef PRISMIO_PLATFORM_H
#define PRISMIO_PLATFORM_H

// Platform includes plus the few macros that paper over the differences between
// the Win32 and POSIX APIs the toolchain uses.
//
// Shared by both halves of the former driver.c -- program_support.c (linked into
// every compiled Prismio program) and build_driver.c (linked only into the
// compiler) -- so the two translation units cannot drift apart on things like the
// path separator.

// <stdint.h> is here for the uint32_t that _NSGetExecutablePath() takes on macOS.
// Windows headers drag it in transitively, which is why its absence went unnoticed;
// on Apple platforms nothing else includes it and program_support.c fails to build.
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <direct.h>
#include <process.h>
#include <windows.h>
#define PRISMIO_GETPID _getpid
#define PRISMIO_MKDIR(path) _mkdir(path)
#define PRISMIO_RMDIR(path) _rmdir(path)
#define PRISMIO_PATH_SEP '\\'
#else
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>
#ifdef __APPLE__
#include <mach-o/dyld.h>
#endif
#define PRISMIO_GETPID getpid
#define PRISMIO_MKDIR(path) mkdir(path, 0777)
#define PRISMIO_RMDIR(path) rmdir(path)
#define PRISMIO_PATH_SEP '/'
#endif

#endif

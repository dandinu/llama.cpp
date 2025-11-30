# Windows XP 64-bit Cross-Compilation Toolchain for MinGW-w64
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR x86_64)

# Compiler configuration
set(CMAKE_C_COMPILER x86_64-w64-mingw32-gcc)
set(CMAKE_CXX_COMPILER x86_64-w64-mingw32-g++)
set(CMAKE_RC_COMPILER x86_64-w64-mingw32-windres)

# Cross-compilation settings
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

# Target Windows XP 64-bit (0x0502 = Windows XP 64-bit / Server 2003)
# This is critical for XP compatibility
add_compile_definitions(_WIN32_WINNT=0x0502)
add_compile_definitions(WINVER=0x0502)

# Override GGML_WIN_VER to prevent it from being set to 0x0A00 (Windows 10)
# FORCE is required because ggml/CMakeLists.txt sets it by default
set(GGML_WIN_VER "0x0502" CACHE STRING "ggml: Windows version" FORCE)

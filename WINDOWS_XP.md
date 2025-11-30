# Building llama.cpp for Windows XP 64-bit

## Introduction

This guide shows you how to cross-compile llama.cpp from macOS to create Windows XP (64-bit) compatible binaries. You'll be able to run modern AI language models on a Windows XP system!

**What you'll get:**
- llama-cli.exe (main CLI tool)
- llama-bench.exe (benchmarking)
- llama-quantize.exe (model optimization)
- llama-perplexity.exe (testing)
- And 60+ other tools

**Target System:** Windows XP 64-bit (x64) / Windows Server 2003 x64

> **Note:** For 32-bit Windows XP, use `0x0501` instead of `0x0502` in the toolchain file and use `i686-w64-mingw32` compilers.

---

## Prerequisites

### On macOS (Build Machine)
- macOS (any recent version)
- Homebrew package manager
- ~2 GB free disk space
- Internet connection

### On Windows XP (Target Machine)
- Windows XP 64-bit or Windows Server 2003 x64
- ~500 MB free disk space (more for models)
- **Visual C++ Redistributable for Visual Studio 2019 (version 16.7) x64** - REQUIRED!

---

## Part 1: Building on macOS

### Step 1: Install Build Tools

If you don't have Homebrew installed:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Install the required tools:
```bash
brew install mingw-w64 cmake git
```

This installs:
- **mingw-w64**: Cross-compiler for Windows
- **cmake**: Build system
- **git**: Version control

### Step 2: Get llama.cpp Source Code

```bash
cd ~
git clone https://github.com/ggml-org/llama.cpp
cd llama.cpp
```

### Step 3: Create XP Toolchain File

Create `cmake/xp64-toolchain.cmake`:

```bash
cat > cmake/xp64-toolchain.cmake << 'EOF'
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

# Target Windows XP 64-bit (0x0502)
add_compile_definitions(_WIN32_WINNT=0x0502)
add_compile_definitions(WINVER=0x0502)

# Override GGML default Windows version
set(GGML_WIN_VER "0x0502" CACHE STRING "ggml: Windows version" FORCE)
EOF
```

### Step 4: Downgrade cpp-httplib (Critical!)

The bundled cpp-httplib version doesn't support Windows XP. Replace it with v0.15.3:

```bash
# Backup original version
cp vendor/cpp-httplib/httplib.h vendor/cpp-httplib/httplib.h.backup

# Download XP-compatible version
curl -L https://raw.githubusercontent.com/yhirose/cpp-httplib/v0.15.3/httplib.h \
     -o vendor/cpp-httplib/httplib.h

# Verify version
head -20 vendor/cpp-httplib/httplib.h | grep "CPPHTTPLIB_VERSION"
# Should show: #define CPPHTTPLIB_VERSION "0.15.3"
```

### Step 5: Modify cpp-httplib CMakeLists.txt

Edit `vendor/cpp-httplib/CMakeLists.txt` to make it header-only (v0.15.3 is header-only):

```bash
# Change line 5 from:
# add_library(${TARGET} STATIC httplib.cpp httplib.h)
# To:
# add_library(${TARGET} INTERFACE)
# And add include directory

# The file should look like this at the top:
cat > vendor/cpp-httplib/CMakeLists.txt << 'EOF'
set(TARGET cpp-httplib)

find_package(Threads REQUIRED)

# Version 0.15.3 is header-only
add_library(${TARGET} INTERFACE)
target_include_directories(${TARGET} INTERFACE ${CMAKE_CURRENT_SOURCE_DIR})

target_link_libraries  (${TARGET} INTERFACE Threads::Threads)
# Link Winsock2 on Windows for socket functions
if (WIN32)
    target_link_libraries(${TARGET} INTERFACE ws2_32)
endif()
target_compile_features(${TARGET} INTERFACE cxx_std_17)

target_compile_definitions(${TARGET} INTERFACE
    CPPHTTPLIB_FORM_URL_ENCODED_PAYLOAD_MAX_LENGTH=1048576
    CPPHTTPLIB_LISTEN_BACKLOG=512
    CPPHTTPLIB_REQUEST_URI_MAX_LENGTH=32768
    CPPHTTPLIB_TCP_NODELAY=1
)
EOF
```

### Step 6: Fix Threading for Windows XP

Edit `ggml/src/ggml-cpu/ggml-cpu.c` around line 391-406 to add XP-compatible threading:

Look for this section:
```c
#if defined(_WIN32)

typedef CONDITION_VARIABLE ggml_cond_t;
typedef SRWLOCK            ggml_mutex_t;
```

Replace it with XP-compatible code that uses `CRITICAL_SECTION` instead of `SRWLOCK` for Windows XP.

> **Tip:** This step is already done in the repository if you're following recent commits. The code now checks `_WIN32_WINNT < 0x0600` and uses XP-compatible primitives.

### Step 7: Configure the Build

```bash
cmake -B build-xp \
  -DCMAKE_TOOLCHAIN_FILE=cmake/xp64-toolchain.cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLAMA_CURL=OFF \
  -DLLAMA_HTTPLIB=ON \
  -DLLAMA_BUILD_SERVER=OFF \
  -DGGML_NATIVE=OFF \
  -DGGML_AVX=OFF \
  -DGGML_AVX2=OFF \
  -DGGML_FMA=OFF \
  -DGGML_F16C=OFF \
  -DGGML_SSE42=ON \
  -DBUILD_SHARED_LIBS=OFF
```

**Build flags explained:**
- `LLAMA_CURL=OFF` - Avoid curl dependency issues on XP
- `LLAMA_HTTPLIB=ON` - Use httplib for downloads instead
- `LLAMA_BUILD_SERVER=OFF` - Server isn't compatible with httplib v0.15.3
- `GGML_NATIVE=OFF` - Don't optimize for your Mac's CPU
- `GGML_AVX/AVX2/FMA/F16C=OFF` - Disable modern CPU features
- `GGML_SSE42=ON` - Safe for most 64-bit CPUs from 2008+
- `BUILD_SHARED_LIBS=OFF` - Static linking preferred

### Step 8: Build the Project

```bash
cmake --build build-xp --config Release --parallel $(sysctl -n hw.ncpu)
```

This takes 5-15 minutes depending on your Mac's CPU. The build uses all available CPU cores.

**Expected output:**
```
[100%] Built target llama-cli
[100%] Built target llama-bench
...
```

### Step 9: Collect Files for Deployment

Create a deployment package with executables and required DLLs:

```bash
# Create deploy directory
mkdir -p build-xp/deploy

# Copy all executables
cp build-xp/bin/*.exe build-xp/deploy/

# Copy MinGW runtime DLLs (required)
cp /opt/homebrew/Cellar/mingw-w64/*/toolchain-x86_64/x86_64-w64-mingw32/lib/libgcc_s_seh-1.dll \
   /opt/homebrew/Cellar/mingw-w64/*/toolchain-x86_64/x86_64-w64-mingw32/lib/libstdc++-6.dll \
   /opt/homebrew/Cellar/mingw-w64/*/toolchain-x86_64/x86_64-w64-mingw32/bin/libwinpthread-1.dll \
   build-xp/deploy/

# Create ZIP package
cd build-xp
zip -r llama-cpp-winxp-x64.zip deploy/

# Verify
ls -lh llama-cpp-winxp-x64.zip
```

**You now have:** `build-xp/llama-cpp-winxp-x64.zip` (~120 MB)

This ZIP contains:
- 70+ Windows executables (.exe files)
- 3 MinGW runtime DLLs (libgcc, libstdc++, libwinpthread)

---

## Part 2: Setting Up Windows XP

### Step 1: Install Visual C++ Redistributable (CRITICAL!)

> **⚠️ IMPORTANT:** You MUST install this or the executables won't run!

**Download Link:**
- **Visual C++ Redistributable for Visual Studio 2019 (version 16.7) x64**
- Get it from: https://github.com/LegacyUpdate/LegacyUpdate/issues/352
- Look for the x64 version link in that thread

**What this provides:**
- Universal C Runtime (UCRT) DLLs
- Required `api-ms-win-crt-*.dll` files
- `ucrtbase.dll`

**Installation:**
1. Download the installer to your Windows XP VM
2. Run the installer (vc_redist.x64.exe)
3. Follow the installation wizard
4. Restart Windows XP

**Without this, you'll get this error:**
```
This application has failed to start because api-ms-win-crt-heap-l1-1-0.dll
was not found. Re-installing the application may fix this problem.
```

### Step 2: Transfer Files to Windows XP

**Option A: Shared Folder (UTM/VMware/VirtualBox)**
1. Configure shared folder in your VM settings
2. Copy `llama-cpp-winxp-x64.zip` to the shared folder
3. Access from XP via network share

**Option B: ISO Image**
1. Create an ISO containing the ZIP:
   ```bash
   mkdir iso-staging
   cp build-xp/llama-cpp-winxp-x64.zip iso-staging/
   hdiutil makehybrid -o llama-xp.iso -iso -joliet iso-staging/
   ```
2. Mount the ISO in your VM
3. Copy files from the mounted drive

**Option C: USB Drive**
- Copy the ZIP to a USB drive
- Pass the USB device to your VM

### Step 3: Extract Files on Windows XP

1. Create a folder for llama.cpp:
   ```cmd
   mkdir C:\llama
   cd C:\llama
   ```

2. Extract the ZIP file here

3. Verify all files are present:
   ```cmd
   dir *.exe
   dir *.dll
   ```

   You should see:
   - 70+ .exe files
   - 3 .dll files (libgcc_s_seh-1.dll, libstdc++-6.dll, libwinpthread-1.dll)

### Step 4: Download a Language Model

You need a GGUF model file to run inference. Recommended starter model:

**Qwen2.5-0.5B-Instruct (Q4_K_M quantization)**
- Size: ~400 MB
- Best for testing on old hardware
- Download from: https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF
- File: `qwen2.5-0.5b-instruct-q4_k_m.gguf`

**Download methods:**
1. Download on a modern computer and transfer to XP
2. Use Internet Explorer on XP (slow but works)
3. Use a download manager on XP

Place the model file in `C:\llama\`

### Step 5: Test Your Installation

Open Command Prompt and run:

```cmd
cd C:\llama

REM Test version
llama-cli.exe --version

REM Test help
llama-cli.exe --help

REM Run inference
llama-cli.exe -m qwen2.5-0.5b-instruct-q4_k_m.gguf -p "Hello, how are you?" -n 100 --no-mmap

REM Benchmark performance
llama-bench.exe -m qwen2.5-0.5b-instruct-q4_k_m.gguf
```

**Successful output should show:**
- Model loading progress
- Inference tokens being generated
- Final statistics (tokens/second)

---

## Performance Expectations

**Typical Windows XP hardware (2006-2008 era):**
- CPU: Intel Core 2 Quad or AMD Phenom
- RAM: 2-4 GB
- No GPU acceleration

**Expected inference speed:**
- **Qwen2.5-0.5B (Q4_K_M):** 2-8 tokens/second
- **TinyLlama-1.1B:** 1-4 tokens/second
- **Larger models (7B+):** <1 token/second (not recommended)

**Tips for better performance:**
- Use Q4_0 or Q4_K_M quantization (smaller = faster)
- Reduce context size: `--ctx-size 512`
- Limit threads: `-t 2` or `-t 4`
- Use `--no-mmap` if you experience stability issues
- Disable warmup: `--no-warmup`

---

## Troubleshooting

### Error: "api-ms-win-crt-heap-l1-1-0.dll was not found"

**Solution:** Install Visual C++ Redistributable for Visual Studio 2019 (version 16.7) x64
- Download from: https://github.com/LegacyUpdate/LegacyUpdate/issues/352
- This is REQUIRED - the executables won't run without it

### Error: "Missing DLL" (libgcc_s_seh-1.dll, libstdc++-6.dll, libwinpthread-1.dll)

**Solution:** These DLLs should be in the same folder as the .exe files
- Verify they're in `C:\llama\`
- Re-extract the ZIP if missing
- Make sure you extracted ALL files, not just the executables

### Error: "Not a valid Win32 application"

**Causes:**
- Running 64-bit executable on 32-bit Windows XP
- Executable is corrupted

**Solution:**
- Make sure you're using Windows XP **64-bit** (x64)
- Re-download and re-extract the ZIP
- For 32-bit XP, rebuild with `i686-w64-mingw32` toolchain

### Program crashes on startup (no error message)

**Cause:** CPU doesn't support required instruction sets

**Solution:** Rebuild with more conservative CPU flags:
```bash
cmake -B build-xp \
  -DCMAKE_TOOLCHAIN_FILE=cmake/xp64-toolchain.cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLAMA_CURL=OFF \
  -DLLAMA_HTTPLIB=ON \
  -DLLAMA_BUILD_SERVER=OFF \
  -DGGML_NATIVE=OFF \
  -DGGML_AVX=OFF \
  -DGGML_AVX2=OFF \
  -DGGML_FMA=OFF \
  -DGGML_F16C=OFF \
  -DGGML_SSE42=OFF  # Also disable SSE4.2
  -DGGML_SSSE3=OFF  # Disable all SIMD
  -DBUILD_SHARED_LIBS=OFF
```

### Very slow performance (< 1 token/second)

**This is expected on XP-era hardware!**

**Optimizations:**
- Use smaller models (0.5B - 1.1B parameters)
- Use aggressive quantization (Q4_0, Q3_K_S)
- Reduce context size: `--ctx-size 512` or `--ctx-size 256`
- Limit threads to match CPU cores: `-t 2`

### Out of memory errors

**Solutions:**
- Use smaller quantization (Q4_0 instead of Q4_K_M)
- Reduce context size: `--ctx-size 512`
- Use smaller models
- Close other applications

---

## Recommended Models for Windows XP

| Model | Size | Quantization | Speed | Use Case |
|-------|------|--------------|-------|----------|
| **Qwen2.5-0.5B** | ~300-500 MB | Q4_K_M | 2-8 t/s | Best for testing, chat |
| **TinyLlama-1.1B** | ~600-800 MB | Q4_K_M | 1-4 t/s | General purpose, chat |
| **Phi-2 (2.7B)** | ~1.5-2 GB | Q4_0 | 0.5-2 t/s | Better quality, slower |
| **StableLM 3B** | ~2 GB | Q4_0 | 0.5-1.5 t/s | Code, chat |

**Download sources:**
- Hugging Face: https://huggingface.co/models?library=gguf
- Search for "GGUF" models
- Look for Q4_K_M or Q4_0 quantization

---

## Advanced Usage

### Interactive Chat Mode

```cmd
llama-cli.exe -m model.gguf --interactive --interactive-first ^
  -p "You are a helpful assistant." ^
  --ctx-size 2048 -n -1
```

### Batch Processing

```cmd
echo "Translate to French: Hello, how are you?" > input.txt
llama-cli.exe -m model.gguf -f input.txt -n 100 > output.txt
```

### Generate with Custom Parameters

```cmd
llama-cli.exe -m model.gguf ^
  -p "Write a short poem about computers" ^
  -n 200 ^
  --temp 0.8 ^
  --top-k 40 ^
  --top-p 0.95 ^
  --repeat-penalty 1.1
```

### Quantize Your Own Models

Convert a larger GGUF model to a smaller quantization:

```cmd
llama-quantize.exe model-f16.gguf model-q4_0.gguf Q4_0
```

---

## Technical Details

### What Was Modified for XP Compatibility

1. **Windows API Level:**
   - Set `_WIN32_WINNT=0x0502` (Windows XP 64-bit)
   - Prevents use of Vista+ APIs

2. **Threading Primitives:**
   - Replaced `SRWLOCK` (Vista+) with `CRITICAL_SECTION` (XP-compatible)
   - Replaced `CONDITION_VARIABLE` with manual `Event` objects

3. **HTTP Library:**
   - Downgraded cpp-httplib from v0.28.0 to v0.15.3
   - v0.28.0 explicitly blocks Windows 8 and earlier

4. **CPU Features:**
   - Disabled AVX, AVX2, FMA, F16C (not available on old CPUs)
   - Kept SSE4.2 enabled (safe for most 64-bit CPUs from 2008+)

5. **C Runtime:**
   - Links against UCRT (requires VC++ Redistributable 2019)
   - Modern MinGW doesn't support the old MSVCRT.dll

### Build Artifacts

After building, you get:
- **70+ executables** in `build-xp/bin/`
- **3 MinGW DLLs** (libgcc, libstdc++, libwinpthread)
- **Package size:** ~120 MB compressed, ~358 MB extracted

### Files Modified in llama.cpp Source

1. `cmake/xp64-toolchain.cmake` - Created (toolchain file)
2. `vendor/cpp-httplib/httplib.h` - Replaced (v0.15.3)
3. `vendor/cpp-httplib/CMakeLists.txt` - Modified (header-only build)
4. `ggml/src/ggml-cpu/ggml-cpu.c` - Modified (XP threading support)

---

## Additional Resources

- **llama.cpp GitHub:** https://github.com/ggml-org/llama.cpp
- **GGUF Models:** https://huggingface.co/models?library=gguf
- **cpp-httplib:** https://github.com/yhirose/cpp-httplib
- **MinGW-w64:** https://www.mingw-w64.org/
- **VC++ Redistributable:** https://github.com/LegacyUpdate/LegacyUpdate/issues/352

---

## FAQ

**Q: Can I build for 32-bit Windows XP?**
A: Yes, use `i686-w64-mingw32-gcc` compiler and `_WIN32_WINNT=0x0501`

**Q: Why isn't llama-server included?**
A: It uses API features not available in cpp-httplib v0.15.3

**Q: Can I use GPU acceleration?**
A: No, CUDA/OpenCL aren't supported on Windows XP

**Q: Will this work on Windows 2000?**
A: No, Windows XP (0x0501/0x0502) is the minimum

**Q: Can I run larger models like Llama-7B?**
A: Yes, but expect <1 token/second on XP hardware. Use Q4_0 quantization.

**Q: Is this really running AI on Windows XP?**
A: Yes! Modern transformer models running on vintage 2001 operating system!

---

*Built with ❤️ for retro computing enthusiasts*

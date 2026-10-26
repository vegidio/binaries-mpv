# Chainloaded by the MSVC triplets (wired up by the windows action) for the
# ports that cl.exe can't compile: mpv and libplacebo. It swaps the compiler
# for clang-cl, which has the same ABI, flags and CRT as cl.exe, and keeps
# vcpkg's stock Windows toolchain for everything else. The action copies this
# file next to that toolchain, into vcpkg's scripts/toolchains/.

# vcpkg builds inside the Visual Studio environment, so VCINSTALLDIR points at
# VS's bundled LLVM (the "C++ Clang tools" component); the standalone LLVM
# install is a fallback.
if(CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "ARM64")
    set(Z_CLANG_CL_HOST ARM64)
else()
    set(Z_CLANG_CL_HOST x64)
endif()
find_program(Z_CLANG_CL clang-cl
    HINTS
        "$ENV{VCINSTALLDIR}/Tools/Llvm/${Z_CLANG_CL_HOST}/bin"
        "$ENV{ProgramFiles}/LLVM/bin"
    REQUIRED
)

set(CMAKE_C_COMPILER "${Z_CLANG_CL}" CACHE FILEPATH "")
set(CMAKE_CXX_COMPILER "${Z_CLANG_CL}" CACHE FILEPATH "")

include("${CMAKE_CURRENT_LIST_DIR}/windows.cmake")

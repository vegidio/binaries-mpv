# Runs after each port's portfile on the MinGW triplets (wired up through
# VCPKG_POST_PORTFILE_INCLUDES by the mingw action). It removes link flags
# from installed .pc files that break static linking on Windows. These matter
# for the self-contained libmpv-2.dll and for consumers of the static zip
# (`pkg-config --static mpv`). On static triplets vcpkg_fixup_pkgconfig has
# already merged Libs.private into Libs, so flags are removed from any line.

function(z_strip_pc_flags pc regex)
    file(READ "${pc}" contents)
    # Twice, because adjacent matches share the separating whitespace.
    string(REGEX REPLACE "[ \t]\"?(${regex})\"?([ \t\r\n])" "\\2" contents "${contents}")
    string(REGEX REPLACE "[ \t]\"?(${regex})\"?([ \t\r\n])" "\\2" contents "${contents}")
    file(WRITE "${pc}" "${contents}")
endfunction()

file(GLOB z_pc_files
    "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/*.pc"
    "${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig/*.pc"
)
foreach(pc IN LISTS z_pc_files)
    # Some ports (e.g. harfbuzz) record the C++ runtime they were built with as
    # absolute paths, including MSYS2's libgcc_s.a, which is the import library
    # of libgcc_s_seh-1.dll. That overrides -static-libgcc and makes anything
    # linked statically depend on the DLL. The compiler driver links libgcc
    # itself, so drop it.
    z_strip_pc_flags("${pc}" "[^ \t\"]*libgcc_s\\.a|-lgcc_s")
    # The other runtime archives are recorded as absolute paths into the build
    # machine's MSYS2 install, which won't exist where the zip is extracted;
    # refer to them by name instead.
    file(READ "${pc}" contents)
    string(REGEX REPLACE "\"?[A-Za-z]:/[^ \t\"]*/lib(stdc\\+\\+|c\\+\\+abi|c\\+\\+|unwind)\\.a\"?" "-l\\1" contents "${contents}")
    file(WRITE "${pc}" "${contents}")
endforeach()

# LuaJIT's upstream luajit.pc has `Libs.private: -Wl,-E -lm -ldl`, which is
# only valid on ELF platforms, and vcpkg's MinGW build installs it unchanged:
# lld rejects -E, GNU ld warns about --export-dynamic, and Windows has no libdl.
if(PORT STREQUAL "luajit")
    foreach(pc IN LISTS z_pc_files)
        z_strip_pc_flags("${pc}" "-Wl,-E|-ldl")
    endforeach()
endif()

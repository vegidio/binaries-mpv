# Runs after each port's portfile on the MinGW triplets (wired up through
# VCPKG_POST_PORTFILE_INCLUDES by the mingw action).
#
# LuaJIT's upstream luajit.pc has `Libs.private: -Wl,-E -lm -ldl`, which is
# only valid on ELF platforms, and vcpkg's MinGW build installs it unchanged.
# Anything linking LuaJIT statically through pkg-config (the self-contained
# libmpv-2.dll, and consumers of the static zip via `pkg-config --static mpv`)
# then fails: lld rejects -E, GNU ld warns about --export-dynamic, and there is
# no libdl on Windows. On static triplets vcpkg_fixup_pkgconfig has already
# merged Libs.private into Libs, so the flags are removed from any line.
if(PORT STREQUAL "luajit")
    foreach(pc IN ITEMS "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/luajit.pc" "${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig/luajit.pc")
        if(EXISTS "${pc}")
            file(READ "${pc}" contents)
            string(REGEX REPLACE "[ \t]\"?(-Wl,-E|-ldl)\"?([ \t\r\n])" "\\2" contents "${contents}")
            string(REGEX REPLACE "[ \t]\"?(-Wl,-E|-ldl)\"?([ \t\r\n])" "\\2" contents "${contents}")
            file(WRITE "${pc}" "${contents}")
        endif()
    endforeach()
endif()

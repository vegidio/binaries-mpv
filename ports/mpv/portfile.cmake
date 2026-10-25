vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO mpv-player/mpv
    REF "v${VERSION}"
    SHA512 d8806ef04455aeb65d45c5956b4589d7a9728f869b74b9bcd8c9ab08475c28538334399ddc7fc2aee6a31fd178fe4b87ec755cd99ffa6e29ab4b6b61757b9320
    HEAD_REF master
)

# Only libmpv is built (no mpv player). Every feature we rely on is `enabled`
# so a missing dependency fails the build instead of silently dropping it;
# backends that make no sense for a redistributable library are `disabled`.
set(OPTIONS
    -Dlibmpv=true
    -Dcplayer=false
    -Dgpl=true
    -Dbuild-date=false
    -Dtests=false
    -Dfuzzers=false
    -Dhtml-build=disabled
    -Dmanpage-build=disabled
    -Dpdf-build=disabled
    -Dlibavdevice=enabled
    -Dlua=luajit
    -Djavascript=enabled
    -Dlcms2=enabled
    -Duchardet=enabled
    -Dlibbluray=enabled
    -Dlibarchive=enabled
    -Ddvdnav=enabled
    -Djpeg=enabled
    -Dzimg=enabled
    -Dzlib=enabled
    -Diconv=enabled
    -Dgl=enabled
    -Dcdda=disabled
    -Ddvbin=disabled
    -Drubberband=disabled
    -Dvapoursynth=disabled
    -Djack=disabled
    -Dopenal=disabled
    -Dsndio=disabled
    -Doss-audio=disabled
    -Dsdl2-audio=disabled
    -Dsdl2-video=disabled
    -Dsdl2-gamepad=disabled
    -Dcaca=disabled
    -Dsixel=disabled
    -Duwp=disabled
)

if(VCPKG_TARGET_IS_OSX)
    # cocoa (needed for gl-cocoa and VideoToolbox GL interop) requires Swift in
    # mpv 0.41. mpv invokes swiftc without a target, so pass one explicitly:
    # otherwise it builds for the host arch (breaking the x64 cross-compile) and
    # the host OS version (ignoring the deployment target).
    # No Vulkan: vcpkg has no MoltenVK port. audiounit is iOS-only (RemoteIO).
    # X11 is disabled so a Homebrew libX11 on the build machine can't leak in.
    # mpv also has swiftc emit a static *library* named swift.o; ar can't nest
    # archives, so a static libmpv.a ends up empty. Emit one plain object file
    # (whole-module) instead, which links the same way in both linkages.
    vcpkg_replace_string("${SOURCE_PATH}/osdep/mac/meson.build"
        "swift_flags = ['-c', '-emit-library', '-static', "
        "swift_flags = ['-c', '-wmo', "
    )
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
        set(SWIFT_ARCH x86_64)
    else()
        set(SWIFT_ARCH arm64)
    endif()
    if(VCPKG_OSX_DEPLOYMENT_TARGET)
        set(SWIFT_DEPLOYMENT "${VCPKG_OSX_DEPLOYMENT_TARGET}")
    elseif(DEFINED ENV{MACOSX_DEPLOYMENT_TARGET})
        set(SWIFT_DEPLOYMENT "$ENV{MACOSX_DEPLOYMENT_TARGET}")
    else()
        set(SWIFT_DEPLOYMENT "11.0")
    endif()
    list(APPEND OPTIONS
        "-Dswift-flags=-target ${SWIFT_ARCH}-apple-macos${SWIFT_DEPLOYMENT}"
        -Dcocoa=enabled
        -Dgl-cocoa=enabled
        -Dvideotoolbox-gl=enabled
        -Dcoreaudio=enabled
        -Davfoundation=enabled
        -Daudiounit=disabled
        -Dx11=disabled
        -Dx11-clipboard=disabled
        -Dvulkan=disabled
        -Dswift-build=enabled
        -Dmacos-cocoa-cb=disabled
        -Dmacos-media-player=disabled
        -Dmacos-touchbar=disabled
    )
elseif(VCPKG_TARGET_IS_LINUX)
    # Display and audio stacks (X11, Wayland, EGL, DRM, PulseAudio, PipeWire,
    # ALSA) come from the system and stay dynamically linked: GL/EGL must be
    # the user's driver, and these are present on every desktop.
    list(APPEND OPTIONS
        -Dx11=enabled
        -Dwayland=enabled
        -Degl=enabled
        -Degl-x11=enabled
        -Degl-wayland=enabled
        -Degl-drm=enabled
        -Ddrm=enabled
        -Dgbm=enabled
        -Dvulkan=enabled
        -Dvaapi=enabled
        -Dvaapi-drm=enabled
        -Dvaapi-x11=enabled
        -Dvaapi-wayland=enabled
        -Dvdpau=enabled
        -Dpulse=enabled
        -Dpipewire=enabled
        -Dalsa=enabled
    )
elseif(VCPKG_TARGET_IS_MINGW)
    # mpv looks for the shared SPIRV-Cross C API, but vcpkg only builds it
    # static, and its static .pc lists only -lspirv-cross-c. Use that .pc and
    # add the backend archives spirv-cross-c depends on (core last, for GNU ld).
    # They're looked up in the .pc's libdir: with prefer_static (the DLL build
    # below) find_library ignores -L flags and searches only compiler dirs.
    vcpkg_replace_string("${SOURCE_PATH}/meson.build"
        "spirv_cross = dependency('spirv-cross-c-shared', required:\n    get_option('spirv-cross').require(features['win32-desktop']))"
        "spirv_cross = dependency('spirv-cross-c', required:\n    get_option('spirv-cross').require(features['win32-desktop']))
if spirv_cross.found()
    spirv_cross_dirs = [spirv_cross.get_variable('libdir')]
    spirv_cross_libs = []
    foreach l : ['glsl', 'hlsl', 'msl', 'cpp', 'reflect', 'util', 'core']
        spirv_cross_libs += cc.find_library('spirv-cross-' + l, dirs: spirv_cross_dirs)
    endforeach
    spirv_cross = declare_dependency(dependencies: [spirv_cross] + spirv_cross_libs)
endif"
    )
    # mpv only uses libdl for C plugins on POSIX, but probes for it everywhere;
    # don't, so a stray libdl can never leak -ldl into the DLL link or mpv.pc.
    vcpkg_replace_string("${SOURCE_PATH}/meson.build"
        "libdl = dependency('dl', required: false)"
        "libdl = dependency('', required: false)"
    )
    list(APPEND OPTIONS
        -Dd3d11=enabled
        -Dd3d-hwaccel=enabled
        -Dwasapi=enabled
        -Dgl-win32=enabled
        -Dvulkan=enabled
        -Dshaderc=enabled
        -Dspirv-cross=enabled
        -Dwin32-smtc=disabled
        -Degl-angle=disabled
    )
endif()

vcpkg_find_acquire_program(PYTHON3)

# mpv's macOS code is Objective-C; vcpkg only puts the compilers for the listed
# languages into its meson machine file, which matters for the x64 cross-build.
set(LANGUAGES C CXX)
if(VCPKG_TARGET_IS_OSX)
    list(APPEND LANGUAGES OBJC)
endif()

vcpkg_configure_meson(
    SOURCE_PATH "${SOURCE_PATH}"
    LANGUAGES ${LANGUAGES}
    OPTIONS
        ${OPTIONS}
    ADDITIONAL_BINARIES
        "python3 = ['${PYTHON3}']"
)

vcpkg_install_meson()

# On the MinGW static triplet, also produce a self-contained libmpv-2.dll for
# MSVC consumers: link libmpv as a DLL against the static archives of FFmpeg
# and every other dependency (prefer_static = `pkg-config --static`), with the
# compiler runtime linked in too, so the DLL imports only Windows system DLLs.
# Only the DLL is kept (in bin/); the static libmpv.a and its .pc stay as-is.
if(VCPKG_TARGET_IS_MINGW AND VCPKG_LIBRARY_LINKAGE STREQUAL "static")
    file(RENAME "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/mpv.pc" "${CURRENT_BUILDTREES_DIR}/mpv-static.pc")
    vcpkg_replace_string("${SOURCE_PATH}/meson.build"
        "link_args: cc.get_supported_link_arguments(['-Wl,-Bsymbolic']),"
        "link_args: cc.get_supported_link_arguments(['-Wl,-Bsymbolic', '-static', '-static-libgcc', '-static-libstdc++']),"
    )
    set(VCPKG_LIBRARY_LINKAGE dynamic)
    vcpkg_configure_meson(
        SOURCE_PATH "${SOURCE_PATH}"
        LANGUAGES ${LANGUAGES}
        OPTIONS
            ${OPTIONS}
            -Dprefer_static=true
        ADDITIONAL_BINARIES
            "python3 = ['${PYTHON3}']"
    )
    vcpkg_install_meson()
    set(VCPKG_LIBRARY_LINKAGE static)
    file(REMOVE "${CURRENT_PACKAGES_DIR}/lib/libmpv.dll.a")
    file(RENAME "${CURRENT_BUILDTREES_DIR}/mpv-static.pc" "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/mpv.pc")
    set(VCPKG_POLICY_DLLS_IN_STATIC_LIBRARY enabled)
endif()

vcpkg_copy_pdbs()
vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include" "${CURRENT_PACKAGES_DIR}/debug/share")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.GPL" "${SOURCE_PATH}/LICENSE.LGPL" "${SOURCE_PATH}/Copyright")

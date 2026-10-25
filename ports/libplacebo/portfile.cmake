# libplacebo has no vcpkg port. Its build needs five git submodules that GitHub
# source tarballs don't contain, so each one is fetched at the commit pinned by
# the libplacebo tag and dropped into 3rdparty/. Bump all of them together.
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO haasn/libplacebo
    REF "v${VERSION}"
    SHA512 209b1713cff34f06149af16fb3ea52e3662a566ef5df6b29811ad295aa8cb6388f827a93fc8e0eed1a72f35b3b3aae835520c933079e706a51d11136a8128799
    HEAD_REF master
)

# name|repo|commit|sha512
set(SUBMODULES
    "glad|Dav1dde/glad|73db193f853e2ee079bf3ca8a64aa2eaf6459043|f20873b108cda958c9a3d48dad46d09636e98ed7a6b3d176a8164d2994cafbb06b2b8692217afd95e5278c96cc430f70ceda68057ca059e25ba3f4b719316eaa"
    "jinja|pallets/jinja|15206881c006c79667fe5154fe80c01c65410679|e1082222a4660e60f05e970e7c5b6f2fab377ba01c273bcb6fe0ead457ea5d4764c1d95fb3264b6bc371e122d574517ac35b6ae3858b50bc4918acd08a3f75de"
    "markupsafe|pallets/markupsafe|297fc8e356e6836a62087949245d09a28e9f1b13|8e16146b42de9f0939b706c1652d4c5fe8e67e1f7e0c5a0e37d698d9ab10dcadf3e26b12e4be2b37209c33703996351b02c54af7ceb2d9eaf24aede7cecdf648"
    "fast_float|fastfloat/fast_float|97b54ca9e75f5303507699d27c6b4f4efe4641a1|9b9bc2434b2569bb049e209980b7cbedfb00b90b8579859581db9271385f965e6225dc5dc6359665ef95b0463924f8fe0e5c96c68a364e5d696d1687633971cd"
    "Vulkan-Headers|KhronosGroup/Vulkan-Headers|450bd2232225d6c7728a4108055ac2e37cef6475|eee6d264779ab1a7c8a6632e4780eeb9fab3c67726d5fa3bdf8750a18d7f630734f0c60f59c9d9a469f6df9e2ff630f7694ce693c8d77954d248d2094412e10e"
)
foreach(SUBMODULE IN LISTS SUBMODULES)
    string(REPLACE "|" ";" PARTS "${SUBMODULE}")
    list(GET PARTS 0 SUB_NAME)
    list(GET PARTS 1 SUB_REPO)
    list(GET PARTS 2 SUB_REF)
    list(GET PARTS 3 SUB_SHA512)
    vcpkg_from_github(
        OUT_SOURCE_PATH SUB_PATH
        REPO "${SUB_REPO}"
        REF "${SUB_REF}"
        SHA512 "${SUB_SHA512}"
    )
    file(REMOVE_RECURSE "${SOURCE_PATH}/3rdparty/${SUB_NAME}")
    file(RENAME "${SUB_PATH}" "${SOURCE_PATH}/3rdparty/${SUB_NAME}")
endforeach()

# The bundled Vulkan-Headers (always in sync with the vk.xml the code generator
# reads) are used everywhere. On macOS there is no Vulkan loader in vcpkg
# (no MoltenVK port), so Vulkan is disabled there and mpv renders via OpenGL.
if(VCPKG_TARGET_IS_OSX)
    set(VULKAN disabled)
    set(SHADERC disabled)
else()
    set(VULKAN enabled)
    set(SHADERC enabled)
endif()

if(VCPKG_TARGET_IS_WINDOWS)
    set(D3D11 enabled)
    # The D3D11 backend looks for the shared SPIRV-Cross C API, but vcpkg only
    # builds it static, and its static .pc lists only -lspirv-cross-c. Use that
    # .pc and add the backend archives it depends on (core last, for GNU ld).
    vcpkg_replace_string("${SOURCE_PATH}/src/d3d11/meson.build"
        "  dependency('spirv-cross-c-shared', version: '>=0.29.0', required: d3d11),"
        "  declare_dependency(dependencies: [
    dependency('spirv-cross-c', version: '>=0.29.0', required: d3d11),
    cc.find_library('spirv-cross-glsl', required: d3d11),
    cc.find_library('spirv-cross-hlsl', required: d3d11),
    cc.find_library('spirv-cross-msl', required: d3d11),
    cc.find_library('spirv-cross-cpp', required: d3d11),
    cc.find_library('spirv-cross-reflect', required: d3d11),
    cc.find_library('spirv-cross-util', required: d3d11),
    cc.find_library('spirv-cross-core', required: d3d11),
  ]),"
    )
else()
    set(D3D11 disabled)
endif()

vcpkg_find_acquire_program(PYTHON3)

vcpkg_configure_meson(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -Ddemos=false
        -Dtests=false
        -Dbench=false
        -Dfuzz=false
        -Dopengl=enabled
        -Dvulkan=${VULKAN}
        -Dshaderc=${SHADERC}
        -Dglslang=disabled
        -Dd3d11=${D3D11}
        -Dlcms=enabled
        -Dxxhash=enabled
        -Ddovi=enabled
        -Dlibdovi=disabled
        -Dunwind=disabled
    ADDITIONAL_BINARIES
        "python3 = ['${PYTHON3}']"
)

vcpkg_install_meson()
vcpkg_copy_pdbs()
vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include" "${CURRENT_PACKAGES_DIR}/debug/share")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")

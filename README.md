# binaries-mpv

A repository with static and dynamic binaries for **libmpv**, the client library of the [mpv](https://mpv.io) media player. Each archive also contains **every library libmpv needs**: FFmpeg (`libavcodec`, `libavformat`, `libavutil`, `libavfilter`, `libavdevice`, `libswscale`, `libswresample`), libplacebo, libass and all codec, subtitle, font and GPU dependencies, plus the headers. An app that links libmpv from one of these archives can play nearly any video without installing anything else.

The binaries are **not** the `mpv` player application. Only the library and headers are produced, for embedding mpv in other projects.

## Platforms

x64 & arm64 for macOS, Linux and Windows. On Windows there are two variants:

- **MinGW** — static and dynamic, built with GCC (x64) or Clang (arm64) in MSYS2.
- **Windows (MSVC)** — static and dynamic, for `*-pc-windows-msvc` / Visual Studio consumers. Dependencies are built with MSVC (`cl.exe`); mpv and libplacebo, which don't build with `cl.exe`, are built with `clang-cl` (same ABI), as mpv's own MSVC CI does. Both variants use the **dynamic CRT (`/MD`)**, so your app must be built with `/MD` too (Rust: the default, i.e. without `+crt-static`) and needs the Visual C++ Redistributable, which is usually already installed.

| Archive                        | Contents                                                                  |
|--------------------------------|---------------------------------------------------------------------------|
| `static_osx_<arch>.zip`        | `include/`, `lib/*.a`, `lib/pkgconfig/*.pc`                               |
| `dynamic_osx_<arch>.zip`       | `include/`, `lib/*.dylib`                                                 |
| `static_linux_<arch>.zip`      | `include/`, `lib/*.a`, `lib/pkgconfig/*.pc`                               |
| `dynamic_linux_<arch>.zip`     | `include/`, `lib/*.so*`                                                   |
| `static_mingw_<arch>.zip`      | `include/`, `lib/*.a`, `lib/pkgconfig/*.pc`                               |
| `dynamic_mingw_<arch>.zip`     | `include/`, `lib/*.dll` (incl. the MinGW runtime DLLs)¹                   |
| `static_windows_<arch>.zip`    | `include/`, `lib/*.lib`, `lib/pkgconfig/*.pc`                             |
| `dynamic_windows_<arch>.zip`   | `include/`, `lib/*.dll`, `lib/mpv.lib` (import library of `mpv-2.dll`)   |

¹ A few libraries can't be built as DLLs with MinGW (libvpx, LuaJIT, zimg, SPIRV-Tools), so they are linked statically into the DLLs that use them (e.g. LuaJIT and zimg are inside `libmpv-2.dll`) instead of shipping as separate DLLs.

Versions: **mpv 0.41.0** and **libplacebo 7.360.1**, built as [vcpkg overlay ports](ports/), on top of [vcpkg](https://vcpkg.io) `master` (**FFmpeg 9.0.2**). Only **Release** binaries are produced.

## Linking

### Static

The static archives contain dozens of libraries, so let pkg-config work out the link line. The `.pc` files are relocatable:

```sh
export PKG_CONFIG_PATH=/path/to/static_<os>_<arch>/lib/pkgconfig
cc app.c $(pkg-config --cflags mpv) $(pkg-config --static --libs mpv)
```

For **Windows (MSVC)**, the same `.pc` files work with `pkgconf`'s `--msvc-syntax`, which outputs `cl.exe`/`link.exe` flags:

```sh
cl /MD app.c $(pkgconf --cflags --msvc-syntax mpv) /link $(pkgconf --static --libs --msvc-syntax mpv)
```

On **Linux**, the display and audio stacks stay **dynamically linked to the system**: X11, Wayland, EGL/GL, GBM, libdisplay-info, VDPAU, PulseAudio, PipeWire and ALSA. The OpenGL/EGL driver must be the user's own, and these libraries are on every desktop. Everything else (FFmpeg, codecs, libplacebo, libass, VA-API, libdrm, …) is in the archive.

On **macOS**, only Apple system frameworks and `/usr/lib` libraries (including the Swift runtime in `/usr/lib/swift`, part of the OS since 10.14.4) are linked dynamically. libmpv contains some Swift code; the Swift back-deployment archives it needs (`libswiftCompatibility*.a`) are included in `lib/`, so no Xcode-specific link flags are needed.

Also on **macOS**, LuaJIT is built with internal unwinding (`LUAJIT_NO_UNWIND`, as LuaJIT does on iOS), so the static libraries use only the Objective-C and C++ personality routines. ld64's compact unwind format holds at most three per image, which leaves room for a third, such as Rust's `rust_eh_personality`, without `-Wl,-no_compact_unwind`. Lua scripts work as usual; the only difference is that C++ exceptions can't propagate through Lua frames, which libmpv never does.

### Dynamic

macOS and Linux libraries find each other through `@rpath`/`@loader_path` and `$ORIGIN`, so keep the whole `lib/` folder together next to your binary. On Windows, put all the DLLs next to your `.exe`.

## Binary size & debug stripping

Static libraries are **stripped of debug information** before packaging, using `strip --strip-debug` (Linux/MinGW) and `strip -S` (macOS). The MSVC libraries are compiled without debug information instead (vcpkg's default `/Z7` is dropped, FFmpeg is configured with `--disable-debug` and OpenSSL without its `/Zi`), and C++ code with `/Zc:inline`, so unreferenced inline functions aren't emitted into every object. The `static_windows` zip also contains only the libraries libmpv links (`pkg-config --static --libs mpv`). Only debug sections are removed; the symbol table is kept, so the libraries link exactly as before.

## Feature matrix

Legend: ✅ available · ❌ not available. Columns are `OS-arch`. The `windows` variant has the same features as `mingw`.

### libmpv

| Feature                | What it is                           | mac-x64 | mac-arm64 | lin-x64 | lin-arm64 | mingw-x64 | mingw-arm64 |
|------------------------|--------------------------------------|:-------:|:---------:|:-------:|:---------:|:---------:|:-----------:|
| libplacebo             | GPU renderer (`vo=gpu-next`)         |    ✅    |     ✅     |    ✅    |     ✅     |     ✅     |      ✅      |
| libass                 | ASS/SSA subtitles                    |    ✅    |     ✅     |    ✅    |     ✅     |     ✅     |      ✅      |
| OpenGL                 | render API (`MPV_RENDER_API_TYPE_OPENGL`) |  ✅   |     ✅     |    ✅    |     ✅     |     ✅     |      ✅      |
| Vulkan                 | `gpu-api=vulkan`                     |    ❌    |     ❌     |    ✅    |     ✅     |     ❌     |      ❌      |
| D3D11                  | `gpu-api=d3d11`                      |    ❌    |     ❌     |    ❌    |     ❌     |     ✅     |      ✅      |
| X11 / Wayland / DRM    | Linux windowing                      |    ❌    |     ❌     |    ✅    |     ✅     |     ❌     |      ❌      |
| Cocoa                  | macOS windowing                      |    ✅    |     ✅     |    ❌    |     ❌     |     ❌     |      ❌      |
| Lua (LuaJIT)           | Lua scripts                          |    ✅    |     ✅     |    ✅    |     ✅     |     ✅     |      ✅      |
| JavaScript (MuJS)      | JS scripts                           |    ✅    |     ✅     |    ✅    |     ✅     |     ✅     |      ✅      |
| lcms2                  | ICC color management                 |    ✅    |     ✅     |    ✅    |     ✅     |     ✅     |      ✅      |
| zimg                   | high-quality scaling                 |    ✅    |     ✅     |    ✅    |     ✅     |     ✅     |      ✅      |
| uchardet               | subtitle charset detection           |    ✅    |     ✅     |    ✅    |     ✅     |     ✅     |      ✅      |
| libbluray / dvdnav     | Blu-ray & DVD playback               |    ✅    |     ✅     |    ✅    |     ✅     |     ✅     |      ✅      |
| libarchive             | play from zip/rar/7z archives        |    ✅    |     ✅     |    ✅    |     ✅     |     ✅     |      ✅      |
| libjpeg                | JPEG screenshots                     |    ✅    |     ✅     |    ✅    |     ✅     |     ✅     |      ✅      |

### Hardware decoding

| hwdec                 | mac-x64 | mac-arm64 | lin-x64 | lin-arm64 | mingw-x64 | mingw-arm64 |
|-----------------------|:-------:|:---------:|:-------:|:---------:|:---------:|:-----------:|
| VideoToolbox          |    ✅    |     ✅     |    ❌    |     ❌     |     ❌     |      ❌      |
| VA-API                |    ❌    |     ❌     |    ✅    |     ✅     |     ❌     |      ❌      |
| VDPAU                 |    ❌    |     ❌     |    ✅    |     ✅     |     ❌     |      ❌      |
| NVDEC / CUDA          |    ❌    |     ❌     |    ✅    |     ✅     |     ✅     |      ❌      |
| D3D11VA / DXVA2       |    ❌    |     ❌     |    ❌    |     ❌     |     ✅     |      ✅      |
| Vulkan video          |    ❌    |     ❌     |    ✅    |     ✅     |     ❌     |      ❌      |

### Audio output

| AO                                 | macOS | Linux | Windows |
|------------------------------------|:-----:|:-----:|:-------:|
| CoreAudio / AVFoundation           |   ✅   |   ❌   |    ❌    |
| PipeWire / PulseAudio / ALSA       |   ❌   |   ✅   |    ❌    |
| WASAPI                             |   ❌   |   ❌   |    ✅    |

### FFmpeg

FFmpeg is built for **playback**: all native decoders, demuxers and protocols are enabled, plus these external libraries on every platform:

| Library   | What it adds                                    |
|-----------|-------------------------------------------------|
| dav1d     | AV1 decoding (fast)                             |
| vpx       | VP8/VP9 decoding, including alpha channel       |
| opus      | Opus audio                                      |
| speex     | Speex audio                                     |
| ilbc      | iLBC speech                                     |
| openjpeg  | JPEG 2000                                       |
| ass, freetype, fontconfig, fribidi, drawtext | subtitle and text filters |
| openssl   | HTTPS/TLS streams                               |
| xml2      | DASH manifests                                  |
| srt, ssh  | SRT and SFTP protocols                          |
| dvdvideo  | DVD-Video demuxer                               |
| snappy    | HAP video                                       |
| soxr      | high-quality resampling                         |
| bzip2, lzma, zlib, iconv | compression and charset conversion |

H.264, HEVC, VP9, MPEG-2/4, ProRes, AAC, AC-3, E-AC-3, DTS, FLAC, MP3, Vorbis, Theora, WebP and the rest use FFmpeg's own decoders, which need no external library.

## Features intentionally excluded

| Feature                                          | Reason                                                                                     |
|--------------------------------------------------|--------------------------------------------------------------------------------------------|
| x264, x265, svt-av1, aom, mp3lame, twolame, openh264, theora, vorbis, webp (external libs) | Encoders (or encoder-only wrappers); playback uses FFmpeg's native decoders or dav1d instead. Drops a lot of size and build time. |
| amf, qsv                                         | Hardware **encoding** only.                                                                |
| zmq, opencl, sdl2                                | Not used for playback.                                                                     |
| Vulkan on macOS                                  | vcpkg has no MoltenVK port; macOS renders through OpenGL and decodes through VideoToolbox. |
| Vulkan on Windows (`gpu-api=vulkan`, `hwdec=vulkan`, `vf=gpu`) | libmpv embedders use the OpenGL render API, which has no Vulkan option; D3D11 (`gpu-api=d3d11`) and D3D11VA/DXVA2 cover rendering and decoding. Removing Vulkan removes the `vulkan-1.dll` runtime dependency. |
| `cocoa-cb`, media keys, touch bar (macOS)        | Only used by the `mpv` player app, not by libmpv.                                          |
| `fdk-aac`                                        | Non-redistributable; FFmpeg's native AAC decoder covers playback.                          |
| rubberband                                       | Its vcpkg port (v4.0.0) fails to compile with modern compilers; `scaletempo2` (built in) does pitch-correct speed changes. |
| modplug / openmpt                                | Do not build cleanly across all triplets, so there is **no tracker-module (MOD/XM/IT/S3M) playback**. |
| VapourSynth, CDDA, DVB, JACK, OpenAL, SDL2, caca, sixel | Niche outputs/inputs that would pull extra system dependencies.                     |

## 📝 License

**libmpv** is built with `-Dgpl=true`, and these binaries are released under the GPLv3 License. See [LICENSE](LICENSE) for details.

## 👨🏾‍💻 Author

Vinicius Egidio ([vinicius.io](http://vinicius.io))

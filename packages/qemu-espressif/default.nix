{
  lib,
  stdenv,
  fetchFromGitLab,
  fetchFromGitHub,
  versionCheckHook,
  qemu,
  glib,
  zlib,
  libgcrypt,
  libaio,
  SDL2,
  SDL2_image,
  gtk3,
  gettext,
  vte,
  apple-sdk_13,
  valgrind-light,
  darwinMinVersionHook,
  esp32Support ? true,
  esp32c3Support ? true,
  sdlSupport ? false,
  gtkSupport ? false,
  cocoaSupport ? false,
  enableTools ? false,
  enableDebug ? false,
  enableTests ? true,
}:

assert esp32Support || esp32c3Support;

let
  keycodemapdb = fetchFromGitLab {
    owner = "qemu-project";
    repo = "keycodemapdb";
    rev = "f5772a62ec52591ff6870b7e8ef32482371f22c6";
    hash = "sha256-GbZ5mrUYLXMi0IX4IZzles0Oyc095ij2xAsiLNJwfKQ=";
  };

  berkeley-softfloat-3 = fetchFromGitLab {
    owner = "qemu-project";
    repo = "berkeley-softfloat-3";
    rev = "b64af41c3276f97f0e181920400ee056b9c88037";
    hash = "sha256-Yflpx+mjU8mD5biClNpdmon24EHg4aWBZszbOur5VEA=";
  };

  berkeley-testfloat-3 = fetchFromGitLab {
    owner = "qemu-project";
    repo = "berkeley-testfloat-3";
    rev = "e7af9751d9f9fd3b47911f51a5cfd08af256a9ab";
    hash = "sha256-inQAeYlmuiRtZm37xK9ypBltCJ+ycyvIeIYZK8a+RYU=";
  };

  libslirp = fetchFromGitLab {
    domain = "gitlab.freedesktop.org";
    owner = "slirp";
    repo = "libslirp";
    rev = "26be815b86e8d49add8c9a8b320239b9594ff03d";
    hash = "sha256-6LX3hupZQeg3tZdY1To5ZtkOXftwgboYul792mhUmds=";
  };

  targets =
    lib.optionals esp32Support [ "xtensa-softmmu" ]
    ++ lib.optionals esp32c3Support [ "riscv32-softmmu" ];

  # This version number is written into the VERSION file below and
  # the first components must be x.y.z or the meson.build complains:
  # "ERROR: Index 1 out of bounds of array of size 1."
  #
  # Any suffix to that will cause a problem during the build since it will end up
  # in a C macro, so we fix that particular problem by patching meson.build below.
  #
  # That way we still get the fancy version in the --version check,
  # but we keep the internal MAJOR/MINOR/MICRO versions numerical.
  #
  # Also: do not make this string too long in general or it will break
  # on macos GitHub runners, see workaround below.
  version = "9.2.2-20250817";

  mainProgram = if (!esp32Support) then "qemu-system-riscv32" else "qemu-system-xtensa";

  qemu' = qemu.override { minimal = true; };

  darwinSDK = [
    apple-sdk_13
    (darwinMinVersionHook "13")
  ];
in

qemu'.overrideAttrs (
  finalAttrs: previousAttrs: {
    pname = "${previousAttrs.pname}-${
      if (esp32Support && !esp32c3Support) then
        "esp32"
      else if (!esp32Support && esp32c3Support) then
        "esp32c3"
      else
        "espressif"
    }";
    inherit version;

    __structuredAttrs = !stdenv.hostPlatform.isDarwin; # TODO: Why doesn't this work on Darwin?
    strictDeps = true;

    src = fetchFromGitHub {
      owner = "espressif";
      repo = "qemu";
      tag = "esp-develop-${version}";
      hash = "sha256-Oc3fBtyd5lzTWK/DjrYXUvN0pmHnooKtT+yPIu+XNsk=";
    };

    buildInputs = [
      # dependencies declared in nixpkgs
      glib
      zlib
      # libslirp - we let Meson handle this to make sure the library is built statically
      # dependency from the espressif fork
      libgcrypt
    ]
    ++ lib.optionals sdlSupport [
      SDL2
      SDL2_image
    ]
    ++ lib.optionals gtkSupport [
      gtk3
      gettext
      vte
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [ libaio ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [ darwinSDK ]
    ++ lib.optionals (enableDebug && stdenv.hostPlatform.isLinux) [ valgrind-light ];

    postPatch =
      previousAttrs.postPatch
      + ''
        # Prefetch Meson subprojects, after checking that the revision that we fetch matches the original
        grep -q "revision = ${keycodemapdb.rev}" subprojects/keycodemapdb.wrap
        ln -s ${keycodemapdb} subprojects/keycodemapdb

        grep -q "revision = ${berkeley-softfloat-3.rev}" subprojects/berkeley-softfloat-3.wrap
        cp -r ${berkeley-softfloat-3} subprojects/berkeley-softfloat-3
        chmod a+w subprojects/berkeley-softfloat-3
        cp subprojects/packagefiles/berkeley-softfloat-3/* subprojects/berkeley-softfloat-3

        grep -q "revision = ${berkeley-testfloat-3.rev}" subprojects/berkeley-testfloat-3.wrap
        cp -r ${berkeley-testfloat-3} subprojects/berkeley-testfloat-3
        chmod a+w subprojects/berkeley-testfloat-3
        cp subprojects/packagefiles/berkeley-testfloat-3/* subprojects/berkeley-testfloat-3

        grep -q "revision = ${libslirp.rev}" subprojects/slirp.wrap
        ln -s ${libslirp} subprojects/slirp

        # Overwrite the supplied version with the nixpkgs version with the date suffix
        echo ${version} > VERSION

        # Prevent fancy custom suffixes from ending up in C macros that are intended to be integers
        substituteInPlace meson.build \
          --replace-fail "config_host_data.set('QEMU_VERSION_MICRO', meson.project_version().split('.')[2])" \
                         "config_host_data.set('QEMU_VERSION_MICRO', meson.project_version().split('.')[2].split('-')[0])"

        # Workaround for errors on (macos) GitHub actions runners:
        # ERROR:../tests/qtest/netdev-socket.c:203:test_stream_unix_reconnect: assertion failed (resp == "st0: index=0,type=stream,listening\r\n"):
        # ("st0: index=0,type=stream,error: UNIX socket path '/private/tmp/nix-build-qemu-esp32-9.2.2-unstable-2025-06-24.drv-0/netdev-socket.Q7TX92/stream_unix_reconnect'
        #  is too long\r\n" == "st0: index=0,type=stream,listening\r\n")
        # We can't really do anything about how nix makes its temp dirs, but we can slightly shrink the final socket name(s):
        substituteInPlace tests/qtest/netdev-socket.c \
          --replace-fail "/stream_unix" "/su"
      ''
      + (
        if enableTests then
          ''
            substituteInPlace tests/functional/meson.build \
              --replace-fail "'version'," "" \
              --replace-fail "'riscv_opensbi'," ""

            substituteInPlace tests/qtest/meson.build \
              --replace-fail "'device-introspect-test'," "" \
              --replace-fail "'qom-test'," "" \
              --replace-fail "'test-hmp'," ""
          ''
        else
          ''
            # Faster build, we don't need these files if we don't have checkPhase
            rm -rf tests/
            substituteInPlace meson.build \
              --replace-fail "subdir('tests/qtest/libqos')" "" \
              --replace-fail "subdir('tests/qtest/fuzz')" "" \
              --replace-fail "subdir('tests')" ""
            rm -rf docs/devel/testing/
          ''
      );

    configureFlags = [
      # Flags taken from the original nixpkgs expression
      "--disable-strip" # We'll strip ourselves after separating debug info.
      (lib.enableFeature enableTools "tools")
      "--localstatedir=/var"
      "--sysconfdir=/etc"
      "--cross-prefix=${stdenv.cc.targetPrefix}"

      # Flags taken from the instructions for the Espressif fork
      # Based on https://github.com/espressif/esp-toolchain-docs/blob/main/qemu/esp32/README.md
      # Based on https://github.com/espressif/esp-toolchain-docs/tree/main/qemu/esp32c3/README.md
      "--target-list=${lib.concatStringsSep "," targets}"
      "--enable-gcrypt"
      "--enable-slirp"
    ]
    ++ lib.optionals enableDebug [
      # Do not enable debug by default - amongst other things it spams the build log like crazy
      # The flag --disable-debug is not accepted, so we can't use lib.enableFeature here
      "--enable-debug"
    ]
    ++ [
      # https://github.com/espressif/qemu/issues/77
      # https://github.com/espressif/qemu/issues/84
      # "--enable-sanitizers"
      "--disable-user"
      "--disable-capstone"
      "--disable-vnc"
      "--disable-oss"
      "--disable-slirp-smbd"
    ]
    ++ lib.optionals sdlSupport [
      "--enable-sdl"
    ]
    ++ lib.optionals gtkSupport [
      "--enable-gtk"
    ]
    ++ lib.optionals (!cocoaSupport) [
      "--disable-cocoa"
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      "--enable-linux-aio"
    ];

    doCheck = enableTests;

    nativeInstallCheckInputs = [ versionCheckHook ];
    doInstallCheck = true;
    versionCheckProgram = "${builtins.placeholder "out"}/bin/${mainProgram}";

    meta = previousAttrs.meta // {
      inherit mainProgram;
      homepage = "https://github.com/espressif/qemu";
      maintainers = previousAttrs.meta.maintainers ++ [ lib.maintainers.sfrijters ];
    };
  }
)

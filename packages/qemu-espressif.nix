{ lib
, stdenv
, fetchFromGitLab
, fetchFromGitHub
, fetchpatch
, qemu
, libgcrypt
, enableEsp32 ? true
, enableEsp32c3 ? true
}:

assert enableEsp32 || enableEsp32c3;

let
  keycodemapdb = fetchFromGitLab {
    owner = "qemu-project";
    repo = "keycodemapdb";
    rev = "f5772a62ec52591ff6870b7e8ef32482371f22c6";
    hash = "sha256-EQrnBAXQhllbVCHpOsgREzYGncMUPEIoWFGnjo+hrH4=";
    fetchSubmodules = true;
  };

  berkeley-softfloat-3 = fetchFromGitLab {
    owner = "qemu-project";
    repo = "berkeley-softfloat-3";
    rev = "b64af41c3276f97f0e181920400ee056b9c88037";
    hash = "sha256-Yflpx+mjU8mD5biClNpdmon24EHg4aWBZszbOur5VEA=";
    fetchSubmodules = true;
  };

  berkeley-testfloat-3 = fetchFromGitLab {
    owner = "qemu-project";
    repo = "berkeley-testfloat-3";
    rev = "e7af9751d9f9fd3b47911f51a5cfd08af256a9ab";
    hash = "sha256-inQAeYlmuiRtZm37xK9ypBltCJ+ycyvIeIYZK8a+RYU=";
    fetchSubmodules = true;
  };

  targets =
    lib.optionals enableEsp32 [ "xtensa-softmmu" ] ++
    lib.optionals enableEsp32c3 [ "riscv32-softmmu" ];

  version = "8.2.0-20240122";
in

qemu.overrideAttrs (oldAttrs: {
  pname = "${oldAttrs.pname}-${if (enableEsp32 && !enableEsp32c3) then "esp32" else if (!enableEsp32 && enableEsp32c3) then "esp32c3" else "espressif"}";
  inherit version;

  src = fetchFromGitHub {
    owner = "espressif";
    repo = "qemu";
    rev = "refs/tags/esp-develop-${version}";
    hash = "sha256-5eJXDjhDaBU3rzPnVVKpg9bqThUy+WdR5ip40cCDklk=";
  };

  buildInputs = oldAttrs.buildInputs ++ [ libgcrypt ];

  postPatch = oldAttrs.postPatch + ''
    # Correctly detect libgcrypt
    substituteInPlace meson.build \
      --replace-fail config-tool pkg-config

    # Prefetch Meson subprojects
    rm subprojects/keycodemapdb.wrap
    ln -s ${keycodemapdb} subprojects/keycodemapdb

    rm subprojects/berkeley-softfloat-3.wrap
    cp -r ${berkeley-softfloat-3} subprojects/berkeley-softfloat-3
    chmod a+w subprojects/berkeley-softfloat-3
    cp subprojects/packagefiles/berkeley-softfloat-3/* subprojects/berkeley-softfloat-3

    rm subprojects/berkeley-testfloat-3.wrap
    cp -r ${berkeley-testfloat-3} subprojects/berkeley-testfloat-3
    chmod a+w subprojects/berkeley-testfloat-3
    cp subprojects/packagefiles/berkeley-testfloat-3/* subprojects/berkeley-testfloat-3
  '';

  patches = oldAttrs.patches ++ [
    # Fix display issues when using virtio-gpu on 8.2.0 https://gitlab.com/qemu-project/qemu/-/issues/2051
    (fetchpatch {
      url = "https://gitlab.com/qemu-project/qemu/-/commit/9d5b42beb6978dc6219d5dc029c9d453c6b8d503.diff";
      sha256 = "sha256-NknkH/gFTsMcdq8/ArwM4+qrpU+ZHd+xVMFUuMJTtf0=";
    })
    (fetchpatch {
      name = "CVE-2023-6693.patch";
      url = "https://gitlab.com/qemu-project/qemu/-/commit/2220e8189fb94068dbad333228659fbac819abb0.patch";
      sha256 = "sha256-uoFFFsVZ8XnsI2GD7xsRFNWghWL7/PSYTc1yhXI6nv4=";
    })
  ];

  configureFlags = [
    # Flags taken from the original nixpkgs expression
    "--disable-strip" # We'll strip ourselves after separating debug info.
    "--enable-tools"
    "--localstatedir=/var"
    "--sysconfdir=/etc"
    "--cross-prefix=${stdenv.cc.targetPrefix}"
    "--enable-linux-aio"

    # Flags taken from the instructions for the Espressif fork
    # Based on https://github.com/espressif/esp-toolchain-docs/blob/main/qemu/esp32/README.md
    # Based on https://github.com/espressif/esp-toolchain-docs/tree/main/qemu/esp32c3/README.md
    "--target-list=${lib.concatStringsSep "," targets}"
    "--enable-gcrypt"
    "--enable-slirp"
    "--enable-debug"
    # https://github.com/espressif/qemu/issues/77
    # https://github.com/espressif/qemu/issues/84
    # "--enable-sanitizers"
    "--enable-sdl"
    "--disable-strip"
    "--disable-user"
    "--disable-capstone"
    "--disable-vnc"
    "--disable-gtk"
  ];

  meta = oldAttrs.meta // {
    homepage = "https://github.com/espressif/qemu";
    mainProgram = if (!enableEsp32) then "qemu-system-riscv32" else "qemu-system-xtensa";
    maintainers = oldAttrs.meta.maintainers ++ [ lib.maintainers.sfrijters ];
  };
})

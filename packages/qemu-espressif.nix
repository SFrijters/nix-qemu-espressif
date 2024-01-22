{ lib
, stdenv
, fetchFromGitLab
, fetchFromGitHub
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
in

qemu.overrideAttrs (oldAttrs: rec {
  pname = "${oldAttrs.pname}-espressif";
  version = "8.1.3-20231206";

  src = fetchFromGitHub {
    owner = "espressif";
    repo = "qemu";
    rev = "refs/tags/esp-develop-${version}";
    sha256 = "sha256-9oC4xL/XRsttJ/qoUL32ZHkpYjQaDMLcm2FMw57svHg=";
  };

  buildInputs = oldAttrs.buildInputs ++ [ libgcrypt ];

  postPatch = oldAttrs.postPatch + ''
    # Correctly detect libgcrypt
    sed -i "s/config-tool/auto/" meson.build

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

  # This patch is for 8.2.0 and doesn't fit on the fork, which is still based on 8.1.3
  patches = builtins.filter (x: (x.name or "") != "9d5b42beb6978dc6219d5dc029c9d453c6b8d503.diff") oldAttrs.patches;

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
})

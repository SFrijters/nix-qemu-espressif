{
  lib,
  stdenv,
  fetchFromGitLab,
  fetchFromGitHub,
  fetchpatch,
  qemu,
  libgcrypt,
  enableEsp32 ? true,
  enableEsp32c3 ? true,
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
    lib.optionals enableEsp32 [ "xtensa-softmmu" ]
    ++ lib.optionals enableEsp32c3 [ "riscv32-softmmu" ];

  version = "9.0.0-20240606";
in

qemu.overrideAttrs (oldAttrs: {
  pname = "${oldAttrs.pname}-${
    if (enableEsp32 && !enableEsp32c3) then
      "esp32"
    else if (!enableEsp32 && enableEsp32c3) then
      "esp32c3"
    else
      "espressif"
  }";
  inherit version;

  src = fetchFromGitHub {
    owner = "espressif";
    repo = "qemu";
    rev = "refs/tags/esp-develop-${version}";
    hash = "sha256-6RX7wGv1Lkxw9ZlLDlQ/tlq/V8QbVzcb27NTr2uwePI=";
  };

  buildInputs = oldAttrs.buildInputs ++ [ libgcrypt ];

  postPatch =
    oldAttrs.postPatch
    + ''
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

  patches = oldAttrs.patches ++ [ ];

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

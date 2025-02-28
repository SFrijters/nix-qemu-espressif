{
  lib,
  stdenv,
  fetchFromGitLab,
  fetchFromGitHub,
  fetchpatch,
  versionCheckHook,
  qemu,
  glib,
  zlib,
  libgcrypt,
  libslirp,
  libaio,
  apple-sdk_13,
  darwinMinVersionHook,
  enableEsp32 ? true,
  enableEsp32c3 ? true,
}:

assert enableEsp32 || enableEsp32c3;

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

  targets =
    lib.optionals enableEsp32 [ "xtensa-softmmu" ]
    ++ lib.optionals enableEsp32c3 [ "riscv32-softmmu" ];

  version = "9.2.2-20250228";

  mainProgram = if (!enableEsp32) then "qemu-system-riscv32" else "qemu-system-xtensa";

  qemu' = qemu.override { minimal = true; };
in

qemu'.overrideAttrs (oldAttrs: {
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
    tag = "esp-develop-${version}";
    hash = "sha256-PQ0zGyIwtskrlNPXYYm7IIy8ID/VnWONjoNIDCCqNsE=";
  };

  buildInputs =
    [
      # dependencies declared in nixpkgs
      glib
      zlib
      libslirp
      # dependency from the espressif fork
      libgcrypt
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [ libaio ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      apple-sdk_13
      (darwinMinVersionHook "13")
    ];

  postPatch =
    oldAttrs.postPatch
    + ''
      # Prefetch Meson subprojects, after checking that the revision that we fetch matches the original
      grep -q "revision = ${keycodemapdb.rev}" subprojects/keycodemapdb.wrap
      rm subprojects/keycodemapdb.wrap
      ln -s ${keycodemapdb} subprojects/keycodemapdb

      grep -q "revision = ${berkeley-softfloat-3.rev}" subprojects/berkeley-softfloat-3.wrap
      rm subprojects/berkeley-softfloat-3.wrap
      cp -r ${berkeley-softfloat-3} subprojects/berkeley-softfloat-3
      chmod a+w subprojects/berkeley-softfloat-3
      cp subprojects/packagefiles/berkeley-softfloat-3/* subprojects/berkeley-softfloat-3

      grep -q "revision = ${berkeley-testfloat-3.rev}" subprojects/berkeley-testfloat-3.wrap
      rm subprojects/berkeley-testfloat-3.wrap
      cp -r ${berkeley-testfloat-3} subprojects/berkeley-testfloat-3
      chmod a+w subprojects/berkeley-testfloat-3
      cp subprojects/packagefiles/berkeley-testfloat-3/* subprojects/berkeley-testfloat-3

      # Overwrite the supplied version with the nixpkgs version with the date suffix
      echo ${version} > VERSION
    '';

  # Revert this change to libslirp detection, because it breaks the build
  patches = oldAttrs.patches or [] ++ [
    (fetchpatch {
      url = "https://github.com/espressif/qemu/commit/6f94694789dd4a632940def84eab067bd6880dc5.diff";
      hash = "sha256-wbT7E0xToPUyEX3rg9AKrbQx2E8SsLdOkdSBT4snwB0=";
      revert = true;
    })
  ];

  configureFlags =
    [
      # Flags taken from the original nixpkgs expression
      "--disable-strip" # We'll strip ourselves after separating debug info.
      "--enable-tools"
      "--localstatedir=/var"
      "--sysconfdir=/etc"
      "--cross-prefix=${stdenv.cc.targetPrefix}"

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
      "--disable-strip"
      "--disable-user"
      "--disable-capstone"
      "--disable-vnc"
      "--disable-gtk"
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      "--enable-linux-aio"
    ];

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;
  versionCheckProgram = "${builtins.placeholder "out"}/bin/${mainProgram}";

  meta = oldAttrs.meta // {
    inherit mainProgram;
    homepage = "https://github.com/espressif/qemu";
    maintainers = oldAttrs.meta.maintainers ++ [ lib.maintainers.sfrijters ];
  };
})

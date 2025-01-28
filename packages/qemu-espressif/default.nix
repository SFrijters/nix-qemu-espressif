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
  libslirp,
  libaio,
  SDL2,
  enableEsp32 ? true,
  enableEsp32c3 ? true,
  minimal ? false,
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

  version = "9.0.0-20240606";

  mainProgram = if (!enableEsp32) then "qemu-system-riscv32" else "qemu-system-xtensa";

  qemu' = qemu.override { inherit minimal; };
in

qemu'.overrideAttrs (oldAttrs: {
  pname = "${oldAttrs.pname}-${
    if (enableEsp32 && !enableEsp32c3) then
      "esp32"
    else if (!enableEsp32 && enableEsp32c3) then
      "esp32c3"
    else
      "espressif"
  }${lib.optionalString minimal "-minimal"}";
  inherit version;

  src = fetchFromGitHub {
    owner = "espressif";
    repo = "qemu";
    rev = "refs/tags/esp-develop-${version}";
    hash = "sha256-6RX7wGv1Lkxw9ZlLDlQ/tlq/V8QbVzcb27NTr2uwePI=";
  };

  buildInputs = if minimal then
    ([ glib zlib libgcrypt libslirp ] ++ lib.optionals stdenv.hostPlatform.isLinux [ libaio ])
      else
        (oldAttrs.buildInputs ++ [ libgcrypt ] ++ lib.optionals stdenv.hostPlatform.isDarwin [ SDL2 ]);

  postPatch =
    oldAttrs.postPatch
    + ''
      # Correctly detect libgcrypt
      substituteInPlace meson.build \
        --replace-fail config-tool pkg-config

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

  # This patch in currently locked nixpkgs is for 9.1.0 and doesn't fit on the fork, which is still based on 9.0.0
  # We use an older version of the patch.
  patches = (builtins.filter (x: builtins.baseNameOf x != "fix-qemu-ga.patch") oldAttrs.patches) ++ [
    ./fix-qemu-ga.patch
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
    ] ++ lib.optionals (!minimal) [
      "--enable-sdl" ]
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

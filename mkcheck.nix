{
  lib,
  stdenv,
  runCommand,
}:
pkg:
let
  # Variants of qemu with and without graphical support
  pkgsWithOverrides = {
    "default" = pkg;
    "guiSupport" = pkg.override {
      sdlSupport = true;
      gtkSupport = true;
      cocoaSupport = stdenv.hostPlatform.isDarwin;
    };
  };

  # Each variant has one or two relevant executables
  executableNamesPerVariant = {
    "qemu-espressif" = [
      "qemu-system-xtensa"
      "qemu-system-riscv32"
    ];
    "qemu-esp32" = [ "qemu-system-xtensa" ];
    "qemu-esp32c3" = [ "qemu-system-riscv32" ];
  };

  # And each of these possible executables supports one or two architectures
  archPerExecutableName = {
    "qemu-system-xtensa" = [
      "esp32"
      "esp32s3"
    ];
    "qemu-system-riscv32" = [ "esp32c3" ];
  };

  # Check that the version is correct (also checked in versionCheckHook, but a bit more cleanly
  mkCheckVersion =
    override: exeName:
    let
      exe = lib.getExe' pkgsWithOverrides.${override} exeName;
      version = pkgsWithOverrides.${override}.version;
    in
    ''
      echo "Checking version for ${override} ${exe}"
      ${exe} --version | grep '${version}' || (echo "ERROR: Did not find expected version ${version}"; exit 1)
    '';

  # Check that the version without graphical support indeed doesn't report graphical support
  # and check that the version with graphical support indeed reports graphical support
  mkCheckGraphics =
    override: exeName:
    let
      exe = lib.getExe' pkgsWithOverrides.${override} exeName;
    in
    ''
      echo "Checking graphics options"
    ''
    + (
      if (override == "guiSupport") then
        (
          ''
            ${exe} --display help | grep -e '^gtk' || (echo "ERROR: Did not find expected graphics option 'gtk'"; exit 1)
            ${exe} --display help | grep -e '^sdl' || (echo "ERROR: Did not find expected graphics option 'sdl'"; exit 1)
          ''
          + (lib.optionalString stdenv.hostPlatform.isDarwin) ''
            ${exe} --display help | grep -e '^cocoa' || (echo "ERROR: Did not find expected graphics option 'cocoa'"; exit 1)
          ''
        )
      else
        ''
          ! ${exe} --display help | grep -e '^[a-z]\\+$' | grep -v -e 'none\\|dbus' || (echo "ERROR: Found unexpected graphics option(s)"; exit 1)
        ''
    );

  # Check if all expected architectures are supported
  mkCheckArch =
    override: exeName:
    let
      exe = lib.getExe' pkgsWithOverrides.${override} exeName;
    in
    ''
      echo "Checking machine options"
    ''
    + (lib.concatMapStrings (arch: ''

      ${exe} --machine help | grep '^${arch} ' || (echo "ERROR: Did not find expected architecture '${arch}'"; exit 1)
    '') archPerExecutableName.${exeName});

  # Concatenate all these commands
  concatChecks = lib.concatMapStrings (
    override:
    lib.concatMapStrings (
      exeName:
      mkCheckVersion override exeName + mkCheckGraphics override exeName + mkCheckArch override exeName
    ) executableNamesPerVariant.${pkgsWithOverrides.${override}.pname}
  ) (lib.attrNames pkgsWithOverrides);
in
runCommand "check-${pkg.name}" { } ''
  ${concatChecks}
  mkdir "$out"
''

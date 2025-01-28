{
  description = "QEMU with ESP32 and/or ESP32C3 support, built from the Espressif fork";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs";

  outputs =
    {
      self,
      nixpkgs,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      forAllSystems =
        function:
        lib.genAttrs [
          "x86_64-linux"
          "aarch64-linux"
          "x86_64-darwin"
          "aarch64-darwin"
        ] (system: function nixpkgs.legacyPackages.${system});

      mkCheck =
        system: pkg:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          executablesPerVariant = {
            "qemu-espressif" = [
              "qemu-system-xtensa"
              "qemu-system-riscv32"
            ];
            "qemu-esp32" = [ "qemu-system-xtensa" ];
            "qemu-esp32c3" = [ "qemu-system-riscv32" ];
          };
          archPerExecutable = {
            "qemu-system-xtensa" = [
              "esp32"
              "esp32s3"
            ];
            "qemu-system-riscv32" = [ "esp32c3" ];
          };

          isMinimal = lib.strings.hasSuffix "-minimal" pkg.pname;
          pnameBase = lib.strings.removeSuffix "-minimal" pkg.pname;

          mkCheckVersion =
            exe: "echo ${lib.getExe' pkg exe}\n${lib.getExe' pkg exe} --version | grep '${pkg.version}'\n";
          mkCheckMinimal =
            exe:
            "${lib.optionalString isMinimal "!"} ${lib.getExe' pkg exe} --display help | grep -v -e 'Available\\|none\\|dbus'\n";
          mkCheckMachines =
            exe:
            lib.concatMapStrings (
              arch: "${lib.getExe' pkg exe} --machine help | grep '^${arch} '\n"
            ) archPerExecutable.${exe};
          concatChecks = exe: mkCheckVersion exe + mkCheckMinimal exe + mkCheckMachines exe;
        in
        pkgs.runCommand "check-${pkg.name}" { } ''
          echo ${pkg.pname}
          ${lib.concatMapStrings concatChecks executablesPerVariant.${pnameBase}}
          mkdir "$out"
        '';
    in
    {
      overlays.default = import ./.;

      packages = forAllSystems (pkgs: rec {
        default = qemu-espressif;
        qemu-espressif = pkgs.callPackage ./packages/qemu-espressif { };
        qemu-esp32 = pkgs.callPackage ./packages/qemu-espressif { enableEsp32c3 = false; };
        qemu-esp32c3 = pkgs.callPackage ./packages/qemu-espressif { enableEsp32 = false; };

        qemu-espressif-minimal = pkgs.callPackage ./packages/qemu-espressif { minimal = true; };
        qemu-esp32-minimal = pkgs.callPackage ./packages/qemu-espressif {
          enableEsp32c3 = false;
          minimal = true;
        };
        qemu-esp32c3-minimal = pkgs.callPackage ./packages/qemu-espressif {
          enableEsp32 = false;
          minimal = true;
        };
      });

      checks = lib.mapAttrs (
        system: perSystem:
        lib.mapAttrs (_: pkg: mkCheck system pkg) (lib.filterAttrs (n: _: n != "default") perSystem)
      ) self.packages;

      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
    };
}

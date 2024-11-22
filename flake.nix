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
      forAllSystems =
        function:
        nixpkgs.lib.genAttrs [
          "x86_64-linux"
          "aarch64-linux"
          "x86_64-darwin"
          "aarch64-darwin"
        ] (system: function nixpkgs.legacyPackages.${system});

      # For a given nixpkgs package set `pkgs`,
      # check that the mainProgram of the qemu package variant `variant` defined in this flake
      # supports the machine `machine`.
      mkCheck =
        pkgs: qemu-variant: machine:
        let
          p = self.packages.${pkgs.system}.${qemu-variant};
          exe = pkgs.lib.getExe p;
        in
        pkgs.runCommand "check-${p.name}" { } ''
          echo ${exe}
          ${exe} --version | grep "${p.version}"
          ${exe} --machine help | grep "^${machine} "
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
      });

      # Some simple sanity checks; for a full emulation check, see https://github.com/SFrijters/nix-qemu-esp32c3-rust-example
      checks = forAllSystems (pkgs: {
        qemu-espressif = mkCheck pkgs "qemu-espressif" "esp32";
        qemu-esp32 = mkCheck pkgs "qemu-esp32" "esp32";
        qemu-esp32c3 = mkCheck pkgs "qemu-esp32c3" "esp32c3";
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
    };
}

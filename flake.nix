{
  description = "QEMU with ESP32 and/or ESP32C3 support, built from the Espressif fork";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    {
      overlays.default = import ./.;
    } // flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in
      {
        packages = rec {
          default = qemu-espressif;
          qemu-espressif = pkgs.callPackage ./packages/qemu-espressif.nix { };
          qemu-esp32 = pkgs.callPackage ./packages/qemu-espressif.nix { enableEsp32c3 = false; };
          qemu-esp32c3 = pkgs.callPackage ./packages/qemu-espressif.nix { enableEsp32 = false; };
        };

        checks = let
          mkCheck = p: pkgs.stdenvNoCC.mkDerivation {
            name = "check-${p.name}";
            src = ./.;
            dontBuild = true;
            doCheck = true;
            checkPhase = ''
              ${pkgs.lib.getExe p} --version
            '';
            installPhase = ''
              mkdir "$out"
            '';
          };
        in
          {
            qemu-espressif = mkCheck self.packages.${system}.qemu-espressif;
            qemu-esp32 = mkCheck self.packages.${system}.qemu-esp32;
            qemu-esp32c3 = mkCheck self.packages.${system}.qemu-esp32c3;
          };
      }
    );
}

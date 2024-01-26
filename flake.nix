{
  description = "Qemu with ESP32 and ESP32C3 support, built from the Espressif fork";

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
      }
    );
}

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
    in
    {
      overlays.default = import ./.;

      packages = forAllSystems (
        pkgs:
        let
          withGui =
            pkg:
            pkg.override {
              sdlSupport = true;
              gtkSupport = true;
              cocoaSupport = pkgs.stdenv.isDarwin;
            };
        in
        rec {
          default = qemu-espressif;
          qemu-espressif = pkgs.callPackage ./packages/qemu-espressif { };
          qemu-esp32 = pkgs.callPackage ./packages/qemu-espressif { esp32c3Support = false; };
          qemu-esp32c3 = pkgs.callPackage ./packages/qemu-espressif { esp32Support = false; };
          qemu-espressif-gui = withGui qemu-espressif;
          qemu-esp32-gui = withGui qemu-esp32;
          qemu-esp32c3-gui = withGui qemu-esp32c3;
        }
      );

      # Some simple sanity checks; for a full emulation check, see https://github.com/SFrijters/nix-qemu-esp32c3-rust-example
      checks = forAllSystems (
        pkgs:
        let
          mkCheck = pkgs.callPackage ./mkcheck.nix { };
          packages = lib.filterAttrs (n: _: n != "default") (self.packages.${pkgs.stdenv.system});
        in
        lib.mapAttrs (_: pkg: mkCheck pkg) packages
      );

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);
    };
}

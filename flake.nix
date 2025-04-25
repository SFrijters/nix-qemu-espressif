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
      # Boilerplate to make the rest of the flake more readable
      # Do not inject system into these attributes
      flatAttrs = [
        "overlays"
        "nixosModules"
      ];
      # Inject a system attribute if the attribute is not one of the above
      injectSystem =
        system:
        lib.mapAttrs (name: value: if builtins.elem name flatAttrs then value else { ${system} = value; });
      # Combine the above for a list of 'systems'
      forSystems =
        systems: f:
        lib.attrsets.foldlAttrs (
          acc: system: value:
          lib.attrsets.recursiveUpdate acc (injectSystem system value)
        ) { } (lib.genAttrs systems f);
    in
    # Maybe other systems work as well, but they have not been tested
    forSystems
      [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ]
      (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          overlays.default = import ./.;

          packages =
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
            };

          # Some simple sanity checks; for a full emulation check, see https://github.com/SFrijters/nix-qemu-esp32c3-rust-example
          checks =
            let
              mkCheck = pkgs.callPackage ./mkcheck.nix { };
              packages = lib.filterAttrs (n: _: n != "default") (self.packages.${pkgs.stdenv.system});
            in
            lib.mapAttrs (_: pkg: mkCheck pkg) packages;

          formatter = pkgs.nixfmt-tree;
        }
      );
}

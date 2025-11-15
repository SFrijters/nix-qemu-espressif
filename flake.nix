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
        lib.mapAttrs (name: value: if lib.elem name flatAttrs then value else { ${system} = value; });
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
              importedPackagesViaOverlay = (import ./.) pkgs pkgs;
            in
            importedPackagesViaOverlay // { default = importedPackagesViaOverlay.qemu-espressif; };

          devShells =
            let
              mkShellWithPackage =
                pkg:
                pkgs.mkShellNoCC {
                  name = pkg.pname;
                  packages = [ pkg ];
                };
            in
            lib.mapAttrs (_: pkg: mkShellWithPackage pkg) self.packages.${system};

          # Some simple sanity checks; for a full emulation check, see https://github.com/SFrijters/nix-qemu-esp32c3-rust-example
          checks =
            let
              mkCheck = pkgs.callPackage ./mkcheck.nix { };
              nonDefaultPackages = lib.filterAttrs (n: _: n != "default") (self.packages.${system});
            in
            lib.mapAttrs (_: pkg: mkCheck pkg) nonDefaultPackages;

          formatter = pkgs.nixfmt-tree;
        }
      );
}

final: prev: {
  qemu-espressif = final.callPackage ./packages/qemu-espressif.nix { };
  qemu-esp32 = final.callPackage ./packages/qemu-espressif.nix { enableEsp32c3 = false; };
  qemu-esp32c3 = final.callPackage ./packages/qemu-espressif.nix { enableEsp32 = false; };
}

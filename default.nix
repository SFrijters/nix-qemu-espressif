final: prev: {
  qemu-espressif = final.callPackage ./packages/qemu-espressif { };
  qemu-esp32 = final.callPackage ./packages/qemu-espressif { enableEsp32c3 = false; };
  qemu-esp32c3 = final.callPackage ./packages/qemu-espressif { enableEsp32 = false; };
}

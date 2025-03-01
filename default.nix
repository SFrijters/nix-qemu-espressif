final: prev: {
  qemu-espressif = final.callPackage ./packages/qemu-espressif { };
  qemu-esp32 = final.callPackage ./packages/qemu-espressif { esp32c3Support = false; };
  qemu-esp32c3 = final.callPackage ./packages/qemu-espressif { esp32Support = false; };
}

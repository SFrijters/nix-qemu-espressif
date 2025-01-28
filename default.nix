final: prev: {
  qemu-espressif = final.callPackage ./packages/qemu-espressif { };
  qemu-esp32 = final.callPackage ./packages/qemu-espressif { enableEsp32c3 = false; };
  qemu-esp32c3 = final.callPackage ./packages/qemu-espressif { enableEsp32 = false; };

  qemu-espressif-minimal = final.callPackage ./packages/qemu-espressif { minimal = true; };
  qemu-esp32-minimal = final.callPackage ./packages/qemu-espressif {
    enableEsp32c3 = false;
    minimal = true;
  };
  qemu-esp32c3-minimal = final.callPackage ./packages/qemu-espressif {
    enableEsp32 = false;
    minimal = true;
  };
}

final: prev:
let
  withGui =
    pkg:
    pkg.override {
      sdlSupport = true;
      gtkSupport = true;
      cocoaSupport = final.stdenv.isDarwin;
    };
in
rec {
  qemu-espressif = final.callPackage ./packages/qemu-espressif { };
  qemu-esp32 = final.callPackage ./packages/qemu-espressif { esp32c3Support = false; };
  qemu-esp32c3 = final.callPackage ./packages/qemu-espressif { esp32Support = false; };
  qemu-espressif-gui = withGui qemu-espressif;
  qemu-esp32-gui = withGui qemu-esp32;
  qemu-esp32c3-gui = withGui qemu-esp32c3;
}

# nix-qemu-espressif

Packages a variant of the [qemu package in nixpkgs](https://github.com/NixOS/nixpkgs/blob/master/pkgs/applications/virtualization/qemu/default.nix) with support for ESP32/ESP32C3 chips, using [Espressif's fork of qemu](https://github.com/espressif/qemu). Current version: [8.2.0-20240122](https://github.com/espressif/qemu/releases/tag/esp-develop-8.2.0-20240122).

Exposed packages:

* qemu-espressif: Supports both [ESP32](https://github.com/espressif/esp-toolchain-docs/blob/main/qemu/esp32/README.md) (`"xtensa-softmmu"`) and [ESP32C3](https://github.com/espressif/esp-toolchain-docs/blob/main/qemu/esp32c3/README.md) (`"riscv32-softmmu"`) chips. Note: `nix run` will run `qemu-system-xtensa` by default.
* qemu-esp32: Supports only ESP32.
* qemu-esp32c3: Supports only ESP32C3.

The default output of this flake is a nixpkgs overlay that adds these packages.

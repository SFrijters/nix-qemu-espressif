# nix-qemu-espressif

Packages a variant of the [qemu package in nixpkgs](https://github.com/NixOS/nixpkgs/blob/master/pkgs/applications/virtualization/qemu/default.nix) with support for ESP32/ESP32C3 chips, using [Espressif's fork of qemu](https://github.com/espressif/qemu).

Exposed packages:

* qemu-espressif: Supports both ESP32 (`"xtensa-softmmu"`) and ESP32C3 (`"riscv32-softmmu"`) chips.
* qemu-esp32: Supports only ESP32.
* qemu-esp32c3: Supports only ESP32C3.

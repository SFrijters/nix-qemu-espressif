# nix-qemu-espressif

[![nix flake check](https://github.com/SFrijters/nix-qemu-espressif/actions/workflows/nix-flake-check.yml/badge.svg)](https://github.com/SFrijters/nix-qemu-espressif/actions/workflows/nix-flake-check.yml)

Packages a variant of the [qemu package in nixpkgs](https://github.com/NixOS/nixpkgs/blob/master/pkgs/applications/virtualization/qemu/default.nix) with support for ESP32/ESP32C3 chips, using [Espressif's fork of qemu](https://github.com/espressif/qemu). Current version: [9.0.0-20240606](https://github.com/espressif/qemu/releases/tag/esp-develop-9.0.0-20240606).

Exposed packages:

* qemu-espressif: Supports both [ESP32](https://github.com/espressif/esp-toolchain-docs/blob/main/qemu/esp32/README.md) (`"xtensa-softmmu"`) and [ESP32C3](https://github.com/espressif/esp-toolchain-docs/blob/main/qemu/esp32c3/README.md) (`"riscv32-softmmu"`) chips. Note: `nix run` will run `qemu-system-xtensa` by default.
* qemu-esp32: Supports only ESP32.
* qemu-esp32c3: Supports only ESP32C3.
* qemu-[espressif|esp32|esp32c3]-minimal: As above, but has minimal qemu features based on the minimal qemu version in nixpkgs and a smaller closure.

The default output of this flake is a nixpkgs overlay that adds these packages.

*Note*: this flake uses the internals of the nixpkgs derivation for qemu, so it is potentially rather fragile and it is not recommended to make the nixpkgs input of this flake follow another.

An example of usage can be found at https://github.com/SFrijters/nix-qemu-esp32c3-rust-example .

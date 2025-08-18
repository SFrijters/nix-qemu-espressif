# nix-qemu-espressif

[![GitHub CI](https://github.com/SFrijters/nix-qemu-espressif/actions/workflows/nix-flake-check.yml/badge.svg)](https://github.com/SFrijters/nix-qemu-espressif/actions/workflows/nix-flake-check.yml) [![GitLab CI](https://gitlab.com/SFrijters/nix-qemu-espressif/badges/master/pipeline.svg?key_text=GitLab+CI)](https://gitlab.com/SFrijters/nix-qemu-espressif/-/commits/master)

Packages a variant of the [qemu package in nixpkgs](https://github.com/NixOS/nixpkgs/blob/master/pkgs/applications/virtualization/qemu/default.nix) with support for ESP32/ESP32C3 chips, using [Espressif's fork of qemu](https://github.com/espressif/qemu). Current version: [9.2.2-20250817](https://github.com/espressif/qemu/releases/tag/esp-develop-9.2.2-20250817).

## Exposed packages

* `qemu-espressif`
  Supports both
  * [ESP32](https://github.com/espressif/esp-toolchain-docs/blob/main/qemu/esp32/README.md) and [ESP32S3](https://github.com/espressif/esp-toolchain-docs/blob/main/qemu/esp32s3/README.md)  (`"xtensa-softmmu"`) and
  * [ESP32C3](https://github.com/espressif/esp-toolchain-docs/blob/main/qemu/esp32c3/README.md) (`"riscv32-softmmu"`) chips.
  Note: `nix run` will run `qemu-system-xtensa` by default.
* `qemu-esp32`
  Supports only ESP32 / ESP32S3.
* `qemu-esp32c3`
  Supports only ESP32C3.
* `qemu-espressif-gui`, `qemu-esp32-gui`, `qemu-esp32c3-gui`
  As above, but with gui support enabled.

## Exposed options

* `sdlSupport` (default: `false`)
* `gtkSupport` (default: `false`)
* `cocoaSupport` (default: `false`, Darwin only)
* `enableTools` (default: `false`)
* `enableDebug` (default: `false`)
* `enableTests` (default: `true`)

These are passed as overrides, e.g. `qemu-espressif.override { sdlSupport = true; enableDebug = true; }`.

## Default output

The default output of this flake is a nixpkgs overlay that adds these packages.

## Addenda

*Note*: this flake uses the internals of the nixpkgs derivation for qemu, so it is potentially rather fragile and it is not recommended to make the nixpkgs input of this flake follow another.

An example of usage can be found at https://github.com/SFrijters/nix-qemu-esp32c3-rust-example .

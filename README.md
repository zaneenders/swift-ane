# swift-ane

## Build

From the repository root:

```sh
swift test --disable-xctest
./scripts/build.sh module
```

## Load and verify

Save your work first: experimental kernel code can crash Linux. Loading lasts until unload or reboot.

```sh
sudo insmod .build/kernel/swift_ane_probe.ko
sudo dmesg | grep -F 'swift_ane_probe' | tail -n 5
```

Success prints `Embedded Swift ABI verified; ANE hardware untouched`.

## Unload

```sh
sudo rmmod swift_ane_probe
```

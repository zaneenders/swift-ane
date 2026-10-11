/// Numeric identification only; this does not initialize or operate the ANE.
public enum ANEChip: UInt32 {
  case m1 = 0x8103
}

/// Version of the small C interface shared with the kernel bridge.
@c(swift_ane_abi_version)
public func aneModuleABIVersion() -> UInt32 {
  1
}

/// Returns one for the M1 chip ID, zero otherwise. Does not access hardware.
@c(swift_ane_is_m1_chip)
public func aneIsM1Chip(_ chipID: UInt32) -> Int32 {
  chipID == ANEChip.m1.rawValue ? 1 : 0
}

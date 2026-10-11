import ANECore
import Testing

@Test func moduleABIVersion() {
  #expect(aneModuleABIVersion() == 1)
}

@Test func recognizesM1() {
  #expect(ANEChip(rawValue: 0x8103) == .m1)
  #expect(aneIsM1Chip(0x8103) == 1)
}

@Test(arguments: [UInt32(0), 1, 0x8102, 0x8104, 0x8112, UInt32.max])
func rejectsOtherChipIDs(_ chipID: UInt32) {
  #expect(ANEChip(rawValue: chipID) == nil)
  #expect(aneIsM1Chip(chipID) == 0)
}

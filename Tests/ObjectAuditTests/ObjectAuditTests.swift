import Testing

@testable import ObjectAudit

private func check(
  header: String = "Type: REL (Relocatable file)\nMachine: AArch64",
  sections: String = ".text .note.GNU-stack",
  relocations: String = "R_AARCH64_JUMP26",
  undefined: String = "",
  defined: String = "swift_ane_abi_version\nswift_ane_is_m1_chip",
  disassembly: String = "       0: mov w0, #1\n       4: ret"
) -> [String] {
  ObjectAudit.check(
    header: header, sections: sections, relocations: relocations,
    undefined: undefined, defined: defined, disassembly: disassembly
  )
}

@Test func acceptsIntegerOnlyObject() {
  #expect(check().isEmpty)
}

@Test(arguments: ["malloc", "swift_retain", "__stack_chk_fail", "memset"])
func rejectsRuntimeDependencies(_ symbol: String) {
  #expect(
    check(undefined: symbol) == [
      "undefined symbols (no runtime dependencies allowed): " + symbol
    ])
}

@Test func requiresBothExports() {
  #expect(
    check(defined: "swift_ane_abi_version") == [
      "missing C ABI exports: swift_ane_is_m1_chip"
    ])
}

@Test(arguments: ["Type: DYN\nMachine: AArch64", "Type: REL\nMachine: X86-64"])
func rejectsWrongArchitectureOrType(_ header: String) {
  #expect(check(header: header) == ["expected an AArch64 ELF relocatable object"])
}

@Test(arguments: [
  "str q0, [sp]", "fmov d1, x0", "mov x18, x0", "mov w18, w0",
  "mrs x0, tpidr_el0", "str z0, [x0]", "ptrue p0.b", "mrs x0, fpcr"
])
func rejectsUnsafeRegisters(_ instruction: String) {
  #expect(
    check(disassembly: "0: " + instruction) == [
      "FP/SIMD/SVE, reserved x18, or TLS register use: " + instruction
    ])
}

@Test(arguments: [
  ".tdata", ".tbss", ".eh_frame", ".gcc_except_table", ".init_array", ".fini_array",
  ".got", ".plt", ".dynamic", ".dynsym"
])
func rejectsTLSUnwindAndInitializers(_ section: String) {
  #expect(
    check(sections: section) == [
      "TLS, unwind, dynamic-linking, or constructor sections found"
    ])
}

@Test(arguments: ["R_AARCH64_TLSLE_ADD_TPREL_LO12_NC", "R_AARCH64_ADR_GOT_PAGE", "R_AARCH64_PLT32"])
func rejectsUnsafeRelocations(_ relocation: String) {
  #expect(check(relocations: relocation) == ["TLS/GOT/PLT relocations found"])
}

@Test(arguments: [".swift1_autolink_entries", ".linker-options"])
func allowsOnlyEmptyAutolinkMetadata(_ name: String) {
  #expect(check(sections: "\(name) PROGBITS 000000 000040 000000").isEmpty)
  #expect(
    check(sections: "\(name) PROGBITS 000000 000040 000008") == [
      "nonempty autolinking metadata: " + name
    ])
}

@Test func rejectsAnyNonemptyAutolinkSection() {
  let sections = """
    .linker-options LLVM_LINKER_OPTIONS 000000 000040 000000
    .linker-options LLVM_LINKER_OPTIONS 000000 000040 000010
    """
  #expect(check(sections: sections) == ["nonempty autolinking metadata: .linker-options"])
}

@Test func requiresDisassembly() {
  #expect(check(disassembly: "") == ["no disassembled instructions found"])
}

@Test func acceptsWhitespaceAroundSymbolsAndDisassembly() {
  #expect(
    check(undefined: " \n\t", defined: "  swift_ane_abi_version\t swift_ane_is_m1_chip\n").isEmpty)
  #expect(
    check(disassembly: "object.o: file format elf64-littleaarch64\n0000 <entry>:\n  0: ret").isEmpty
  )
}

@Test func reportsAllFailures() {
  let errors = check(header: "", undefined: "malloc", defined: "", disassembly: "")
  #expect(errors.count == 4)
  #expect(errors.contains("missing C ABI exports: swift_ane_abi_version, swift_ane_is_m1_chip"))
}

@Test func readsLargeToolOutputWithoutDeadlock() throws {
  let text = String(repeating: "x", count: 100_000)
  #expect(try AuditCommand.output(tool: "printf", arguments: ["%s", text]) == text)
}

@Test func rejectsFailingTools() {
  #expect(throws: (any Error).self) {
    try AuditCommand.output(tool: "false", arguments: [])
  }
}

@Test func rejectsInvalidUTF8ToolOutput() {
  #expect(throws: (any Error).self) {
    try AuditCommand.output(tool: "printf", arguments: [#"\377"#])
  }
}

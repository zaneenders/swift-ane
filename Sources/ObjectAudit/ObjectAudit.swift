/// A narrow build gate for the Embedded Swift object, not a proof of kernel safety.
enum ObjectAudit {
  static let exports: Set<String> = ["swift_ane_abi_version", "swift_ane_is_m1_chip"]

  static func check(
    header: String,
    sections: String,
    relocations: String,
    undefined: String,
    defined: String,
    disassembly: String
  ) -> [String] {
    var errors: [String] = []
    if header.firstMatch(of: /Type:\s+REL\b/) == nil
      || header.firstMatch(of: /Machine:\s+AArch64\b/) == nil
    {
      errors.append("expected an AArch64 ELF relocatable object")
    }
    let undefinedSymbols = undefined.split(whereSeparator: \.isWhitespace).joined(separator: "\n")
    if !undefinedSymbols.isEmpty {
      errors.append("undefined symbols (no runtime dependencies allowed): " + undefinedSymbols)
    }
    let definedSymbols = Set(defined.split(whereSeparator: \.isWhitespace).map(String.init))
    let missing = exports.subtracting(definedSymbols).sorted()
    if !missing.isEmpty {
      errors.append("missing C ABI exports: " + missing.joined(separator: ", "))
    }
    if sections.firstMatch(
      of:
        /\.(?:tdata|tbss|eh_frame|gcc_except_table|init_array|fini_array|got|plt|dynamic|dynsym)\b/
    ) != nil {
      errors.append("TLS, unwind, dynamic-linking, or constructor sections found")
    }
    for match in sections.matches(
      of:
        /(\.swift1_autolink_entries|\.linker-options)\s+\S+\s+[0-9a-fA-F]+\s+[0-9a-fA-F]+\s+([0-9a-fA-F]+)\b/
    ) {
      if match.2.contains(where: { $0 != "0" }) {
        errors.append("nonempty autolinking metadata: " + match.1)
      }
    }
    if relocations.firstMatch(of: /R_AARCH64_\S*(?:TLS|GOT|PLT)/) != nil {
      errors.append("TLS/GOT/PLT relocations found")
    }
    let instructions = disassembly.split(whereSeparator: \.isNewline).compactMap { line in
      line.firstMatch(of: /^\s*[0-9a-f]+:\s+(.+)$/).map { String($0.1) }
    }
    if instructions.isEmpty {
      errors.append("no disassembled instructions found")
    }
    for instruction in instructions {
      if instruction.firstMatch(of: /\b(?:[bhsdqvzp][0-9]+|[wx]18|fpcr|fpsr|tpidr\w*)\b/) != nil {
        errors.append("FP/SIMD/SVE, reserved x18, or TLS register use: " + instruction)
      }
    }
    return errors
  }
}

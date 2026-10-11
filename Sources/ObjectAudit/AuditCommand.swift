import Foundation

@main
struct AuditCommand {
  static func main() {
    do {
      guard CommandLine.arguments.count == 2 else {
        throw Failure(description: "Usage: audit-object <embedded-swift.o>")
      }
      let path = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL.path
      let environment = ProcessInfo.processInfo.environment
      let readelf = environment["READELF"] ?? "readelf"
      let nm = environment["NM"] ?? "llvm-nm"
      let objdump = environment["OBJDUMP"] ?? "llvm-objdump"
      let errors = try ObjectAudit.check(
        header: output(tool: readelf, arguments: ["-h", path]),
        sections: output(tool: readelf, arguments: ["-SW", path]),
        relocations: output(tool: readelf, arguments: ["-rW", path]),
        undefined: output(
          tool: nm, arguments: ["--undefined-only", "--format=just-symbols", path]),
        defined: output(tool: nm, arguments: ["--defined-only", "--format=just-symbols", path]),
        disassembly: output(tool: objdump, arguments: ["-d", "--no-show-raw-insn", path])
      )
      guard errors.isEmpty else {
        throw Failure(description: "Object audit failed:\n- " + errors.joined(separator: "\n- "))
      }
      print("Object audit passed: AArch64, C exports, no undefined symbols, no FP/SIMD/x18/TLS")
    } catch {
      FileHandle.standardError.write(Data("\(error)\n".utf8))
      exit(1)
    }
  }

  static func output(tool: String, arguments: [String]) throws -> String {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [tool] + arguments
    var environment = ProcessInfo.processInfo.environment
    environment["LC_ALL"] = "C"
    process.environment = environment
    process.standardOutput = pipe
    process.standardError = FileHandle.standardError
    try process.run()
    // Drain while the tool runs so output larger than the pipe buffer cannot deadlock.
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationReason == .exit && process.terminationStatus == 0 else {
      throw Failure(description: "\(tool) failed (status \(process.terminationStatus))")
    }
    guard let text = String(data: data, encoding: .utf8) else {
      throw Failure(description: "\(tool) produced invalid UTF-8 output")
    }
    return text
  }

  private struct Failure: Error, CustomStringConvertible {
    let description: String
  }
}

// swift-tools-version: 6.4
import PackageDescription

#if !os(Linux)
#error("swift-ane requires a Linux host.")
#endif

let package = Package(
  name: "swift-ane",
  products: [
    .library(name: "ANECore", targets: ["ANECore"]),
    .executable(name: "audit-object", targets: ["ObjectAudit"])
  ],
  targets: [
    .target(name: "ANECore"),
    .testTarget(name: "ANECoreTests", dependencies: ["ANECore"]),
    .executableTarget(name: "ObjectAudit"),
    .testTarget(name: "ObjectAuditTests", dependencies: ["ObjectAudit"])
  ]
)

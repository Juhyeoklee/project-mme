#!/usr/bin/env swift
// 경계 검증기 — ADR 0001 결정 4가 닫아둔 3항목. 그 이상은 검사하지 않는다.
//
//   ① MomentKernel 소스의 import — 커널은 import 0이다. 의존 선언이 없는 패키지에서
//      컴파일이 통과하는 import는 시스템(플랫폼) 모듈뿐이므로, import가 보이면 곧 위반이다.
//      (교차 패키지 import는 컴파일러가 이미 막는다 — 여기서 다시 검사하지 않는다)
//   ② App 소스의 사진 프레임워크 직접 import
//   ③ PhotoSource 소스의 쓰기 심볼 — 금지 명단 방식. 오탐 쪽으로 기울였다:
//      오탐은 빨간불이 보여 그 자리에서 명단을 고치면 되지만, 미탐은 조용히 도구를 죽인다.
//      주석에 걸리는 것도 오탐으로 감수한다.
//
// 실행 — 로컬과 CI가 같은 명령이다 (ADR 0001 결정 4):
//   cd apple && swift scripts/verify-boundaries.swift

import Foundation

let appleRoot = URL(fileURLWithPath: CommandLine.arguments[0])
    .resolvingSymlinksInPath()
    .deletingLastPathComponent() // scripts/
    .deletingLastPathComponent() // apple/

struct Violation {
    let rule: String
    let file: String
    let line: Int
    let text: String
}

var violations: [Violation] = []

func swiftFiles(under relative: String) -> [URL] {
    let dir = appleRoot.appendingPathComponent(relative)
    guard let enumerator = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else {
        print("⚠️ 디렉터리 없음: \(relative) — 검사 대상이 사라졌다면 이 스크립트도 함께 고쳐야 한다")
        exit(2)
    }
    return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
}

func scan(_ relative: String, rule: String, violates: (String) -> Bool) {
    for file in swiftFiles(under: relative) {
        guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
        let lines = content.components(separatedBy: "\n")
        for (index, line) in lines.enumerated() where violates(line) {
            let path = file.path.replacingOccurrences(of: appleRoot.path + "/", with: "")
            violations.append(Violation(
                rule: rule, file: path, line: index + 1,
                text: line.trimmingCharacters(in: .whitespaces)
            ))
        }
    }
}

func isImportLine(_ line: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    if trimmed.hasPrefix("import ") { return true }
    // @testable import X · @preconcurrency import X
    if trimmed.hasPrefix("@"), trimmed.contains(" import ") { return true }
    return false
}

func importedModule(_ line: String) -> String? {
    guard isImportLine(line) else { return nil }
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard let range = trimmed.range(of: "import ") else { return nil }
    let tokens = trimmed[range.upperBound...].split(separator: " ")
    guard var module = tokens.first else { return nil }
    // `import struct Photos.PHAsset` 같은 종류 지정 import
    let kinds: Set<Substring> = ["struct", "class", "enum", "protocol", "typealias", "func", "var", "let"]
    if kinds.contains(module), tokens.count > 1 { module = tokens[1] }
    return module.split(separator: ".").first.map(String.init)
}

// ① 커널은 import 0
scan("Packages/MomentKernel/Sources", rule: "① 커널은 import 0 (ADR 0001 결정 2)") { line in
    isImportLine(line)
}

// ② App은 사진 프레임워크를 직접 import하지 않는다
let photoFrameworks: Set<String> = ["Photos", "PhotosUI"]
scan("App", rule: "② App은 사진 프레임워크 직접 import 금지 (ADR 0001 결정 2)") { line in
    guard let module = importedModule(line) else { return false }
    return photoFrameworks.contains(module)
}

// ③ 어댑터 내부의 쓰기 심볼 — 금지 명단
let writeSymbols = [
    "PHAssetChangeRequest",
    "PHAssetCollectionChangeRequest",
    "PHCollectionListChangeRequest",
    "PHAssetCreationRequest",
    "performChanges", // PHPhotoLibrary의 쓰기 트랜잭션 진입점
]
scan("Packages/PhotoSource/Sources", rule: "③ 어댑터에 쓰기 심볼 금지 (원칙 P5)") { line in
    writeSymbols.contains { line.contains($0) }
}

if violations.isEmpty {
    print("✅ 경계 검증 통과 — 3항목 위반 0")
    exit(0)
}

for v in violations {
    print("❌ \(v.rule)")
    print("   \(v.file):\(v.line)  \(v.text)")
}
print("\n경계 위반 \(violations.count)건")
exit(1)

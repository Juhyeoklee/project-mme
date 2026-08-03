// R8 프로브 화면 — 한시적. 화면 04·05·06이 들어오는 세션에서 R8Probe.swift와 함께 지운다.
// 디자인 토큰을 쓰지 않는다. 이건 계측기지 제품 화면이 아니다.

import SwiftUI
import UIKit

struct R8ProbeView: View {
    @State private var probe = R8Probe()
    @State private var scope = R8Probe.Scope.sample

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("권한 \(probe.access.description)")
                        .font(.footnote.monospaced())
                    Spacer()
                    if !probe.access.canRead {
                        Button("권한 요청") { probe.requestAccess() }
                    }
                }

                Picker("범위", selection: $scope) {
                    ForEach(R8Probe.Scope.allCases) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(probe.isRunning)

                HStack {
                    Button(probe.isRunning ? "실행 중…" : "프로브 실행") { probe.run(scope: scope) }
                        .buttonStyle(.borderedProminent)
                        .disabled(probe.isRunning)
                    if probe.isRunning {
                        Button("중단") { probe.cancel() }
                    }
                    Spacer()
                    Text(probe.progress).font(.footnote.monospaced()).foregroundStyle(.secondary)
                }

                Divider()

                ScrollView {
                    Text(probe.report.isEmpty ? "아직 결과가 없다." : probe.report)
                        .font(.system(size: 11).monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .navigationTitle("R8 프로브")
            .toolbar {
                if !probe.report.isEmpty {
                    ShareLink(item: probe.report)
                    Button("복사") { UIPasteboard.general.string = probe.report }
                }
            }
        }
    }
}

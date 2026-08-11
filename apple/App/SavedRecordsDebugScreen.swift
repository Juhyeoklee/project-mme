// ⚠️ **임시 화면이다.** `07` 기록 목록이 서면 지운다.
//
// 이 마일스톤의 첫 세션은 기록을 만들어 저장하는 데까지고 열람 화면이 없다. 그런데
// *"앱을 껐다 켜도 남아 있다"* 는 눈으로 봐야 닫히는 판정이라, 그 자리를 이것이 대신한다.

#if DEBUG
import SwiftUI

struct SavedRecordsDebugScreen: View {
    @State private var records: [Record] = []
    @State private var failure: String?

    @Environment(\.recordStore) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let failure {
                    Text(failure)
                } else if records.isEmpty {
                    Text(Wording.empty)
                }
                ForEach(records) { record in
                    row(record)
                }
            }
            .navigationTitle("저장된 기록 \(records.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Wording.acknowledge) { dismiss() }
                }
            }
        }
        .task { load() }
    }

    private func row(_ record: Record) -> some View {
        HStack(spacing: 12) {
            if let first = record.images.first {
                DiskImage(url: store.imageURL(recordID: record.id, image: first))
                    .frame(width: 56, height: 56)
                    .clipShape(.rect(cornerRadius: Radius.thumbnail))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(Wording.dateHeader(record.occurredAt.calendarDay))
                Text("\(record.images.count)장 · \(record.status.rawValue)")
                    .foregroundStyle(Palette.secondaryLabel)
                if !record.caption.isEmpty {
                    Text(record.caption).foregroundStyle(Palette.secondaryLabel)
                }
            }
        }
    }

    private func load() {
        do {
            records = try store.all()
            failure = nil
        } catch {
            failure = String(describing: error)
        }
    }
}

/// 저장된 바이트를 그대로 읽어 그린다 — **복사가 실제로 일어났는지가 여기서 드러난다.**
private struct DiskImage: View {
    let url: URL

    @State private var image: CGImage?

    var body: some View {
        PhotoTile(image: image, fills: true)
            .task(id: url) {
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return }
                image = CGImageSourceCreateImageAtIndex(source, 0, nil)
            }
    }
}
#endif

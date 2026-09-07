// 소스 후보를 내는 자리 (`SRC-02`). `AlbumPhotoSource`가 **정해진 하나**를 읽는다면
// 여기는 **무엇을 정할 수 있는가**를 답한다 — macOS 폴더 소스가 오면 둘이 같이 갈린다.

import Foundation
import Photos

/// 소스로 삼을 수 있는 앨범들.
public enum AlbumCatalog {
    /// 후보를 **사진 앱이 준 순서 그대로** 낸다. `previewLimit`은 후보마다 들고 올 사진 수.
    public static func candidates(previewLimit: Int) throws -> [SourceCandidate] {
        let access = AlbumPhotoSource.currentAccess()
        guard access.canRead else { throw PhotoSourceError.accessNotGranted(access) }

        // 사용자 앨범만 본다. 스마트 앨범(`최근 항목`·`스크린샷`)은 게임이 만든 것이 아니고,
        // 소스가 앨범 하나라는 `SRC-01`을 흐린다.
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any,
                                                                  options: nil)
        var result: [SourceCandidate] = []
        collections.enumerateObjects { collection, _, _ in
            result.append(candidate(in: collection, previewLimit: previewLimit))
        }
        return result
    }

    /// ⚠️ **빈 앨범도 후보다** — 거르는 판정은 이 층이 아니다.
    private static func candidate(in collection: PHAssetCollection,
                                  previewLimit: Int) -> SourceCandidate {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        let fetched = PHAsset.fetchAssets(in: collection, options: options)

        var preview: [SourceAsset] = []
        for index in 0..<min(previewLimit, fetched.count) {
            if let asset = fetched.object(at: index).sourceAsset { preview.append(asset) }
        }
        return SourceCandidate(id: collection.localIdentifier,
                               title: collection.localizedTitle ?? "",
                               count: fetched.count,
                               preview: preview)
    }
}

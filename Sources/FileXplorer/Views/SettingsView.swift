import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var bookmarkStore: BookmarkStore

    var body: some View {
        List {
            Section("연결된 폴더") {
                if bookmarkStore.bookmarks.isEmpty {
                    Text("연결된 외부 폴더가 없습니다")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(bookmarkStore.bookmarks) { bookmark in
                        Text(bookmark.displayName)
                    }
                }
            }
            Section("iOS 제약 안내") {
                Text("iOS 샌드박스 정책상 루트 파일시스템 접근, 시스템 기본 파일앱 지정, SMB 네트워크 드라이브, 서드파티 런처, 플러그인/스크립트 엔진은 지원되지 않습니다. 사용자가 직접 선택한 폴더와 FTP 서버에만 접근할 수 있습니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("설정")
    }
}

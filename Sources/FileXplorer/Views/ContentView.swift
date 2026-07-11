import SwiftUI

struct ContentView: View {
    @StateObject private var bookmarkStore = BookmarkStore.shared
    @State private var selection = ContentView.initialTab

    /// 테스트/스크린샷용: 실행 인자 `-startTab N`으로 시작 탭 지정.
    private static var initialTab: Int {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-startTab"), i + 1 < args.count, let n = Int(args[i + 1]) {
            return n
        }
        return 0
    }

    var body: some View {
        TabView(selection: $selection) {
            TabbedBrowserView(
                home: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            )
            .tabItem { Label("로컬", systemImage: "internaldrive") }
            .tag(0)

            NavigationStack {
                BookmarksListView()
            }
            .tabItem { Label("폴더 연결", systemImage: "folder.badge.plus") }
            .tag(1)

            NavigationStack {
                FTPBrowserView()
            }
            .tabItem { Label("FTP", systemImage: "network") }
            .tag(2)

            NavigationStack {
                VaultView()
            }
            .tabItem { Label("보관함", systemImage: "lock.rectangle.stack") }
            .tag(3)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("설정", systemImage: "gearshape") }
            .tag(4)
        }
        .environmentObject(bookmarkStore)
    }
}

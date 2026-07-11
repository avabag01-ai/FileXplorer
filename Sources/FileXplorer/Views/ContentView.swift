import SwiftUI

struct ContentView: View {
    @StateObject private var bookmarkStore = BookmarkStore.shared

    var body: some View {
        TabView {
            TabbedBrowserView(
                home: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            )
            .tabItem { Label("로컬", systemImage: "internaldrive") }

            NavigationStack {
                BookmarksListView()
            }
            .tabItem { Label("폴더 연결", systemImage: "folder.badge.plus") }

            NavigationStack {
                FTPBrowserView()
            }
            .tabItem { Label("FTP", systemImage: "network") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("설정", systemImage: "gearshape") }
        }
        .environmentObject(bookmarkStore)
    }
}

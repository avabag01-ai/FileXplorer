import Foundation

/// MiXplorer처럼 여러 폴더를 동시에 열어두기 위한 브라우저 탭 하나.
struct BrowserTab: Identifiable, Hashable {
    let id = UUID()
    var rootURL: URL
    var title: String
}

/// 열려 있는 탭 목록과 선택 상태를 관리한다.
/// 각 탭은 자체 NavigationStack을 가지므로 탭마다 독립적인 탐색 경로가 유지된다.
final class BrowserTabManager: ObservableObject {
    @Published var tabs: [BrowserTab]
    @Published var selectedID: UUID

    init(home: URL) {
        let first = BrowserTab(rootURL: home, title: "내 파일")
        tabs = [first]
        selectedID = first.id
    }

    func addTab(url: URL, title: String) {
        let tab = BrowserTab(rootURL: url, title: title)
        tabs.append(tab)
        selectedID = tab.id
    }

    func close(_ tab: BrowserTab) {
        // 마지막 탭은 닫지 않는다 (항상 최소 1개 유지).
        guard tabs.count > 1, let idx = tabs.firstIndex(of: tab) else { return }
        tabs.remove(at: idx)
        if selectedID == tab.id {
            // 닫힌 탭의 왼쪽(없으면 첫) 탭을 선택.
            selectedID = tabs[max(0, idx - 1)].id
        }
    }
}

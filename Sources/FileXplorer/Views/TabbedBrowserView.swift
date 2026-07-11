import SwiftUI

/// 상단 탭 스트립 + 선택된 탭의 파일 브라우저를 보여주는 컨테이너.
/// 폴더 행의 "새 탭에서 열기"로 MiXplorer처럼 여러 폴더를 동시에 열 수 있다.
struct TabbedBrowserView: View {
    @StateObject private var manager: BrowserTabManager

    init(home: URL) {
        _manager = StateObject(wrappedValue: BrowserTabManager(home: home))
    }

    private var home: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    var body: some View {
        VStack(spacing: 0) {
            tabStrip
            Divider()
            content
        }
    }

    // MARK: - 탭 스트립

    private var tabStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(manager.tabs) { tab in
                    tabChip(tab)
                }
                Button {
                    manager.addTab(url: home, title: "내 파일")
                } label: {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("새 탭")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }

    private func tabChip(_ tab: BrowserTab) -> some View {
        let isSelected = tab.id == manager.selectedID
        return HStack(spacing: 6) {
            Image(systemName: "folder")
                .font(.caption2)
            Text(tab.title)
                .lineLimit(1)
                .font(.subheadline)
            if manager.tabs.count > 1 {
                Button {
                    manager.close(tab)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1)
        )
        .foregroundStyle(isSelected ? Color.accentColor : .primary)
        .contentShape(Rectangle())
        .onTapGesture { manager.selectedID = tab.id }
    }

    // MARK: - 탭 내용

    // 각 탭의 NavigationStack을 살려두어 탐색 경로/스크롤이 보존되도록
    // ZStack + opacity로 표시 여부만 전환한다.
    private var content: some View {
        ZStack {
            ForEach(manager.tabs) { tab in
                NavigationStack {
                    FileBrowserView(
                        rootURL: tab.rootURL,
                        rootTitle: tab.title,
                        onOpenInNewTab: { url, title in
                            manager.addTab(url: url, title: title)
                        }
                    )
                }
                .opacity(tab.id == manager.selectedID ? 1 : 0)
                .allowsHitTesting(tab.id == manager.selectedID)
            }
        }
    }
}

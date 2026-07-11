import SwiftUI

/// MiXplorer의 메인 화면에 대응하는 파일 브라우저.
/// 폴더 이동, 다중 선택, 정렬, 검색, 복사/잘라내기/붙여넣기, 압축/해제, 새 폴더,
/// 텍스트 편집, 헥스 뷰어, QuickLook 미리보기를 지원한다.
struct FileBrowserView: View {
    let rootURL: URL
    let rootTitle: String
    /// 폴더를 새 탭에서 열기 위한 콜백. 탭 컨테이너 밖(단독 사용)에서는 nil.
    var onOpenInNewTab: ((URL, String) -> Void)? = nil

    @State private var currentURL: URL
    @State private var items: [FileItem] = []
    @State private var selection = Set<String>()
    @State private var isSelecting = false
    @State private var sortOption: SortOption = .name
    @State private var sortDirection: SortDirection = .ascending
    @State private var searchText = ""
    @State private var showingNewFolderAlert = false
    @State private var newFolderName = ""
    @State private var previewItem: FileItem?
    @State private var textEditItem: FileItem?
    @State private var hexViewItem: FileItem?
    @State private var errorMessage: String?
    @State private var pendingClipboard: (items: [FileItem], isCut: Bool)?

    init(rootURL: URL, rootTitle: String, onOpenInNewTab: ((URL, String) -> Void)? = nil) {
        self.rootURL = rootURL
        self.rootTitle = rootTitle
        self.onOpenInNewTab = onOpenInNewTab
        _currentURL = State(initialValue: rootURL)
    }

    private var filteredItems: [FileItem] {
        let base = searchText.isEmpty ? items : items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        return sortFileItems(base, by: sortOption, direction: sortDirection)
    }

    var body: some View {
        List(selection: $selection) {
            ForEach(filteredItems) { item in
                if item.isDirectory {
                    NavigationLink(value: item) {
                        FileRowView(item: item)
                    }
                    .contextMenu {
                        if let onOpenInNewTab {
                            Button {
                                onOpenInNewTab(item.url, item.name)
                            } label: {
                                Label("새 탭에서 열기", systemImage: "plus.square.on.square")
                            }
                        }
                    }
                } else {
                    FileRowView(item: item)
                        .onTapGesture { open(item) }
                }
            }
        }
        .environment(\.editMode, .constant(isSelecting ? .active : .inactive))
        .navigationDestination(for: FileItem.self) { item in
            FileBrowserView(rootURL: item.url, rootTitle: item.name, onOpenInNewTab: onOpenInNewTab)
        }
        .navigationTitle(rootTitle)
        .searchable(text: $searchText, prompt: "이 폴더에서 검색")
        .toolbar { toolbarContent }
        .onAppear(perform: reload)
        .alert("새 폴더", isPresented: $showingNewFolderAlert) {
            TextField("폴더 이름", text: $newFolderName)
            Button("취소", role: .cancel) {}
            Button("만들기") { createFolder() }
        }
        .alert("오류", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("확인") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(item: $previewItem) { item in
            QuickLookPreview(url: item.url)
        }
        .sheet(item: $textEditItem) { item in
            TextEditorSheet(item: item)
        }
        .sheet(item: $hexViewItem) { item in
            HexViewerView(item: item)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Menu {
                Picker("정렬 기준", selection: $sortOption) {
                    ForEach(SortOption.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                Button(sortDirection == .ascending ? "내림차순으로 바꾸기" : "오름차순으로 바꾸기") {
                    sortDirection = sortDirection == .ascending ? .descending : .ascending
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }

            Button {
                showingNewFolderAlert = true
            } label: {
                Image(systemName: "folder.badge.plus")
            }

            Button(isSelecting ? "완료" : "선택") {
                isSelecting.toggle()
                if !isSelecting { selection.removeAll() }
            }
        }

        if isSelecting && !selection.isEmpty {
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    pendingClipboard = (selectedItems, false)
                } label: {
                    Image(systemName: "doc.on.doc")
                }

                Button {
                    pendingClipboard = (selectedItems, true)
                } label: {
                    Image(systemName: "scissors")
                }

                Button {
                    pasteClipboard()
                } label: {
                    Image(systemName: "doc.on.clipboard")
                }
                .disabled(pendingClipboard == nil)

                Button {
                    compressSelection()
                } label: {
                    Image(systemName: "doc.zipper")
                }

                Button(role: .destructive) {
                    deleteSelection()
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
    }

    private var selectedItems: [FileItem] {
        items.filter { selection.contains($0.id) }
    }

    private func reload() {
        do {
            items = try FileService.contents(of: currentURL)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func open(_ item: FileItem) {
        switch item.kind {
        case .image, .video, .pdf, .audio:
            previewItem = item
        case .text:
            textEditItem = item
        case .archive:
            extractArchive(item)
        case .other, .folder:
            hexViewItem = item
        }
    }

    private func createFolder() {
        guard !newFolderName.isEmpty else { return }
        do {
            try FileService.createFolder(named: newFolderName, in: currentURL)
            newFolderName = ""
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteSelection() {
        do {
            try FileService.delete(selectedItems)
            selection.removeAll()
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func pasteClipboard() {
        guard let clipboard = pendingClipboard else { return }
        do {
            if clipboard.isCut {
                try FileService.move(clipboard.items, to: currentURL)
            } else {
                try FileService.copy(clipboard.items, to: currentURL)
            }
            pendingClipboard = nil
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func compressSelection() {
        let zipURL = currentURL.appendingPathComponent("Archive_\(Int(Date().timeIntervalSince1970)).zip")
        do {
            try ArchiveService.createZip(from: selectedItems, to: zipURL)
            selection.removeAll()
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func extractArchive(_ item: FileItem) {
        let destination = currentURL.appendingPathComponent(item.url.deletingPathExtension().lastPathComponent)
        do {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            try ArchiveService.extract(archive: item.url, to: destination)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

import SwiftUI
import LocalAuthentication

/// 영업/현장 사진 보관함. 기본 "사진" 앱과 분리된 샌드박스에만 저장되고,
/// 진입 시 Face ID(또는 기기 암호)로 잠긴다.
struct VaultView: View {
    private static let allTab = "전체"

    // UI 테스트/스크린샷 시 생체인증을 건너뛰기 위한 실행 인자(-uiTestUnlockVault).
    @State private var authed = ProcessInfo.processInfo.arguments.contains("-uiTestUnlockVault")
    @State private var authInProgress = false
    @State private var noAuthWarning = false

    @State private var categories: [String] = []
    @State private var selected = VaultView.allTab
    @State private var photos: [VaultPhoto] = []

    @State private var showCamera = false
    @State private var showImporter = false
    @State private var showNewCategory = false
    @State private var newCategoryName = ""
    @State private var detailPhoto: VaultPhoto?

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 4)]

    var body: some View {
        Group {
            if authed {
                gallery
            } else {
                lockScreen
            }
        }
        .onAppear { if authed { reload() } else { unlock() } }
    }

    // MARK: - 잠금 화면

    private var lockScreen: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 64)).foregroundStyle(.blue)
            Text("보관함이 잠겨 있습니다")
                .font(.title3.weight(.semibold))
            Text("Face ID로 잠금을 해제하세요")
                .font(.subheadline).foregroundStyle(.secondary)
            Button {
                unlock()
            } label: {
                Label("잠금 해제", systemImage: "faceid")
                    .padding(.horizontal, 20).padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .disabled(authInProgress)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func unlock() {
        authInProgress = true
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "기기 암호 사용"
        var error: NSError?
        if ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            ctx.evaluatePolicy(.deviceOwnerAuthentication,
                               localizedReason: "보관함의 사진을 보려면 인증이 필요합니다") { ok, _ in
                DispatchQueue.main.async {
                    authInProgress = false
                    if ok { authed = true; reload() }
                }
            }
        } else {
            // 생체인증·암호가 설정되지 않은 기기(예: 시뮬레이터)에서는
            // 잠금을 걸 수단이 없으므로 경고와 함께 접근을 허용한다.
            authInProgress = false
            authed = true
            noAuthWarning = true
            reload()
        }
    }

    // MARK: - 갤러리

    private var gallery: some View {
        VStack(spacing: 0) {
            if noAuthWarning { warningBanner }
            categoryStrip
            Divider()
            if photos.isEmpty {
                EmptyStateView(systemImage: "camera.on.rectangle",
                               title: "사진이 없습니다",
                               message: "오른쪽 위 카메라로 촬영하면 이 보관함에만 저장되고\n기본 '사진' 앱에는 나타나지 않습니다.")
            } else {
                grid
            }
        }
        .navigationTitle("보관함")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button { showNewCategory = true } label: { Image(systemName: "folder.badge.plus") }
                Button { showImporter = true } label: { Image(systemName: "photo.badge.plus") }
                Button { showCamera = true } label: { Image(systemName: "camera") }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(category: shootCategory) { reload() }
        }
        .sheet(isPresented: $showImporter) {
            PhotoPicker { data in
                _ = try? VaultService.saveJPEG(data, category: shootCategory, date: Date())
                reload()
            }
            .ignoresSafeArea()
        }
        .sheet(item: $detailPhoto) { photo in
            VaultPhotoDetail(photo: photo) { deleted in
                if deleted { reload() }
                detailPhoto = nil
            }
        }
        .alert("새 카테고리", isPresented: $showNewCategory) {
            TextField("예: 고객사A, 현장1", text: $newCategoryName)
            Button("취소", role: .cancel) { newCategoryName = "" }
            Button("만들기") {
                let name = newCategoryName
                newCategoryName = ""
                if let created = try? VaultService.createCategory(name) {
                    selected = created
                    reload()
                }
            }
        }
    }

    private var warningBanner: some View {
        Text("⚠️ 이 기기에 Face ID·암호가 설정돼 있지 않아 잠금이 비활성화됩니다.")
            .font(.caption).foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Color.orange.opacity(0.12))
    }

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip(Self.allTab)
                ForEach(categories, id: \.self) { chip($0) }
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
        }
    }

    private func chip(_ name: String) -> some View {
        let isSel = name == selected
        return Text(name)
            .font(.subheadline)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(isSel ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground)))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSel ? Color.accentColor : .clear, lineWidth: 1))
            .foregroundStyle(isSel ? Color.accentColor : .primary)
            .onTapGesture { selected = name; reload() }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(photos) { photo in
                    VaultThumbnail(photo: photo)
                        .onTapGesture { detailPhoto = photo }
                }
            }
            .padding(4)
        }
    }

    private var shootCategory: String {
        selected == Self.allTab ? VaultService.defaultCategory : selected
    }

    private func reload() {
        _ = try? VaultService.ensureRoot()
        categories = VaultService.categories()
        photos = selected == Self.allTab ? VaultService.allPhotos() : VaultService.photos(in: selected)
    }
}

/// 정사각 썸네일.
struct VaultThumbnail: View {
    let photo: VaultPhoto
    @State private var image: UIImage?

    var body: some View {
        Color(.secondarySystemBackground)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    ProgressView()
                }
            }
            .clipped()
            .task { if image == nil { image = await Self.load(photo.url) } }
    }

    static func load(_ url: URL) async -> UIImage? {
        await Task.detached(priority: .utility) {
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }.value
    }
}

/// 사진 상세 — 원본 보기, 내보내기(공유), 삭제.
struct VaultPhotoDetail: View {
    let photo: VaultPhoto
    var onClose: (_ deleted: Bool) -> Void

    @State private var image: UIImage?
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let image {
                    Image(uiImage: image).resizable().scaledToFit()
                } else {
                    ProgressView().tint(.white)
                }
            }
            .navigationTitle(photo.createdAt.formatted(date: .abbreviated, time: .shortened))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { onClose(false) }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    ShareLink(item: photo.url) { Image(systemName: "square.and.arrow.up") }
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .task { image = await VaultThumbnail.load(photo.url) }
            .confirmationDialog("이 사진을 삭제할까요?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("삭제", role: .destructive) {
                    try? VaultService.delete(photo)
                    onClose(true)
                }
                Button("취소", role: .cancel) {}
            }
        }
    }
}

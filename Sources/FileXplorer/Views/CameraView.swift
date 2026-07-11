import SwiftUI
import AVFoundation

/// 카메라 미리보기 레이어를 SwiftUI에 노출.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

/// 촬영 화면. 찍은 사진은 VaultService(샌드박스)로만 저장되며 Photos에는 저장되지 않는다.
struct CameraView: View {
    let category: String
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraModel()
    @State private var sampleCounter = 1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.isAvailable {
                CameraPreview(session: camera.session).ignoresSafeArea()
            } else {
                fallback
            }

            VStack {
                header
                Spacer()
                controls
            }
            .padding()
        }
        .onAppear {
            camera.onCapture = { data in save(data) }
            camera.start()
        }
        .onDisappear { camera.stop() }
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark").font(.title3.weight(.semibold))
            }
            Spacer()
            Label(category, systemImage: "folder")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .foregroundStyle(.white)
    }

    private var fallback: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 56)).foregroundStyle(.white.opacity(0.6))
            Text(camera.permissionDenied ? "카메라 권한이 없습니다" : "이 기기에서 카메라를 쓸 수 없어요")
                .foregroundStyle(.white)
            Text("시뮬레이터에서는 아래 버튼으로 샘플 사진을 추가해 흐름을 확인할 수 있습니다.")
                .font(.caption).foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center).padding(.horizontal, 40)
        }
    }

    private var controls: some View {
        Group {
            if camera.isAvailable {
                Button(action: camera.capture) {
                    Circle().strokeBorder(.white, lineWidth: 4)
                        .frame(width: 74, height: 74)
                        .overlay(Circle().fill(.white).frame(width: 60, height: 60))
                }
            } else {
                Button {
                    if let data = camera.makeSampleJPEG(label: "#\(sampleCounter)") {
                        sampleCounter += 1
                        save(data)
                    }
                } label: {
                    Label("샘플 사진 추가", systemImage: "plus.viewfinder")
                        .font(.headline).padding(.horizontal, 20).padding(.vertical, 12)
                        .background(.white, in: Capsule()).foregroundStyle(.black)
                }
            }
        }
        .padding(.bottom, 24)
    }

    private func save(_ data: Data) {
        do {
            _ = try VaultService.saveJPEG(data, category: category, date: Date())
            onSaved()
        } catch {
            camera.lastError = error.localizedDescription
        }
    }
}

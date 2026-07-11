import AVFoundation
import UIKit

/// 앱 내장 카메라. 촬영 결과 JPEG를 클로저로 전달하며, Photos 라이브러리에는 저장하지 않는다.
/// 시뮬레이터처럼 카메라가 없는 환경에서는 `isAvailable == false`가 되고,
/// UI가 폴백(샘플 추가)으로 전환된다.
final class CameraModel: NSObject, ObservableObject {
    @Published var isAvailable = false
    @Published var permissionDenied = false
    @Published var lastError: String?

    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "vault.camera.session")
    private var configured = false

    /// 촬영 완료 시 JPEG 데이터 전달.
    var onCapture: ((Data) -> Void)?

    // MARK: - 수명주기

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            guard granted else {
                DispatchQueue.main.async { self.permissionDenied = true; self.isAvailable = false }
                return
            }
            self.sessionQueue.async { self.configureIfNeeded(); self.startRunning() }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        defer { session.commitConfiguration() }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input), session.canAddOutput(output) else {
            DispatchQueue.main.async { self.isAvailable = false }
            return
        }
        session.addInput(input)
        session.addOutput(output)
        configured = true
        DispatchQueue.main.async { self.isAvailable = true }
    }

    private func startRunning() {
        guard configured, !session.isRunning else { return }
        session.startRunning()
    }

    // MARK: - 촬영

    func capture() {
        sessionQueue.async { [weak self] in
            guard let self, self.configured else { return }
            let settings = AVCapturePhotoSettings()
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }

    /// 카메라가 없는 환경(시뮬레이터)에서 흐름을 시연하기 위한 합성 이미지 생성.
    func makeSampleJPEG(label: String) -> Data? {
        let size = CGSize(width: 1200, height: 1600)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.systemIndigo.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let para = NSMutableParagraphStyle(); para.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.white,
                .font: UIFont.boldSystemFont(ofSize: 72),
                .paragraphStyle: para
            ]
            let text = "샘플 촬영\n\(label)"
            let rect = CGRect(x: 0, y: size.height/2 - 120, width: size.width, height: 240)
            (text as NSString).draw(in: rect, withAttributes: attrs)
        }
        return image.jpegData(compressionQuality: 0.8)
    }
}

extension CameraModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error {
            DispatchQueue.main.async { self.lastError = error.localizedDescription }
            return
        }
        guard let data = photo.fileDataRepresentation() else { return }
        DispatchQueue.main.async { self.onCapture?(data) }
    }
}

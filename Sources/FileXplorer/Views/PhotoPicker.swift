import SwiftUI
import PhotosUI

/// 기본 '사진' 앱에서 사진을 골라 앱으로 가져오는 피커.
///
/// PHPickerViewController는 앱과 분리된 프로세스에서 동작하므로
/// **사진 라이브러리 접근 권한(NSPhotoLibraryUsageDescription)이 필요 없다.**
/// 사용자가 명시적으로 고른 사진만 앱으로 전달된다.
struct PhotoPicker: UIViewControllerRepresentable {
    /// 고른 각 사진을 JPEG 데이터로 전달(비동기, 여러 장이면 여러 번 호출).
    var onPicked: (Data) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 0   // 0 = 무제한 다중 선택
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPicked: (Data) -> Void
        init(onPicked: @escaping (Data) -> Void) { self.onPicked = onPicked }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            for result in results {
                let provider = result.itemProvider
                guard provider.canLoadObject(ofClass: UIImage.self) else { continue }
                provider.loadObject(ofClass: UIImage.self) { [onPicked] object, _ in
                    guard let image = object as? UIImage,
                          let data = image.jpegData(compressionQuality: 0.9) else { return }
                    DispatchQueue.main.async { onPicked(data) }
                }
            }
        }
    }
}

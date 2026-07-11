# FileXplorer (MiXplorer 컨셉 iOS 클론)

MiXplorer 핵심 기능을 iOS 샌드박스 안에서 최대한 재현한 SwiftUI 앱 **소스코드**입니다.
이 세션에는 Xcode/macOS가 없어 실제 빌드·시뮬레이터 실행은 하지 못했습니다. 아래 순서대로 본인 Mac의 Xcode에서 열어 빌드해야 합니다.

## 빌드 방법

### 방법 A — XcodeGen 사용 (추천)
```bash
brew install xcodegen
cd FileXplorer
xcodegen generate
open FileXplorer.xcodeproj
```
Xcode가 열리면 Signing & Capabilities에서 본인 Apple ID 팀을 선택하고 실기기/시뮬레이터로 실행하세요.
`project.yml`에 ZIPFoundation SPM 의존성이 선언되어 있어 자동으로 받아옵니다.

### 방법 B — 수동으로 새 프로젝트 만들기
1. Xcode → New Project → iOS App → SwiftUI, 이름 `FileXplorer`
2. `Sources/FileXplorer` 안의 모든 `.swift` 파일과 `Info.plist`를 프로젝트에 드래그해서 추가
3. File → Add Package Dependencies → `https://github.com/weichsel/ZIPFoundation.git` 추가
4. Info.plist에 `UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace`를 `YES`로 설정 (파일 앱에서 이 앱 문서 폴더가 보이게 함)

## 구현된 기능 (MiXplorer 대응)

| MiXplorer 기능 | 이 앱에서 |
|---|---|
| 로컬 파일 탐색 | 앱 샌드박스(Documents) + 사용자가 연결한 외부 폴더 |
| 다중 선택 / 복사·잘라내기·붙여넣기·삭제 | 지원 |
| 압축(zip) 생성/해제 | 지원 (ZIPFoundation) |
| 정렬(이름/크기/날짜/종류) | 지원 |
| 폴더 내 검색 | 지원 |
| 이미지/동영상/오디오/PDF 미리보기 | QuickLook으로 지원 |
| 텍스트 편집기 | 지원 |
| 헥스 뷰어 | 지원 (앞 64KB 미리보기) |
| FTP 클라이언트 | 평문 FTP 패시브 모드로 지원 (목록/다운로드/업로드/삭제/폴더생성) |
| 탭 기반 다중 폴더 뷰 | 지원 — 상단 탭 스트립으로 여러 폴더 동시 열기, 폴더 길게 눌러 "새 탭에서 열기" |
| 사진 보관함 (차별화) | 내장 카메라로 촬영 → 앱 샌드박스에만 저장(기본 '사진' 앱 미노출) → 카테고리 분류 → Face ID 잠금 → 내보내기 |

## 사진 보관함 — 기본 '사진' 앱과 분리 보관

영업·현장 사진을 아이폰 기본 사진 라이브러리와 완전히 분리해 보관하는 기능.

- **저장 위치**: `Application Support/Vault/<카테고리>/` (앱 샌드박스). Photos 라이브러리에
  나타나지 않고, `UIFileSharingEnabled`(Documents만 노출)로도 보이지 않는다.
- **원리**: `VaultService`는 Photos 프레임워크(`PHPhotoLibrary` 등)를 **일절 사용하지 않는다.**
  내장 카메라(`AVCaptureSession`)로 찍은 JPEG를 곧바로 샌드박스에 기록하므로, 애초에
  기본 사진앱으로 유출될 경로 자체가 없다.
- **잠금**: 진입 시 `LocalAuthentication`(Face ID / 기기 암호)으로 잠긴다.
- **주의**: 샌드박스 사진은 iCloud 사진에 백업되지 않으므로 내보내기(공유)로 별도 보관 필요.
  이미 카메라롤에 있는 사진을 "그 자리에서" 숨기는 것은 iOS 공개 API로 불가능하다
  (가져오기 후 원본 삭제만 가능).

## iOS 정책상 100% 재현이 불가능한 것

- **루트/시스템 파일시스템 접근** — 안드로이드처럼 `/` 전체를 스캔하거나 다른 앱의 데이터 폴더를 보는 것은 iOS 앱 샌드박스 구조상 불가능. 사용자가 Files 피커로 명시적으로 선택한 폴더에만 접근 가능.
- **기본 파일 관리자로 지정** — iOS는 "기본 앱" 개념이 파일 매니저에는 없음.
- **SMB/네트워크 드라이브 마운트** — Apple이 공개 API로 제공하지 않음. Files 앱 자체의 "서버에 연결" 기능만 존재하며 서드파티가 동일하게 구현 불가.
- **FTPS/SFTP** — 이 프로젝트는 평문 FTP만 구현했음. TLS(FTPS)나 SSH(SFTP)를 붙이려면 별도 크립토 라이브러리(예: Citadel, SwiftNIO SSH)가 필요.
- **서드파티 런처 연동, 시스템 전역 파일 연결(아무 앱에서나 "다른 앱으로 열기"), 백그라운드 상시 파일 감시, 플러그인/스크립트 엔진** — iOS 앱 확장 모델상 미지원.

즉 "그대로"는 애초에 불가능하고, 이 프로젝트는 iOS 안에서 낼 수 있는 최대치의 기능 커버리지입니다.

## 알려진 제약 / TODO
- FTP 클라이언트는 최소 구현이라 대용량 파일 전송 진행률 표시, 재시도 로직은 없음
- 헥스 뷰어는 성능을 위해 파일 앞부분 64KB만 표시
- 압축은 zip만 지원 (rar/7z 등은 별도 라이브러리 필요, 라이선스 이슈로 제외)

## 테스트

`Tests/`에 XCTest 17개(FileService/ArchiveService/HexDump/FTPService). 실행:
```bash
xcodegen generate
xcodebuild -project FileXplorer.xcodeproj -scheme FileXplorer \
  -destination 'platform=iOS Simulator,name=iPhone 16' test
```
FTP 테스트는 로컬 FTP 서버가 없으면 자동으로 스킵된다. 서버를 띄우려면
`pip install pyftpdlib` 후 127.0.0.1:2121에 `tester/testpass` 계정으로 기동하면 된다.

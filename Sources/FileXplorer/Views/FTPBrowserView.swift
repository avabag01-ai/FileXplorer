import SwiftUI

struct FTPBrowserView: View {
    @StateObject private var ftp = FTPService()
    @State private var host = ""
    @State private var port = "21"
    @State private var username = "anonymous"
    @State private var password = ""
    @State private var isConnected = false
    @State private var currentPath = "/"
    @State private var entries: [FTPEntry] = []
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        Group {
            if isConnected {
                List(entries) { entry in
                    HStack {
                        Image(systemName: entry.isDirectory ? "folder.fill" : "doc")
                        Text(entry.name)
                        Spacer()
                        if !entry.isDirectory {
                            Text(ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if entry.isDirectory {
                            currentPath = currentPath.hasSuffix("/") ? currentPath + entry.name : currentPath + "/" + entry.name
                            Task { await loadList() }
                        }
                    }
                }
                .navigationTitle(currentPath)
                .toolbar {
                    Button("연결 해제") {
                        ftp.disconnect()
                        isConnected = false
                        entries = []
                        currentPath = "/"
                    }
                }
                .refreshable { await loadList() }
            } else {
                Form {
                    Section("FTP 서버 연결") {
                        TextField("호스트", text: $host)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("포트", text: $port)
                            .keyboardType(.numberPad)
                        TextField("사용자 이름", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("비밀번호", text: $password)
                    }
                    Section {
                        Button("연결") {
                            Task { await connect() }
                        }
                        .disabled(host.isEmpty || isLoading)
                    }
                    if let errorMessage {
                        Section {
                            Text(errorMessage).foregroundStyle(.red)
                        }
                    }
                }
                .navigationTitle("FTP")
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
    }

    private func connect() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let creds = FTPService.Credentials(host: host, port: UInt16(port) ?? 21, username: username, password: password)
            try await ftp.connect(creds)
            isConnected = true
            errorMessage = nil
            await loadList()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadList() async {
        isLoading = true
        defer { isLoading = false }
        do {
            entries = try await ftp.listDirectory(path: currentPath)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

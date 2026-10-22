import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: NoteViewModel
    let onClose: () -> Void

    @State private var token: String = ""
    @State private var serviceType: ServiceType = .yinxiangChina
    @State private var dockSide: DockSide = .right
    @State private var isPinned: Bool = false
    @State private var isTesting: Bool = false
    @State private var testResult: String? = nil
    @State private var isSuccess: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("偏好设置")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // 1. Evernote / Yinxiang Section
                    VStack(alignment: .leading, spacing: 8) {
                        Label("印象笔记 / Evernote 接入", systemImage: "cloud.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)

                        // Service Type Picker
                        Picker("服务类型", selection: $serviceType) {
                            ForEach(ServiceType.allCases, id: \.self) { type in
                                Text(type.title).tag(type)
                            }
                        }
                        .pickerStyle(RadioGroupPickerStyle())
                        .font(.system(size: 11))

                        // Token input
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Developer Token (开发者令牌):")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            TextField("粘贴您的 Developer Token", text: $token)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 11, design: .monospaced))

                            HStack {
                                Button("获取国内版 Token ↗") {
                                    if let url = URL(string: "https://app.yinxiang.com/api/DeveloperToken.action") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                                .font(.system(size: 10))
                                .buttonStyle(LinkButtonStyle())

                                Text("•")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)

                                Button("获取国际版 Token ↗") {
                                    if let url = URL(string: "https://www.evernote.com/api/DeveloperToken.action") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                                .font(.system(size: 10))
                                .buttonStyle(LinkButtonStyle())

                                Spacer()

                                Button(action: testConnection) {
                                    if isTesting {
                                        ProgressView().scaleEffect(0.6)
                                    } else {
                                        Text("测试连接")
                                            .font(.system(size: 11))
                                    }
                                }
                                .disabled(token.isEmpty || isTesting)
                            }
                            .padding(.top, 2)

                            if let res = testResult {
                                Text(res)
                                    .font(.system(size: 11))
                                    .foregroundColor(isSuccess ? .green : .red)
                                    .padding(.top, 2)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)

                    // 2. Docking & Window Section
                    VStack(alignment: .leading, spacing: 10) {
                        Label("屏幕停靠与窗口行为", systemImage: "sidebar.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)

                        Picker("停靠位置:", selection: $dockSide) {
                            ForEach(DockSide.allCases, id: \.self) { side in
                                Text(side.title).tag(side)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())

                        Toggle("窗口始终置顶 (Pin 模式)", isOn: $isPinned)
                            .font(.system(size: 11))
                        Text("开启后点击其他软件窗口不会自动收起；关闭后失去焦点时自动滑入屏幕边缘。")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)

                    // 3. Shortcuts hint
                    VStack(alignment: .leading, spacing: 6) {
                        Label("使用快捷方式", systemImage: "keyboard")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)

                        HStack {
                            Text("点击菜单栏图标:")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("一键唤出 / 隐藏")
                                .font(.system(size: 11, weight: .medium))
                        }
                        HStack {
                            Text("右键菜单栏图标:")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("快捷新建 / 立即同步")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                }
                .padding(16)
            }

            Divider()

            // Bottom Actions
            HStack {
                Spacer()
                Button("完成") {
                    saveSettings()
                    onClose()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 340, height: 480)
        .onAppear {
            self.token = viewModel.settings.evernoteToken
            self.serviceType = viewModel.settings.serviceType
            self.dockSide = viewModel.settings.dockSide
            self.isPinned = viewModel.settings.isPinned
        }
    }

    private func testConnection() {
        guard !token.isEmpty else { return }
        isTesting = true
        testResult = nil

        Task {
            do {
                let username = try await YinxiangSyncEngine.shared.testConnection(
                    token: token,
                    china: serviceType.isChina
                )
                await MainActor.run {
                    self.isTesting = false
                    self.isSuccess = true
                    self.testResult = "✅ 验证通过，欢迎 \(username)"
                }
            } catch {
                await MainActor.run {
                    self.isTesting = false
                    self.isSuccess = false
                    self.testResult = "❌ \(error.localizedDescription)"
                }
            }
        }
    }

    private func saveSettings() {
        var s = viewModel.settings
        s.evernoteToken = token
        s.serviceType = serviceType
        s.dockSide = dockSide
        s.isPinned = isPinned

        viewModel.saveSettings(s)
        WindowManager.shared.setDockSide(dockSide)
        WindowManager.shared.setPinned(isPinned)

        if !token.isEmpty {
            viewModel.syncWithYinxiang()
        }
    }
}

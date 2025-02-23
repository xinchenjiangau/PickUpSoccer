import SwiftUI
import PhotosUI
import SwiftData

struct UserPlayerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    // 表单字段
    @State private var name: String = ""
    @State private var number: String = ""
    @State private var position: PlayerPosition = .forward
    @State private var selectedItem: PhotosPickerItem?
    @State private var profileImage: Image?
    @State private var gender: String = ""
    @State private var height: String = ""
    @State private var weight: String = ""
    
    // Alert 提示
    @State private var showMergeAlert = false
    @State private var duplicatePlayers: [Player] = []
    @State private var showError = false
    @State private var errorMessage = ""
    
    var player: Player? {
        authManager.currentPlayer
    }
    
    var body: some View {
        NavigationView {
            content
                .navigationTitle("完善球员资料")
                .toolbar {
                    toolbarItems
                }
                .alert("发现重复的球员名称", isPresented: $showMergeAlert) {
                    alertButtons
                } message: {
                    Text("已有其他球员使用相同名称，是否合并数据？")
                }
                .alert("错误", isPresented: $showError) {
                    Button("确定", role: .cancel) { }
                } message: {
                    Text(errorMessage)
                }
        }
    }
    
    // MARK: - 子视图
    
    @ViewBuilder
    private var content: some View {
        Form {
            basicInfoSection
            avatarSection
        }
        .onAppear {
            loadPlayerData()
        }
        .onChange(of: selectedItem) { _, newItem in
            handleImageSelection(newItem)
        }
    }
    
    @ViewBuilder
    private var basicInfoSection: some View {
        Section(header: Text("基本信息")) {
            TextField("姓名", text: $name)
            TextField("号码", text: $number)
                .keyboardType(.numberPad)
            positionPicker
            TextField("性别", text: $gender)
            TextField("身高", text: $height)
                .keyboardType(.decimalPad)
            TextField("体重", text: $weight)
                .keyboardType(.decimalPad)
        }
    }
    
    @ViewBuilder
    private var positionPicker: some View {
        Picker("位置", selection: $position) {
            ForEach(PlayerPosition.allCases, id: \.self) { position in
                Text(position.rawValue).tag(position)
            }
        }
    }
    
    @ViewBuilder
    private var avatarSection: some View {
        Section(header: Text("头像")) {
            HStack {
                Spacer()
                PhotosPicker(selection: $selectedItem) {
                    avatarImage
                }
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private var avatarImage: some View {
        if let image = profileImage {
            image
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .foregroundColor(.gray)
        }
    }
    
    @ViewBuilder
    private var alertButtons: some View {
        Button("合并") {
            mergeWithDuplicatePlayers()
        }
        Button("使用新名称", role: .destructive) {
            savePlayerInfo(merge: false)
        }
        Button("取消", role: .cancel) { }
    }
    
    // MARK: - 辅助方法
    
    private func loadPlayerData() {
        if let player = player {
            name = player.name
            number = player.number.map(String.init) ?? ""
            position = player.position
            gender = player.gender ?? ""
            height = player.height.map { String(format: "%.1f", $0) } ?? ""
            weight = player.weight.map { String(format: "%.1f", $0) } ?? ""
        }
    }
    
    private func handleImageSelection(_ newItem: PhotosPickerItem?) {
        Task {
            if let data = try? await newItem?.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                profileImage = Image(uiImage: uiImage)
                if let url = try await saveImageLocally(uiImage) {
                    player?.profilePicture = url
                }
            }
        }
    }
    
    private func checkForDuplicateAndSave() {
        guard let currentPlayerID = player?.id else {
            // 如果没有当前用户，直接保存
            return savePlayerInfo(merge: false)
        }
        let currentName = self.name

        do {
            // 不带谓词，获取所有玩家
            let allPlayers = try modelContext.fetch(FetchDescriptor<Player>())
            
            // 在内存中手动过滤
            let results = allPlayers.filter {
                $0.name == currentName && $0.id != currentPlayerID
            }
            
            if !results.isEmpty {
                duplicatePlayers = results
                showMergeAlert = true
            } else {
                savePlayerInfo(merge: false)
            }
        } catch {
            errorMessage = "查询重复名称失败: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func savePlayerInfo(merge: Bool) {
        guard let player = player else { return }
        
        player.name = name
        if let numberInt = Int(number) {
            player.number = numberInt
        }
        player.position = position
        player.gender = gender
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        
        if let heightDouble = Double(height.replacingOccurrences(of: ",", with: ".")) {
            player.height = heightDouble
        }
        if let weightDouble = Double(weight.replacingOccurrences(of: ",", with: ".")) {
            player.weight = weightDouble
        }
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "保存失败: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func mergeWithDuplicatePlayers() {
        guard let current = player else { return }
        
        for duplicate in duplicatePlayers {
            // 将重复球员的所有比赛统计转移到当前球员
            for stats in duplicate.matchStats {
                stats.player = current  // 更改统计数据的所属球员
                current.matchStats.append(stats)  // 添加到当前球员的统计数组中
            }
            modelContext.delete(duplicate)  // 删除重复的球员
        }
        
        savePlayerInfo(merge: true)
    }
    
    private func saveImageLocally(_ image: UIImage) async throws -> URL? {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return nil }
        
        let filename = "\(UUID().uuidString).jpg"
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        
        try data.write(to: fileURL)
        return fileURL
    }
    
    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("取消") {
                dismiss()
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("完成") {
                checkForDuplicateAndSave()
            }
            .disabled(name.isEmpty || number.isEmpty)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Player.self, configurations: config)
    
    return UserPlayerView()
        .modelContainer(container)
} 
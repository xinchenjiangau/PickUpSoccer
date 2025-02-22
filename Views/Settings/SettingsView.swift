import SwiftUI
import PhotosUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authManager: AuthManager
    @State private var showEditSheet = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var profileImage: Image?
    
    // 用户设置数据
    @State private var gender = "男"
    @State private var height = "170"
    @State private var weight = "70"
    @State private var preferredFoot = "右脚"
    @State private var boots = "猎鹰系列"
    @State private var playerNumber = "10" // 球员号码
    
    private let genderOptions = ["男", "女"]
    private let footOptions = ["左脚", "右脚"]
    private let heightRange = Array(150...200).map { String($0) }
    private let weightRange = Array(50...100).map { String($0) }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 头像和基本信息区域
                    profileSection
                    
                    // 常用设置区域
                    commonSettingsSection
                    
                    // 其他区域
                    otherSection
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .sheet(isPresented: $showEditSheet) {
                editProfileView
            }
            .onChange(of: selectedItem) { _, newItem in
                handleImageSelection(newItem)
            }
        }
    }
    
    // MARK: - 头像和基本信息区域
    private var profileSection: some View {
        VStack(spacing: 10) {
            PhotosPicker(selection: $selectedItem) {
                if let profileImage {
                    profileImage
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.gray)
                }
            }
            
            Text(authManager.currentPlayer?.name ?? "昵称")
                .font(.title2)
            
            Text("ID: \(authManager.currentPlayer?.id.uuidString.prefix(8) ?? "")")
                .font(.caption)
                .foregroundColor(.gray)
            
            Button("编辑") {
                showEditSheet = true
            }
            .font(.subheadline)
        }
    }
    
    // MARK: - 常用设置区域
    private var commonSettingsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("常用设置")
                .font(.headline)
                .foregroundColor(.gray)
            
            settingRow("性别", value: $gender, options: genderOptions)
            settingRow("身高", value: $height, options: heightRange, unit: "cm")
            settingRow("体重", value: $weight, options: weightRange, unit: "kg")
            settingRow("惯用脚", value: $preferredFoot, options: footOptions)
            settingRow("位置", text: authManager.currentPlayer?.position.rawValue ?? "")
            settingRow("球鞋", value: $boots, options: [])
            settingRow("球员号码", value: $playerNumber, options: [])
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    // MARK: - 其他区域
    private var otherSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("其他")
                .font(.headline)
                .foregroundColor(.gray)
            
            NavigationLink("帮助") {
                Text("帮助内容")
            }
            
            NavigationLink("球员列表与数据") {
                PlayerListView()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    // MARK: - 辅助视图
    private func settingRow(_ title: String, value: Binding<String>, options: [String], unit: String = "") -> some View {
        HStack {
            Text(title)
                .font(.body)
            Spacer()
            Picker("", selection: value) {
                ForEach(options, id: \.self) { option in
                    Text("\(option)\(unit)").tag(option)
                }
            }
            .pickerStyle(.menu)
        }
    }
    
    private func settingRow(_ title: String, text: String) -> some View {
        HStack {
            Text(title)
                .font(.body)
            Spacer()
            Text(text)
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - 编辑个人资料视图
    private var editProfileView: some View {
        NavigationView {
            Form {
                Section {
                    TextField("昵称", text: .constant(authManager.currentPlayer?.name ?? ""))
                    TextField("球鞋", text: $boots)
                    TextField("球员号码", text: $playerNumber)
                    // 其他可编辑字段...
                }
            }
            .navigationTitle("编辑资料")
            .navigationBarItems(
                leading: Button("取消") {
                    showEditSheet = false
                },
                trailing: Button("保存") {
                    // 保存逻辑
                    if let player = authManager.currentPlayer {
                        player.name = "新昵称" // 更新昵称
                        player.boots = boots // 更新球鞋
                        player.number = Int(playerNumber) ?? 0 // 更新球员号码
                        try? modelContext.save() // 持久化保存
                    }
                    showEditSheet = false
                }
            )
        }
    }
    
    // MARK: - 辅助方法
    private func handleImageSelection(_ newItem: PhotosPickerItem?) {
        Task {
            if let data = try? await newItem?.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                profileImage = Image(uiImage: uiImage)
                if let url = try await saveImageLocally(uiImage) {
                    authManager.currentPlayer?.profilePicture = url
                    try? modelContext.save()
                }
            }
        }
    }
    
    private func saveImageLocally(_ image: UIImage) async throws -> URL? {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return nil }
        
        let filename = "\(UUID().uuidString).jpg"
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        
        try data.write(to: fileURL)
        return fileURL
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: Player.self, inMemory: true)
} 
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct PlayerListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Player.number) private var players: [Player]
    @State private var showingAddPlayer = false
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    @State private var csvString: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        List {
            ForEach(players) { player in
                HStack {
                    Text("\(player.number ?? 0)")
                        .frame(width: 30)
                        .foregroundColor(.secondary)
                    Text(player.name)
                    Spacer()
                    Text(player.position.rawValue)
                        .foregroundColor(.secondary)
                }
            }
            .onDelete(perform: deletePlayers)
        }
        .navigationTitle("球员名单")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: { showingAddPlayer = true }) {
                        Label("添加球员", systemImage: "person.badge.plus")
                    }
                    
                    Button(action: exportPlayerData) {
                        Label("导出数据", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: { showingImportSheet = true }) {
                        Label("导入数据", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddPlayer) {
            AddPlayerView(isPresented: $showingAddPlayer)
        }
        .fileExporter(
            isPresented: $showingExportSheet,
            document: CSVFile(initialText: csvString),
            contentType: .commaSeparatedText,
            defaultFilename: "球员列表_\(formattedDate).csv"
        ) { result in
            switch result {
            case .success(let url):
                print("成功导出到: \(url)")
            case .failure(let error):
                print("导出失败: \(error.localizedDescription)")
            }
        }
        .fileImporter(
            isPresented: $showingImportSheet,
            allowedContentTypes: [.commaSeparatedText]
        ) { result in
            switch result {
            case .success(let url):
                importCSV(from: url)
            case .failure(let error):
                errorMessage = "导入失败: \(error.localizedDescription)"
                showError = true
            }
        }
        .alert("错误", isPresented: $showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
    
    private func deletePlayers(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(players[index])
            }
        }
    }
    
    private func exportPlayerData() {
        csvString = CSVExporter.exportPlayers(players)
        showingExportSheet = true
    }
    
    private func importCSV(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "无法访问选择的文件"
            showError = true
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        do {
            let data = try Data(contentsOf: url)
            guard let content = String(data: data, encoding: .utf8) else {
                throw CSVImporter.ImportError.invalidData
            }
            
            try CSVImporter.importPlayers(from: content, modelContext: modelContext)
        } catch let error as CSVImporter.ImportError {
            errorMessage = error.localizedDescription
            showError = true
        } catch {
            errorMessage = "导入失败: \(error.localizedDescription)"
            showError = true
        }
    }
}

// 用于文件导出的文档类型
struct CSVFile: FileDocument {
    static var readableContentTypes = [UTType.commaSeparatedText]
    
    var text: String
    
    init(initialText: String = "") {
        self.text = initialText
    }
    
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(decoding: data, as: UTF8.self)
        } else {
            text = ""
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let bomString = "\u{FEFF}"
        let fullText = bomString + text
        guard let data = fullText.data(using: .utf8) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return .init(regularFileWithContents: data)
    }
}

#Preview {
    PlayerListView()
        .modelContainer(for: Player.self, inMemory: true)
} 
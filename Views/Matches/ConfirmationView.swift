import SwiftUI

struct ConfirmationView: View {
    let recognizedText: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("识别到的内容")
                .font(.headline)
            Text(recognizedText)
                .font(.body)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

            HStack {
                Button("取消") {
                    onCancel()
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)

                Button("确认") {
                    onConfirm()
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
    }
} 
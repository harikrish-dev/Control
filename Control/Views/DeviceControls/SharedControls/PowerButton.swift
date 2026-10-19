import SwiftUI

struct PowerButton: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button {
            HapticFeedback.click()
            action()
        } label: {
            Image(systemName: "power")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(isOn ? .white : .secondary)
                .frame(width: 36, height: 36)
                .background(isOn ? Color.accentColor : Color.secondary.opacity(0.15))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}

import SwiftUI

@main
struct DevServersApp: App {
    @StateObject private var store = ServerStore()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}

/// 메뉴바 라벨. 컬러 아이콘은 템플릿이 아니라 메뉴바 밝기를 직접 따라가야 하므로 colorScheme 을 넘긴다.
struct MenuBarLabel: View {
    @ObservedObject var store: ServerStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 3) {
            Image(nsImage: RackIcon.image(store.iconFrame, isDark: colorScheme == .dark))
                .renderingMode(.original)
            Text("\(store.servers.count)")
        }
    }
}

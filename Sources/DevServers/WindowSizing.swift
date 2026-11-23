import AppKit
import SwiftUI

/// SwiftUI 뷰가 올라간 NSWindow 를 얻는다.
struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { if let window = view.window { onWindow(window) } }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { if let window = view.window { onWindow(window) } }
    }
}

/// 뷰 높이 측정용 PreferenceKey. 중첩된 측정끼리 값이 섞이지 않도록 용도별로 나눈다.
struct RootHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

struct ListHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// 부모 뷰의 높이를 지정한 PreferenceKey 로 올려 보낸다.
struct HeightReader<Key: PreferenceKey>: View where Key.Value == CGFloat {
    init(_ key: Key.Type) {}

    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: Key.self, value: proxy.size.height)
        }
    }
}

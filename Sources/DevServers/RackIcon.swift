import AppKit

/// 메뉴바용 서버 랙 아이콘. 3칸짜리 랙에 칸마다 전원 LED(초록) · 활동 LED(빨강)를 그린다.
/// LED 색을 살리기 위해 템플릿이 아닌 컬러 이미지로 그리고, 랙 몸체 색은 메뉴바 밝기에 맞춘다.
enum RackIcon {
    static let unitCount = 3

    struct Frame: Equatable {
        /// 전원 LED 가 켜진 칸 수 (위에서부터)
        var powered: Int
        /// 칸별 활동 LED on/off 비트마스크 (bit i = i번째 칸)
        var activityMask: Int
    }

    private static var cache: [Int: NSImage] = [:]

    static func image(_ frame: Frame, isDark: Bool) -> NSImage {
        let key = (isDark ? 1 << 16 : 0) | frame.powered << 8 | frame.activityMask
        if let cached = cache[key] { return cached }
        let image = draw(frame, isDark: isDark)
        cache[key] = image
        return image
    }

    private static let powerColor = NSColor(srgbRed: 0.20, green: 0.90, blue: 0.40, alpha: 1)
    private static let activityColor = NSColor(srgbRed: 1.00, green: 0.25, blue: 0.22, alpha: 1)

    private static func draw(_ frame: Frame, isDark: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 16)
        let ink = isDark ? NSColor(white: 1, alpha: 0.92) : NSColor(white: 0, alpha: 0.85)
        let dim = isDark ? NSColor(white: 1, alpha: 0.22) : NSColor(white: 0, alpha: 0.2)

        let image = NSImage(size: size, flipped: true) { _ in
            let unitHeight: CGFloat = 4.4
            let gap: CGFloat = 1.2
            let top: CGFloat = (size.height - (unitHeight * 3 + gap * 2)) / 2

            for unit in 0..<unitCount {
                let y = top + CGFloat(unit) * (unitHeight + gap)
                let rect = NSRect(x: 1.5, y: y, width: 15, height: unitHeight).insetBy(dx: 0.5, dy: 0.5)
                let body = NSBezierPath(roundedRect: rect, xRadius: 1.2, yRadius: 1.2)
                body.lineWidth = 1.1
                ink.setStroke()
                body.stroke()

                let midY = rect.midY
                let isPowered = unit < frame.powered
                let isActive = isPowered && frame.activityMask & (1 << unit) != 0

                // 켜진 LED 는 컬러 + 은은한 글로우, 꺼진 LED 는 흐린 점
                led(x: 4.4, y: midY, color: isPowered ? powerColor : nil, dim: dim)
                led(x: 7.2, y: midY, color: isActive ? activityColor : nil, dim: dim)

                // 오른쪽 슬롯(디스크 베이) 줄
                let slot = NSBezierPath()
                slot.move(to: NSPoint(x: 10.0, y: midY))
                slot.line(to: NSPoint(x: 14.0, y: midY))
                slot.lineWidth = 1.0
                slot.lineCapStyle = .round
                ink.setStroke()
                slot.stroke()
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func led(x: CGFloat, y: CGFloat, color: NSColor?, dim: NSColor) {
        func circle(_ r: CGFloat) -> NSBezierPath {
            NSBezierPath(ovalIn: NSRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }
        guard let color else {
            dim.setFill()
            circle(0.9).fill()
            return
        }
        color.withAlphaComponent(0.35).setFill()
        circle(1.9).fill()
        color.setFill()
        circle(1.2).fill()
    }
}

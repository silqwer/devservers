import SwiftUI

/// 서버 랙 느낌의 팔레트
enum Rack {
    static let chassis = Color(red: 0.055, green: 0.06, blue: 0.07)
    static let plateTop = Color(red: 0.20, green: 0.21, blue: 0.23)
    static let plateBottom = Color(red: 0.135, green: 0.14, blue: 0.155)
    static let ear = Color(red: 0.105, green: 0.11, blue: 0.12)
    static let engraved = Color(white: 0.58)
    static let lcdBackground = Color(red: 0.02, green: 0.075, blue: 0.04)
    static let lcdText = Color(red: 0.38, green: 0.96, blue: 0.56)
    static let green = Color(red: 0.24, green: 0.92, blue: 0.48)
    static let amber = Color(red: 1.0, green: 0.73, blue: 0.22)
    static let red = Color(red: 1.0, green: 0.33, blue: 0.31)
    static let ledOff = Color(white: 0.2)

    /// CPU 사용률 → 활동 LED 깜빡임 간격 (메뉴바 아이콘과 같은 공식)
    static func blinkInterval(cpu: Double) -> TimeInterval {
        let load = min(max(cpu, 0) / 100, 1)
        return 0.9 - (0.9 - 0.07) * load.squareRoot()
    }
}

/// 브러시드 금속 전면판
struct Faceplate: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(LinearGradient(colors: [Rack.plateTop, Rack.plateBottom], startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.1)).frame(height: 1) }
            .overlay(alignment: .bottom) { Rectangle().fill(.black.opacity(0.55)).frame(height: 1) }
    }
}

/// 양옆에 나사 박힌 랙 이어가 달린 1U 장비
struct RackUnit<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 0) {
            RackEar()
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .modifier(Faceplate())
            RackEar()
        }
        .fixedSize(horizontal: false, vertical: true)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
    }
}

struct RackEar: View {
    var body: some View {
        VStack {
            Screw()
            Spacer(minLength: 4)
            Screw()
        }
        .padding(.vertical, 6)
        .frame(width: 14)
        .frame(maxHeight: .infinity)
        .background(Rack.ear)
        .overlay(alignment: .trailing) { Rectangle().fill(.black.opacity(0.6)).frame(width: 1) }
    }
}

struct Screw: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(white: 0.5), Color(white: 0.22)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Rectangle()
                .fill(.black.opacity(0.7))
                .frame(width: 4, height: 0.9)
                .rotationEffect(.degrees(45))
        }
        .frame(width: 6, height: 6)
        .shadow(color: .black.opacity(0.8), radius: 0.5, y: 0.5)
    }
}

struct LED: View {
    let color: Color
    let isOn: Bool

    var body: some View {
        Circle()
            .fill(isOn ? color : Rack.ledOff)
            .overlay(Circle().fill(.white.opacity(isOn ? 0.35 : 0.06)).frame(width: 2, height: 2).offset(x: -1, y: -1))
            .overlay(Circle().stroke(.black.opacity(0.5), lineWidth: 0.5))
            .frame(width: 6, height: 6)
            .shadow(color: isOn ? color.opacity(0.9) : .clear, radius: 3)
    }
}

/// 전원 LED: 평소 녹색, 종료 중이면 빨간색으로 빠르게 점멸
struct PowerLED: View {
    let isTerminating: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if isTerminating && !reduceMotion {
            TimelineView(.periodic(from: .now, by: 0.2)) { context in
                LED(color: Rack.red, isOn: Int(context.date.timeIntervalSinceReferenceDate * 5) % 2 == 0)
            }
        } else {
            LED(color: isTerminating ? Rack.red : Rack.green, isOn: true)
        }
    }
}

/// 활동 LED: 서버 CPU 사용률에 비례해 깜빡임
struct ActivityLED: View {
    let cpu: Double
    let isOn: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if !isOn {
            LED(color: Rack.amber, isOn: false)
        } else if reduceMotion {
            LED(color: Rack.amber, isOn: true)
        } else {
            TimelineView(.periodic(from: .now, by: Rack.blinkInterval(cpu: cpu))) { _ in
                LED(color: Rack.amber, isOn: Bool.random())
            }
        }
    }
}

/// 녹색 세그먼트 LCD 창
struct LCD: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
            .foregroundStyle(Rack.lcdText)
            .shadow(color: Rack.lcdText.opacity(0.7), radius: 2)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(Rack.lcdBackground, in: RoundedRectangle(cornerRadius: 2))
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(.black.opacity(0.8), lineWidth: 0.8))
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 2).stroke(.white.opacity(0.08), lineWidth: 0.5).offset(y: 0.5)
            }
    }
}

/// 장비 종류를 표시하는 라벨 스티커
struct KindPlate: View {
    let kind: String
    let isNode: Bool

    var body: some View {
        Text(kind.uppercased())
            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
            .tracking(0.6)
            .foregroundStyle(color)
            .padding(.horizontal, 4)
            .padding(.vertical, 1.5)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 2))
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(color.opacity(0.55), lineWidth: 0.7))
            .lineLimit(1)
    }

    private var color: Color {
        guard isNode else { return Color(white: 0.6) }
        switch kind {
        case "Next.js": return Color(white: 0.9)
        case "Vite": return Color(red: 0.72, green: 0.55, blue: 1.0)
        case "Storybook": return Color(red: 1.0, green: 0.45, blue: 0.62)
        case "Nuxt", "Vue": return Rack.green
        case "Astro", "Remix": return Rack.amber
        case "NestJS", "Angular": return Rack.red
        default: return Color(red: 0.45, green: 0.7, blue: 1.0)
        }
    }
}

/// 통풍구
struct VentSlots: View {
    let count: Int

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<count, id: \.self) { _ in
                Capsule()
                    .fill(.black.opacity(0.6))
                    .frame(width: 2.5, height: 22)
                    .overlay(alignment: .trailing) {
                        Capsule().fill(.white.opacity(0.07)).frame(width: 0.6)
                    }
            }
        }
    }
}

/// 노란/검정 경고 줄무늬
struct HazardStripe: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            var x: CGFloat = -size.height
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                path.addLine(to: CGPoint(x: x + size.height + 5, y: 0))
                path.addLine(to: CGPoint(x: x + 5, y: size.height))
                path.closeSubpath()
                context.fill(path, with: .color(Rack.amber))
                x += 10
            }
        }
    }
}

/// 하드웨어 버튼
struct HardwareButtonStyle: ButtonStyle {
    var tint: Color? = nil
    var isProminent = false
    var isSquare = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let top = isProminent ? (tint ?? .gray).opacity(0.85) : Color(white: pressed ? 0.15 : 0.27)
        let bottom = isProminent ? (tint ?? .gray).opacity(0.6) : Color(white: pressed ? 0.2 : 0.17)

        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(isProminent ? .white : (tint ?? Color(white: 0.85)))
            .frame(width: isSquare ? 24 : nil, height: 22)
            .padding(.horizontal, isSquare ? 0 : 8)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom))
            )
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(.black.opacity(0.75), lineWidth: 0.8))
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(.white.opacity(pressed ? 0 : 0.12), lineWidth: 0.6)
                    .padding(0.8)
                    .mask(alignment: .top) { Rectangle().frame(height: 6) }
            }
            .offset(y: pressed ? 0.5 : 0)
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(Rectangle())
    }
}

/// 로커 스위치 + 상태 LED
struct RockerToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 7) {
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.7))
                        .overlay(Capsule().stroke(.white.opacity(0.08), lineWidth: 0.5))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(colors: [Color(white: 0.55), Color(white: 0.3)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 11, height: 10)
                        .padding(2)
                }
                .frame(width: 28, height: 14)
                .animation(.easeOut(duration: 0.12), value: configuration.isOn)

                LED(color: Rack.green, isOn: configuration.isOn)
                configuration.label
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(Rack.engraved)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 전원 버튼: 켜져 있는 동안 초록으로 빛나고, 마우스를 올리면 "누르면 꺼짐" 을 뜻하는 빨강으로 바뀐다.
struct PowerButton: View {
    let help: LocalizedStringKey
    let action: () -> Void
    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let color = isHovering && isEnabled ? Rack.red : Rack.green
        Button(action: action) {
            Image(systemName: "power")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.8), radius: 3)
                .animation(.easeOut(duration: 0.12), value: isHovering)
        }
        .buttonStyle(HardwareButtonStyle(isSquare: true))
        .onHover { isHovering = $0 }
        .help(help)
    }
}

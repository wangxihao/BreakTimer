import SwiftUI

/// 自绘滑杆：替代 Slider（离屏渲染友好，交互一致）。
struct TimeSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var tint: Color = .teal

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let fraction = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.12))
                    .frame(height: 5)
                Capsule()
                    .fill(tint.gradient)
                    .frame(width: max(0, min(width, width * fraction)), height: 5)
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.28), radius: 3, y: 1)
                    .frame(width: 22, height: 22)
                    .offset(x: max(-11, min(width - 11, width * fraction - 11)))
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { gesture in
                let f = min(1, max(0, gesture.location.x / width))
                let raw = range.lowerBound + f * (range.upperBound - range.lowerBound)
                let stepped = (raw / step).rounded() * step
                value = min(range.upperBound, max(range.lowerBound, stepped))
            })
        }
        .frame(height: 26)
    }
}

/// 自绘开关：替代 Toggle（离屏渲染友好，交互一致）。
struct SwitchToggle: View {
    @Binding var isOn: Bool
    var isEnabled = true

    var body: some View {
        Button {
            guard isEnabled else { return }
            isOn.toggle()
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? Color(red: 0.20, green: 0.48, blue: 1.0)
                               : Color.primary.opacity(0.16))
                    .frame(width: 42, height: 25)
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.22), radius: 2, y: 1)
                    .frame(width: 21, height: 21)
                    .padding(2)
            }
            .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isOn)
    }
}

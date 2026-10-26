import SwiftUI

// MARK: - Colors (private داخل هذا الملف فقط)
private let sBg        = Color(hex: 0x86A5A6)
private let sStripe    = Color(hex: 0x9DB5A8)
private let sCard      = Color(hex: 0x634833)
private let sCardEdge  = Color(hex: 0x4A3324)
private let sYellow    = Color(hex: 0xF2C94C)
private let sSoftYellow = Color(hex: 0xF3DC8B)
private let sTrack     = Color(hex: 0x4A3324)
private let sKnob      = Color(hex: 0xEDE6D6)
private let sText      = Color(hex: 0xE9DFC9)

// MARK: - Screen
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var musicVolume: Double = 0.7
    @State private var musicAllowed = true
    @State private var sfxVolume: Double = 0.55
    @State private var sfxAllowed = true

    var body: some View {
        ZStack {
            sBg.ignoresSafeArea()
            SettingsStripes().ignoresSafeArea()

            // الغيوم
            SettingsCloud().frame(width: 140, height: 70)
                .position(x: 90, y: 150)
            SettingsCloud().frame(width: 150, height: 75)
                .position(x: UIScreen.main.bounds.width - 70, y: 215)

            // الجزيرة الصغيرة
            SettingsIsland()
                .frame(width: 140, height: 90)
                .position(x: 75, y: UIScreen.main.bounds.height - 150)

            VStack(spacing: 0) {
                // العنوان + زر الرجوع
                ZStack(alignment: .topLeading) {
                    VStack(spacing: 6) {
                        Text("Setting")
                            .font(.custom("SnellRoundhand-Bold", size: 64))
                            .foregroundStyle(sYellow)
                        Text("make your island yours")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)

                    Button { dismiss() } label: {
                        ZStack {
                            Circle().fill(sCardEdge).offset(y: 4)
                            Circle().fill(sCard)
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(sSoftYellow)
                        }
                        .frame(width: 48, height: 48)
                    }
                    .padding(.leading, 20)
                }
                .padding(.top, 12)

                Spacer().frame(height: 36)

                VStack(spacing: 28) {
                    SettingsCard(title: "music",
                                 volume: $musicVolume,
                                 allowed: $musicAllowed)
                    SettingsCard(title: "sound effect",
                                 volume: $sfxVolume,
                                 allowed: $sfxAllowed)
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Card
private struct SettingsCard: View {
    let title: String
    @Binding var volume: Double
    @Binding var allowed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(sText)

            SettingsSlider(value: $volume)
                .frame(height: 28)
                .opacity(allowed ? 1 : 0.4)
                .disabled(!allowed)

            Rectangle()
                .fill(sText.opacity(0.15))
                .frame(height: 1)

            HStack {
                Text("allow")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(sText)
                Spacer()
                SettingsToggle(isOn: $allowed)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 30).fill(sCardEdge).offset(y: 6)
                RoundedRectangle(cornerRadius: 30).fill(sCard)
            }
        )
    }
}

// MARK: - Custom slider
private struct SettingsSlider: View {
    @Binding var value: Double

    var body: some View {
        GeometryReader { geo in
            let knob: CGFloat = 28
            let width = geo.size.width - knob
            ZStack(alignment: .leading) {
                Capsule().fill(sTrack).frame(height: 14)
                Capsule().fill(sSoftYellow)
                    .frame(width: CGFloat(value) * width + knob / 2, height: 14)
                Circle().fill(sYellow)
                    .overlay(Circle().stroke(sSoftYellow, lineWidth: 3))
                    .frame(width: knob, height: knob)
                    .offset(x: CGFloat(value) * width)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let v = (g.location.x - knob / 2) / width
                        value = min(max(Double(v), 0), 1)
                    }
            )
        }
    }
}

// MARK: - Custom toggle
private struct SettingsToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.25)) { isOn.toggle() }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? Color(hex: 0xD9BC5C) : sTrack)
                    .frame(width: 76, height: 42)
                Circle()
                    .fill(sKnob)
                    .frame(width: 32, height: 32)
                    .padding(.horizontal, 5)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Decorations
private struct SettingsStripes: View {
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { i in
                    Rectangle()
                        .fill(i % 2 == 0 ? Color.clear : sStripe.opacity(0.7))
                }
            }
            .frame(width: geo.size.width * 1.4, height: geo.size.height * 1.3)
            .rotationEffect(.degrees(8))
            .offset(x: -geo.size.width * 0.2, y: -geo.size.height * 0.1)
        }
        .clipped()
    }
}

private struct SettingsCloud: View {
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                Circle().fill(.white).frame(width: h * 0.85)
                    .position(x: w * 0.40, y: h * 0.40)
                Circle().fill(.white).frame(width: h * 0.55)
                    .position(x: w * 0.65, y: h * 0.58)
                Capsule().fill(.white).frame(width: w, height: h * 0.45)
                    .position(x: w * 0.5, y: h * 0.78)
            }
        }
        .opacity(0.9)
    }
}

private struct SettingsIsland: View {
    var body: some View {
        ZStack {
            Ellipse().fill(.white.opacity(0.35))
                .frame(width: 140, height: 40).offset(y: 22)
            Ellipse().fill(Color(hex: 0xC9AE6A))
                .frame(width: 110, height: 34).offset(y: 12)
            Ellipse().fill(sYellow)
                .frame(width: 24, height: 7).offset(y: 10)
            Capsule().fill(sCard)
                .frame(width: 5, height: 42)
                .rotationEffect(.degrees(-6)).offset(x: -4, y: -14)
            Capsule().fill(Color(hex: 0x3E7A52))
                .frame(width: 34, height: 8)
                .rotationEffect(.degrees(-20)).offset(x: -20, y: -36)
            Capsule().fill(Color(hex: 0x3E7A52))
                .frame(width: 34, height: 8)
                .rotationEffect(.degrees(20)).offset(x: 10, y: -36)
        }
    }
}

#Preview {
    SettingsView()
}

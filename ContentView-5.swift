// xcode: set sdk=iOS

import SwiftUI

// MARK: - Colors

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: s).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Welcome Screen

struct ContentView: View {
    var onStart: () -> Void = {}

    var body: some View {
        ZStack {
            Color(hex: "82A5A6").ignoresSafeArea()

            LightRays()
                .ignoresSafeArea()

            // Clouds
            CloudView().frame(width: 140, height: 70).position(x: 110, y: 190)
            CloudView().frame(width: 150, height: 70).position(x: 345, y: 260)
            CloudView().frame(width: 120, height: 60).position(x: 80, y: 480)
            CloudView().frame(width: 120, height: 60).position(x: 330, y: 540)

            // Seagull
            SeagullView()
                .frame(width: 160, height: 80)
                .position(x: 195, y: 90)

            // Welcome text
            Text("welcome")
                .font(.custom("SnellRoundhand-Bold", size: 64))
                .foregroundColor(Color(hex: "EAC25A"))
                .position(x: 195, y: 340)

            // Island
            IslandView()
                .frame(width: 330, height: 260)
                .position(x: 195, y: 560)

            // Start button
            Button(action: onStart) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color(hex: "7A6428"))
                        .offset(y: 6)
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color(hex: "517D7A"))
                    Text("Start")
                        .font(.system(size: 52, weight: .regular))
                        .foregroundColor(.white)
                }
                .frame(width: 296, height: 68)
            }
            .buttonStyle(.plain)
            .position(x: 195, y: 740)
        }
    }
}

// MARK: - Light rays

struct LightRays: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: w * 0.10, y: 0))
                    p.addLine(to: CGPoint(x: w * 0.42, y: 0))
                    p.addLine(to: CGPoint(x: w * 0.75, y: h))
                    p.addLine(to: CGPoint(x: w * 0.45, y: h))
                    p.closeSubpath()
                }
                .fill(Color.white.opacity(0.10))

                Path { p in
                    p.move(to: CGPoint(x: w * 0.60, y: 0))
                    p.addLine(to: CGPoint(x: w * 0.90, y: 0))
                    p.addLine(to: CGPoint(x: w * 1.10, y: h * 0.8))
                    p.addLine(to: CGPoint(x: w * 0.85, y: h * 0.8))
                    p.closeSubpath()
                }
                .fill(Color.white.opacity(0.08))
            }
        }
    }
}

// MARK: - Cloud

struct CloudView: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Ellipse()
                    .fill(Color.white.opacity(0.75))
                    .frame(width: w, height: h * 0.55)
                    .position(x: w * 0.45, y: h * 0.72)
                Circle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: w * 0.42, height: w * 0.42)
                    .position(x: w * 0.50, y: h * 0.42)
                Ellipse()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: w * 0.36, height: h * 0.5)
                    .position(x: w * 0.78, y: h * 0.62)
            }
        }
    }
}

// MARK: - Seagull

struct SeagullView: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // Left wing
                Path { p in
                    p.move(to: CGPoint(x: w * 0.44, y: h * 0.48))
                    p.addLine(to: CGPoint(x: w * 0.18, y: h * 0.40))
                    p.addLine(to: CGPoint(x: w * 0.00, y: h * 0.58))
                    p.addLine(to: CGPoint(x: w * 0.46, y: h * 0.58))
                    p.closeSubpath()
                }
                .fill(Color(hex: "8C8C8C"))

                // Right wing
                Path { p in
                    p.move(to: CGPoint(x: w * 0.56, y: h * 0.48))
                    p.addLine(to: CGPoint(x: w * 0.82, y: h * 0.40))
                    p.addLine(to: CGPoint(x: w * 1.00, y: h * 0.58))
                    p.addLine(to: CGPoint(x: w * 0.54, y: h * 0.58))
                    p.closeSubpath()
                }
                .fill(Color(hex: "6E6E6E"))

                // Wing edges (black)
                Path { p in
                    p.move(to: CGPoint(x: w * 0.00, y: h * 0.58))
                    p.addLine(to: CGPoint(x: w * 0.46, y: h * 0.58))
                    p.addLine(to: CGPoint(x: w * 0.46, y: h * 0.64))
                    p.closeSubpath()
                    p.move(to: CGPoint(x: w * 1.00, y: h * 0.58))
                    p.addLine(to: CGPoint(x: w * 0.54, y: h * 0.58))
                    p.addLine(to: CGPoint(x: w * 0.54, y: h * 0.64))
                    p.closeSubpath()
                }
                .fill(Color.black)

                // Body
                Path { p in
                    p.move(to: CGPoint(x: w * 0.50, y: h * 0.10))
                    p.addLine(to: CGPoint(x: w * 0.57, y: h * 0.40))
                    p.addLine(to: CGPoint(x: w * 0.56, y: h * 0.85))
                    p.addLine(to: CGPoint(x: w * 0.44, y: h * 0.85))
                    p.addLine(to: CGPoint(x: w * 0.43, y: h * 0.40))
                    p.closeSubpath()
                }
                .fill(Color(hex: "E8E8E6"))

                // Tail
                Path { p in
                    p.move(to: CGPoint(x: w * 0.44, y: h * 0.85))
                    p.addLine(to: CGPoint(x: w * 0.56, y: h * 0.85))
                    p.addLine(to: CGPoint(x: w * 0.56, y: h * 1.00))
                    p.addLine(to: CGPoint(x: w * 0.44, y: h * 1.00))
                    p.closeSubpath()
                }
                .fill(Color.black)

                // Beak
                Path { p in
                    p.move(to: CGPoint(x: w * 0.50, y: 0))
                    p.addLine(to: CGPoint(x: w * 0.53, y: h * 0.14))
                    p.addLine(to: CGPoint(x: w * 0.47, y: h * 0.14))
                    p.closeSubpath()
                }
                .fill(Color(hex: "F4E9B0"))
            }
        }
    }
}

// MARK: - Island

struct IslandView: View {
    var body: some View {
        ZStack {
            // Water ring
            Ellipse()
                .fill(Color(hex: "6F9A9C"))
                .frame(width: 322, height: 122)
                .offset(y: 40)

            // Shallow sand halo
            Ellipse()
                .fill(Color(hex: "C2BA84").opacity(0.85))
                .frame(width: 312, height: 100)
                .offset(y: 64)

            // Island side
            Ellipse()
                .fill(Color(hex: "A89060"))
                .frame(width: 290, height: 112)
                .offset(y: 52)

            // Island top
            Ellipse()
                .fill(Color(hex: "F8E08E"))
                .frame(width: 290, height: 108)
                .offset(y: 34)

            // Palm tree
            PalmTree()
                .frame(width: 150, height: 150)
                .offset(x: -62, y: -30)

            // Treasure chest
            TreasureChest()
                .frame(width: 100, height: 90)
                .offset(x: 62, y: 8)
        }
    }
}

// MARK: - Palm tree

struct PalmTree: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let crown = CGPoint(x: w * 0.56, y: h * 0.32)

            ZStack {
                // Back fronds (darker)
                Frond(start: crown,
                      bend: CGPoint(x: w * 0.46, y: h * 0.02),
                      tip: CGPoint(x: w * 0.24, y: h * 0.20),
                      thickness: 0.5)
                    .fill(Color(hex: "2F6B43"))

                Frond(start: crown,
                      bend: CGPoint(x: w * 0.70, y: h * 0.00),
                      tip: CGPoint(x: w * 0.86, y: h * 0.22),
                      thickness: 0.5)
                    .fill(Color(hex: "2F6B43"))

                // Trunk (tapered, leaning right)
                PalmTrunk(crown: crown, baseX: w * 0.30, baseY: h * 0.98,
                          baseWidth: w * 0.075, topWidth: w * 0.045)
                    .fill(Color(hex: "6F5E40"))

                Circle()
                    .fill(Color(hex: "6F5E40"))
                    .frame(width: w * 0.075, height: w * 0.075)
                    .position(x: w * 0.30, y: h * 0.98)

                // Front fronds (lighter, big and drooping)
                Frond(start: crown,
                      bend: CGPoint(x: w * 0.38, y: h * 0.04),
                      tip: CGPoint(x: w * 0.00, y: h * 0.42),
                      thickness: 0.55)
                    .fill(Color(hex: "3E7D4F"))

                Frond(start: crown,
                      bend: CGPoint(x: w * 0.80, y: h * 0.06),
                      tip: CGPoint(x: w * 0.97, y: h * 0.40),
                      thickness: 0.55)
                    .fill(Color(hex: "3E7D4F"))

                Frond(start: crown,
                      bend: CGPoint(x: w * 0.42, y: h * 0.30),
                      tip: CGPoint(x: w * 0.20, y: h * 0.52),
                      thickness: 0.5)
                    .fill(Color(hex: "4A8C5A"))

                Frond(start: crown,
                      bend: CGPoint(x: w * 0.72, y: h * 0.32),
                      tip: CGPoint(x: w * 0.84, y: h * 0.54),
                      thickness: 0.5)
                    .fill(Color(hex: "4A8C5A"))

                // Coconuts
                Circle()
                    .fill(Color(hex: "5A4A30"))
                    .frame(width: w * 0.06, height: w * 0.06)
                    .position(x: w * 0.52, y: h * 0.36)
                Circle()
                    .fill(Color(hex: "5A4A30"))
                    .frame(width: w * 0.06, height: w * 0.06)
                    .position(x: w * 0.60, y: h * 0.37)
            }
        }
    }
}

struct PalmTrunk: Shape {
    var crown: CGPoint
    var baseX: CGFloat
    var baseY: CGFloat
    var baseWidth: CGFloat
    var topWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: baseX - baseWidth / 2, y: baseY))
        p.addQuadCurve(to: CGPoint(x: crown.x - topWidth / 2, y: crown.y),
                       control: CGPoint(x: baseX - baseWidth / 2, y: (baseY + crown.y) / 2))
        p.addLine(to: CGPoint(x: crown.x + topWidth / 2, y: crown.y))
        p.addQuadCurve(to: CGPoint(x: baseX + baseWidth / 2, y: baseY),
                       control: CGPoint(x: baseX + baseWidth / 2, y: (baseY + crown.y) / 2))
        p.closeSubpath()
        return p
    }
}

// A crescent-shaped palm frond: arches up from `start`, then droops to `tip`.
struct Frond: Shape {
    var start: CGPoint
    var bend: CGPoint
    var tip: CGPoint
    var thickness: CGFloat = 0.5   // 0 = thin line, 1 = very fat

    func path(in rect: CGRect) -> Path {
        let mid = CGPoint(x: (start.x + tip.x) / 2, y: (start.y + tip.y) / 2)
        let lower = CGPoint(x: bend.x + (mid.x - bend.x) * thickness,
                            y: bend.y + (mid.y - bend.y) * thickness)
        var p = Path()
        p.move(to: start)
        p.addQuadCurve(to: tip, control: bend)
        p.addQuadCurve(to: start, control: lower)
        p.closeSubpath()
        return p
    }
}

// MARK: - Treasure chest

struct TreasureChest: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // Gold coins in the chest
                Circle().fill(Color(hex: "E6C766"))
                    .frame(width: 14, height: 14)
                    .position(x: w * 0.20, y: h * 0.12)
                Circle().fill(Color(hex: "E6C766"))
                    .frame(width: 14, height: 14)
                    .position(x: w * 0.50, y: h * 0.04)
                Circle().fill(Color(hex: "E6C766"))
                    .frame(width: 14, height: 14)
                    .position(x: w * 0.78, y: h * 0.12)

                // Lid
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: "A8A296"))
                    .frame(width: w * 0.80, height: h * 0.20)
                    .position(x: w * 0.40, y: h * 0.24)

                // Body
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: "7F6420"))
                    .frame(width: w * 0.80, height: h * 0.42)
                    .position(x: w * 0.40, y: h * 0.52)

                // Gold band
                Rectangle()
                    .fill(Color(hex: "C4B06A"))
                    .frame(width: w * 0.80, height: h * 0.08)
                    .position(x: w * 0.40, y: h * 0.40)

                // Lock
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "D9B84E"))
                    .frame(width: w * 0.10, height: h * 0.22)
                    .position(x: w * 0.40, y: h * 0.48)

                // Coins on the ground
                Circle().fill(Color(hex: "E3C96A"))
                    .frame(width: 18, height: 18)
                    .position(x: w * 0.82, y: h * 0.72)
                Circle().fill(Color(hex: "E3C96A"))
                    .frame(width: 18, height: 18)
                    .position(x: w * 0.98, y: h * 0.82)
                Circle().fill(Color(hex: "E3C96A"))
                    .frame(width: 18, height: 18)
                    .position(x: w * 0.65, y: h * 0.86)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}

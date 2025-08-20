import SwiftUI

// Floating Circles View
struct FloatingCirclesView: View {
    @Binding var isAnimating: Bool
    @Environment(\.colorScheme) var colorScheme
    
    // Fixed circle configurations for consistent rendering
    let circles: [(relativeX: CGFloat, relativeY: CGFloat, size: CGFloat, duration: Double)] = [
        (0.2, 0.3, 150, 4.0),
        (0.7, 0.5, 180, 4.5),
        (0.5, 0.8, 120, 3.5)
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<circles.count, id: \.self) { index in
                    let circle = circles[index]
                    Circle()
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.1))
                        .frame(width: circle.size, height: circle.size)
                        .position(
                            x: geometry.size.width * circle.relativeX,
                            y: geometry.size.height * circle.relativeY
                        )
                        .blur(radius: 10)
                        .offset(y: isAnimating ? -20 : 20)
                        .animation(
                            Animation.easeInOut(duration: circle.duration)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.5),
                            value: isAnimating
                        )
                }
            }
        }
    }
}

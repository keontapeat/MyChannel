import SwiftUI

struct MinimalLikeEffect: View {
    @State private var showEffect = false
    @State private var particles: [LikeParticle] = []
    
    var body: some View {
        ZStack {
            ForEach(particles.indices, id: \.self) { index in
                Image(systemName: "heart.fill")
                    .font(.system(size: particles[index].size, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.red, .pink.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .offset(x: particles[index].x, y: particles[index].y)
                    .opacity(particles[index].opacity)
                    .scaleEffect(particles[index].scale)
                    .animation(
                        .easeOut(duration: particles[index].duration)
                        .delay(particles[index].delay),
                        value: showEffect
                    )
            }
        }
        .onAppear {
            triggerEffect()
        }
    }
    
    private func triggerEffect() {
        particles = createParticles()
        showEffect = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            particles.removeAll()
            showEffect = false
        }
    }
    
    private func createParticles() -> [LikeParticle] {
        var newParticles: [LikeParticle] = []
        
        // Create 3-5 minimal particles (not overwhelming)
        for i in 0..<Int.random(in: 3...5) {
            let particle = LikeParticle(
                x: CGFloat.random(in: -15...15),
                y: CGFloat.random(in: -30...10),
                size: CGFloat.random(in: 12...18),
                opacity: Double.random(in: 0.6...0.9),
                scale: Double.random(in: 0.8...1.2),
                duration: Double.random(in: 0.8...1.2),
                delay: Double(i) * 0.1
            )
            newParticles.append(particle)
        }
        
        return newParticles
    }
}

private struct LikeParticle {
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let opacity: Double
    let scale: Double
    let duration: Double
    let delay: Double
}

#Preview {
    MinimalLikeEffect()
        .frame(width: 100, height: 100)
        .background(.black)
}

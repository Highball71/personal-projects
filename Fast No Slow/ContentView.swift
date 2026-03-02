import SwiftUI

struct ContentView: View {
    @StateObject private var workoutManager = WorkoutManager()
    @State private var lowHR: Double = 120
    @State private var highHR: Double = 150
    @State private var showingWorkout = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                
                // Heart icon
                Image(systemName: "heart.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                
                Text("Fast No Slow")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Zone settings
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Low Heart Rate: \(Int(lowHR)) bpm")
                            .font(.headline)
                        Slider(value: $lowHR, in: 60...200, step: 1)
                            .tint(.blue)
                            .onChange(of: lowHR) { newValue in
                                if newValue >= highHR {
                                    highHR = min(newValue + 1, 220)
                                }
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("High Heart Rate: \(Int(highHR)) bpm")
                            .font(.headline)
                        Slider(value: $highHR, in: 61...220, step: 1)
                            .tint(.red)
                            .onChange(of: highHR) { newValue in
                                if newValue <= lowHR {
                                    lowHR = max(newValue - 1, 60)
                                }
                            }
                    }
                    
                    // Visual zone bar
                    ZoneBar(low: Int(lowHR), high: Int(highHR))
                        .frame(height: 40)
                }
                .padding()
                .background(Color.gray.opacity(0.35))
                .cornerRadius(16)
                
                Spacer()
                
                // Start button
                Button(action: {
                    workoutManager.lowHR = Int(lowHR)
                    workoutManager.highHR = Int(highHR)
                    workoutManager.startWorkout()
                    showingWorkout = true
                }) {
                    Text("Start Workout")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(16)
                }
                
                Spacer()
            }
            .padding()
            .fullScreenCover(isPresented: $showingWorkout) {
                WorkoutView(workoutManager: workoutManager, isPresented: $showingWorkout)
            }
            .onAppear {
                workoutManager.requestAuthorization()
            }
        }
    }
}

// MARK: - Zone Bar
struct ZoneBar: View {
    let low: Int
    let high: Int
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.35))
                
                // Below zone
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: geo.size.width * CGFloat(low) / 220.0)
                
                // In zone
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.opacity(0.5))
                    .frame(width: geo.size.width * CGFloat(high - low) / 220.0)
                    .offset(x: geo.size.width * CGFloat(low) / 220.0)
                
                // Labels
                HStack {
                    Text("\(low)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .offset(x: geo.size.width * CGFloat(low) / 220.0 - 10)
                    Spacer()
                }
                HStack {
                    Spacer()
                        .frame(width: geo.size.width * CGFloat(high) / 220.0 - 10)
                    Text("\(high)")
                        .font(.caption)
                        .fontWeight(.bold)
                    Spacer()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

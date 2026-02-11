import SwiftUI

struct StreakCardView: View {

    var currentStreak: Int?
    var longestStreak: Int?
    var todayCompleted: Bool?

    private var streakCount: Int {
        currentStreak ?? 0
    }

    private var bestStreak: Int {
        longestStreak ?? 0
    }

    private var isCompleted: Bool {
        todayCompleted ?? false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(
                        streakCount > 0
                            ? LinearGradient(colors: [.orange, .red], startPoint: .bottom, endPoint: .top)
                            : LinearGradient(colors: [.gray, .gray], startPoint: .bottom, endPoint: .top)
                    )
                    .symbolEffect(.bounce, value: streakCount > 0)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(streakCount)")
                        .font(.title)
                        .fontWeight(.bold)
                        .contentTransition(.numericText())

                    Text("day streak")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                Text("Best: \(bestStreak)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if isCompleted {
                    Label("Done", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                } else {
                    Text("Practice today!")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: streakCount > 0
                                    ? [.orange.opacity(0.4), .red.opacity(0.2)]
                                    : [.gray.opacity(0.2), .gray.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
        }
    }
}

#Preview("No Streak") {
    StreakCardView(
        currentStreak: 0,
        longestStreak: 0,
        todayCompleted: false
    )
    .padding()
}

#Preview("Active Streak") {
    StreakCardView(
        currentStreak: 7,
        longestStreak: 14,
        todayCompleted: true
    )
    .padding()
}

#Preview("Streak At Risk") {
    StreakCardView(
        currentStreak: 3,
        longestStreak: 10,
        todayCompleted: false
    )
    .padding()
}

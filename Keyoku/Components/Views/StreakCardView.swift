import SwiftUI

struct StreakCardView: View {

    var currentStreak: Int?
    var longestStreak: Int?
    var todayCompleted: Bool?
    var studiedDaysThisWeek: [Date] = []

    private let weekdayLabels = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    private var streakCount: Int { currentStreak ?? 0 }
    private var bestStreak: Int { longestStreak ?? 0 }
    private var isCompleted: Bool { todayCompleted ?? false }
    private var hasStreak: Bool { streakCount > 0 }

    private var todayIndex: Int {
        Calendar.current.component(.weekday, from: Date()) - 1
    }

    private var completedIndices: Set<Int> {
        if !studiedDaysThisWeek.isEmpty {
            return Set(studiedDaysThisWeek.map {
                Calendar.current.component(.weekday, from: $0) - 1
            })
        }
        return isCompleted ? [todayIndex] : []
    }

    private var progressFraction: Double {
        if isFullWeek { return 1.0 }
        guard let maxStudied = completedIndices.max() else { return 0 }
        return (Double(maxStudied) + 0.5) / 7.0
    }

    private var isFullWeek: Bool {
        completedIndices.count == 7
    }

    var body: some View {
        VStack(spacing: 16) {
            headerSection
            Divider()
            weekSection
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: isFullWeek ? 56 : 44))
                .foregroundStyle(
                    isFullWeek
                        ? LinearGradient(colors: [.red, .orange, .yellow], startPoint: .bottom, endPoint: .top)
                        : hasStreak
                            ? LinearGradient(colors: [.orange, .red], startPoint: .bottom, endPoint: .top)
                            : LinearGradient(colors: [Color(.systemGray4), Color(.systemGray3)], startPoint: .bottom, endPoint: .top)
                )
                .shadow(color: isFullWeek ? .orange.opacity(0.6) : .clear, radius: 16, x: 0, y: 4)
                .symbolEffect(.bounce, value: streakCount)
                .symbolEffect(.pulse, options: .repeating, isActive: isFullWeek)

            Text(isFullWeek ? "Perfect Week!" : "\(streakCount) Day Streak!")
                .font(.title3)
                .fontWeight(.bold)
                .contentTransition(.numericText())

            Text("Best: \(bestStreak) \(bestStreak == 1 ? "day" : "days")")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Week Progress

    private var weekSection: some View {
        VStack(spacing: 8) {
            ZStack {
                progressBar
                dayCirclesRow
            }
            .frame(height: 32)

            dayLabelsRow
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            let barHeight: CGFloat = 6
            let yOffset = (geo.size.height - barHeight) / 2

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.systemGray5))
                    .frame(height: barHeight)

                Capsule()
                    .fill(LinearGradient(
                        colors: isFullWeek
                            ? [.red, .orange, .yellow]
                            : hasStreak
                                ? [.orange, .red]
                                : [Color(.systemGray4), Color(.systemGray4)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: geo.size.width * progressFraction, height: barHeight)
            }
            .frame(width: geo.size.width)
            .offset(y: yOffset)
        }
    }

    private var dayCirclesRow: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                dayDot(index: index)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var dayLabelsRow: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                Text(weekdayLabels[index])
                    .font(.caption2)
                    .fontWeight(index == todayIndex ? .semibold : .regular)
                    .foregroundStyle(index == todayIndex ? .primary : .secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func dayDot(index: Int) -> some View {
        let isDayCompleted = completedIndices.contains(index)
        let isToday = index == todayIndex

        return ZStack {
            Circle()
                .fill(isDayCompleted
                    ? (hasStreak ? Color.orange : Color(.systemGray3))
                    : Color(.systemGray5))
                .frame(width: 32, height: 32)

            if isDayCompleted {
                Image(systemName: "flame.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
            } else if isToday {
                Image(systemName: "flame")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange.opacity(0.5))
            }
        }
    }
}

// MARK: - Previews

#Preview("No Streak") {
    StreakCardView(
        currentStreak: 0,
        longestStreak: 5,
        todayCompleted: false
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Active Streak - Today Completed") {
    StreakCardView(
        currentStreak: 7,
        longestStreak: 14,
        todayCompleted: true
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Streak At Risk") {
    StreakCardView(
        currentStreak: 3,
        longestStreak: 10,
        todayCompleted: false
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Multiple Studied Days") {
    let calendar = Calendar.current
    let today = Date()
    let studied = (0...2).compactMap {
        calendar.date(byAdding: .day, value: -$0, to: today)
    }
    StreakCardView(
        currentStreak: 3,
        longestStreak: 21,
        todayCompleted: true,
        studiedDaysThisWeek: studied
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Full Week Studied") {
    let calendar = Calendar.current
    let today = Date()
    let weekday = calendar.component(.weekday, from: today) - 1
    let sunday = calendar.date(byAdding: .day, value: -weekday, to: today)!
    let allDays = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: sunday) }
    StreakCardView(
        currentStreak: 7,
        longestStreak: 7,
        todayCompleted: true,
        studiedDaysThisWeek: allDays
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

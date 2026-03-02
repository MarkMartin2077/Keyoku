//
//  StatsView.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import SwiftUI
import Charts

struct StatsView: View {

    @State var presenter: StatsPresenter

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                summaryGrid
                dueThisWeekCard
                deckBreakdownCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .navigationTitle("Insights")
        .background(Color(.systemGroupedBackground))
        .onAppear {
            presenter.onViewAppear()
        }
    }

    // MARK: - Summary Grid

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(
                title: "Streak",
                value: "\(presenter.currentStreak)",
                unit: presenter.currentStreak == 1 ? "day" : "days",
                icon: "flame.fill",
                color: .orange
            )
            statCard(
                title: "Learned",
                value: "\(presenter.learnedCards)",
                unit: "of \(presenter.totalCards) cards",
                icon: "checkmark.circle.fill",
                color: .green
            )
            statCard(
                title: "Due Today",
                value: "\(presenter.dueToday)",
                unit: presenter.dueToday == 1 ? "card" : "cards",
                icon: "clock.fill",
                color: .blue
            )
            if let rate = presenter.retentionRate {
                statCard(
                    title: "Retention",
                    value: "\(Int(rate * 100))%",
                    unit: "of reviewed",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .purple
                )
            } else {
                statCard(
                    title: "Retention",
                    value: "—",
                    unit: "start reviewing",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .purple
                )
            }
        }
    }

    private func statCard(
        title: String,
        value: String,
        unit: String,
        icon: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.footnote)
                    .foregroundStyle(color)
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        }
    }

    // MARK: - Due This Week

    private var dueThisWeekCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Due This Week")
                .font(.headline)

            Chart(presenter.dueByDay) { item in
                BarMark(
                    x: .value("Day", item.date, unit: .day),
                    y: .value("Cards", item.count)
                )
                .foregroundStyle(Color.accentColor.gradient)
                .cornerRadius(5)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(shortWeekdayLabel(for: date))
                                .font(.caption)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 150)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        }
    }

    private func shortWeekdayLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    // MARK: - Deck Breakdown

    private var deckBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Deck Breakdown")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            if presenter.perDeckStats.isEmpty {
                Text("No decks yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                ForEach(Array(presenter.perDeckStats.enumerated()), id: \.element.id) { index, stat in
                    VStack(spacing: 0) {
                        if index > 0 {
                            Divider()
                                .padding(.horizontal, 16)
                        }
                        deckRow(stat: stat)
                    }
                }
            }

            Color.clear.frame(height: 4)
        }
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        }
    }

    private func deckRow(stat: DeckStat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(stat.color.color)
                    .frame(width: 10, height: 10)
                Text(stat.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if stat.dueCards > 0 {
                    Text("\(stat.dueCards) due")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background { Capsule().fill(.orange.opacity(0.15)) }
                }
            }

            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(.systemGray5))
                        let ratio = stat.totalCards > 0
                            ? CGFloat(stat.learnedCards) / CGFloat(stat.totalCards)
                            : 0
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.green.opacity(0.7))
                            .frame(width: geo.size.width * ratio)
                    }
                }
                .frame(height: 6)

                Text("\(stat.learnedCards)/\(stat.totalCards)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - CoreBuilder Extension

extension CoreBuilder {

    func statsView(router: AnyRouter) -> some View {
        StatsView(
            presenter: StatsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            )
        )
    }
}

// MARK: - Preview

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    return RouterView { router in
        builder.statsView(router: router)
    }
}

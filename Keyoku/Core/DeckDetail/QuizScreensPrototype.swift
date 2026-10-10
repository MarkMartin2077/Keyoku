//
//  QuizScreensPrototype.swift
//  Keyoku
//
//  PROTOTYPE — throwaway, lives only on the `prototype/quiz-screens` branch. Do not merge.
//  Question: "What do the quiz screens look like?" (wayfinder ticket #7).
//  Three structurally different takes (A/B/C) on the whole quiz flow, mounted inside the real
//  DeckDetail screen. Flip variants and section states with the floating pill at the bottom.
//  Mock data only; nothing is saved, nothing goes through the presenter.
//

#if DEBUG
import SwiftUI

// MARK: - Mock data

struct ProtoQuestion: Identifiable {
    let id = UUID().uuidString
    let question: String
    let correct: String
    let wrong: [String]
    let explanation: String
}

struct ProtoQuiz: Identifiable {
    let id = UUID().uuidString
    let title: String
    let date: Date
    let scores: [Int]
    let questions: [ProtoQuestion]

    var bestScore: Int? { scores.max() }
}

enum ProtoData {
    static let questions: [ProtoQuestion] = [
        ProtoQuestion(question: "What organelle produces most of a cell's ATP?", correct: "Mitochondria", wrong: ["Ribosome", "Golgi apparatus", "Lysosome"], explanation: "Mitochondria run cellular respiration, which produces most of the cell's ATP."),
        ProtoQuestion(question: "Where does glycolysis take place?", correct: "Cytoplasm", wrong: ["Mitochondrial matrix", "Nucleus", "Inner membrane"], explanation: "Glycolysis happens in the cytoplasm, before pyruvate enters the mitochondria."),
        ProtoQuestion(question: "What is the final electron acceptor in the electron transport chain?", correct: "Oxygen", wrong: ["NADH", "Carbon dioxide", "Glucose"], explanation: "Oxygen accepts electrons at the end of the chain and forms water."),
        ProtoQuestion(question: "How many ATP does glycolysis net per glucose?", correct: "2", wrong: ["4", "36", "1"], explanation: "Glycolysis makes 4 ATP but uses 2, netting 2 per glucose."),
        ProtoQuestion(question: "Which molecule carries electrons from the Krebs cycle?", correct: "NADH", wrong: ["ATP", "Acetyl-CoA", "Pyruvate"], explanation: "NADH and FADH2 carry high-energy electrons to the transport chain.")
    ]

    static let quizzes: [ProtoQuiz] = [
        ProtoQuiz(title: "Cellular Respiration Basics", date: .now.addingTimeInterval(-86_400 * 2), scores: [3, 4], questions: questions),
        ProtoQuiz(title: "Energy and the Mitochondria", date: .now.addingTimeInterval(-86_400 * 9), scores: [5], questions: questions.reversed()),
        ProtoQuiz(title: "Glycolysis Deep Dive", date: .now.addingTimeInterval(-3_600), scores: [], questions: questions)
    ]
}

enum ProtoSectionState: String, CaseIterable {
    case normal = "Has quizzes"
    case empty = "No quizzes yet"
    case shortSource = "Source < 1,500 chars"
    case handMade = "Hand-made deck"
    case unavailable = "AI unavailable"
    case generating = "Generating"
}

// MARK: - Switcher

struct QuizPrototypeSwitcher: View {
    @AppStorage("quizProtoVariant") private var variant: String = "A"
    @AppStorage("quizProtoState") private var state: String = ProtoSectionState.normal.rawValue

    static let variants: [(key: String, name: String)] = [("A", "Classic list"), ("B", "Cards + sheet"), ("C", "Scrolling transcript")]

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "chevron.left").onTapGesture { cycle(-1) }
            Menu {
                ForEach(ProtoSectionState.allCases, id: \.self) { option in
                    Button(option.rawValue) { state = option.rawValue }
                }
            } label: {
                VStack(spacing: 0) {
                    Text("\(variant) · \(Self.variants.first { $0.key == variant }?.name ?? "")").font(.caption.bold())
                    Text(state).font(.caption2)
                }
            }
            Image(systemName: "chevron.right").onTapGesture { cycle(1) }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Capsule().fill(.black.opacity(0.85)))
        .shadow(radius: 6)
        .padding(.bottom, 8)
    }

    private func cycle(_ step: Int) {
        let keys = Self.variants.map(\.key)
        let index = keys.firstIndex(of: variant) ?? 0
        variant = keys[(index + step + keys.count) % keys.count]
    }
}

// MARK: - Deck screen section (mounted inside DeckDetailView's List)

struct QuizScreensPrototypeSection: View {
    let deckColor: Color
    let deckName: String

    @AppStorage("quizProtoVariant") private var variant: String = "A"
    @AppStorage("quizProtoState") private var stateRaw: String = ProtoSectionState.normal.rawValue
    @State private var playing: ProtoQuiz?
    @State private var showNewQuiz = false
    @State private var showAllQuizzes = false

    private var state: ProtoSectionState { ProtoSectionState(rawValue: stateRaw) ?? .normal }
    private var quizzes: [ProtoQuiz] { state == .normal ? ProtoData.quizzes : [] }
    private var canCreate: Bool { state == .normal || state == .empty }

    var body: some View {
        Group {
            switch variant {
            case "B": sectionB
            case "C": sectionC
            default: sectionA
            }
        }
        .fullScreenCover(item: $playing) { quiz in
            QuizPlayPrototype(quiz: quiz, deckColor: deckColor, variant: variant)
        }
        .sheet(isPresented: $showNewQuiz) {
            NewQuizSheetPrototype(deckColor: deckColor)
        }
        .sheet(isPresented: $showAllQuizzes) {
            NavigationStack {
                List { quizRows }
                    .navigationTitle("Quizzes")
            }
        }
    }

    // A: a plain List section, one row per quiz, "New Quiz" as the last row.
    private var sectionA: some View {
        Section {
            stateNotice
            quizRows
            newQuizRow
        } header: {
            Text("Quizzes")
        }
    }

    // B: a horizontal strip of quiz cards with a "+" card at the front.
    private var sectionB: some View {
        Section {
            if state == .normal || state == .empty || state == .generating {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        VStack(spacing: 8) {
                            Image(systemName: state == .generating ? "hourglass" : "plus")
                                .font(.title)
                            Text(state == .generating ? "6 of 10" : "New Quiz").font(.subheadline.bold())
                        }
                        .frame(width: 120, height: 140)
                        .background(RoundedRectangle(cornerRadius: 16).strokeBorder(deckColor, style: StrokeStyle(lineWidth: 2, dash: [6])))
                        .foregroundStyle(deckColor)
                        .onTapGesture { showNewQuiz = true }

                        ForEach(quizzes) { quiz in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(quiz.title).font(.subheadline.bold()).lineLimit(3)
                                    .frame(maxHeight: .infinity, alignment: .topLeading)
                                Text(bestText(quiz)).font(.title3.bold()).foregroundStyle(deckColor)
                                Text("\(quiz.questions.count) Qs · \(quiz.date.formatted(.relative(presentation: .named)))")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .frame(width: 150, height: 140, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 16).fill(deckColor.opacity(0.12)))
                            .onTapGesture { playing = quiz }
                            .contextMenu { Button("Delete", role: .destructive) {} }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                stateNotice
            }
        } header: {
            Text("Quizzes")
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    // C: one summary row beside Practice; the quiz list lives one tap deeper.
    private var sectionC: some View {
        Section {
            HStack {
                Image(systemName: "questionmark.square.fill").font(.title2).foregroundStyle(deckColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quiz").font(.headline)
                    Text(summaryText).font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if canCreate {
                    Text("New").font(.subheadline.bold())
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(deckColor.opacity(0.15)))
                        .foregroundStyle(deckColor)
                        .onTapGesture { showNewQuiz = true }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if let latest = quizzes.first { playing = latest }
            }
            if !quizzes.isEmpty {
                Text("All quizzes (\(quizzes.count))")
                    .font(.subheadline)
                    .foregroundStyle(deckColor)
                    .onTapGesture { showAllQuizzes = true }
            }
            if !canCreate && state != .generating { stateNotice }
        }
    }

    @ViewBuilder
    private var quizRows: some View {
        ForEach(quizzes) { quiz in
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(quiz.title).font(.headline)
                    Text("\(quiz.date.formatted(date: .abbreviated, time: .omitted)) · \(quiz.questions.count) questions")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(bestText(quiz)).font(.subheadline.bold()).foregroundStyle(quiz.bestScore == nil ? .secondary : deckColor)
            }
            .contentShape(Rectangle())
            .onTapGesture { playing = quiz }
        }
        .onDelete { _ in }
    }

    @ViewBuilder
    private var newQuizRow: some View {
        if state == .generating {
            HStack {
                ProgressView()
                Text("Making your quiz… 6 of 10 questions").font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Cancel").font(.subheadline).foregroundStyle(.red)
            }
        } else if canCreate || state == .unavailable {
            Label("New Quiz", systemImage: "plus.circle.fill")
                .foregroundStyle(canCreate ? deckColor : .secondary)
                .onTapGesture { if canCreate { showNewQuiz = true } }
        }
    }

    @ViewBuilder
    private var stateNotice: some View {
        switch state {
        case .handMade:
            Text("Quizzes are made from a deck's source text. This deck was made by hand, so it has none.")
                .font(.caption).foregroundStyle(.secondary)
        case .shortSource:
            Text("Add more source text to make a quiz. Quizzes need at least 1,500 characters.")
                .font(.caption).foregroundStyle(.secondary)
        case .unavailable:
            VStack(alignment: .leading, spacing: 6) {
                Text("Apple Intelligence isn't turned on, so new quizzes can't be made. Saved quizzes still play.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Open Settings").font(.caption.bold()).foregroundStyle(deckColor)
            }
        case .empty:
            Text("Test yourself on \(deckName) with multiple-choice questions from your source text.")
                .font(.caption).foregroundStyle(.secondary)
        default:
            EmptyView()
        }
    }

    private var summaryText: String {
        switch state {
        case .normal: return "\(quizzes.count) quizzes · best \(bestText(quizzes[0]))"
        case .generating: return "Making your quiz… 6 of 10 questions"
        case .empty: return "Test yourself with multiple choice"
        default: return "Not available for this deck"
        }
    }

    private func bestText(_ quiz: ProtoQuiz) -> String {
        guard let best = quiz.bestScore else { return "New" }
        return "\(best)/\(quiz.questions.count)"
    }
}

// MARK: - New Quiz sheet (shared; only the count stepper)

struct NewQuizSheetPrototype: View {
    let deckColor: Color
    @Environment(\.dismiss) private var dismiss
    @State private var count = 10
    let maxCount = 14

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("\(count) questions", value: $count, in: 5...maxCount)
                } footer: {
                    Text("Up to \(maxCount) for this deck's source text. Add more text for longer quizzes.")
                }
                Section {
                    Text("Make Quiz").frame(maxWidth: .infinity).foregroundStyle(deckColor).bold()
                        .onTapGesture { dismiss() }
                }
            }
            .navigationTitle("New Quiz")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Taking a quiz

struct QuizPlayPrototype: View {
    let quiz: ProtoQuiz
    let deckColor: Color
    let variant: String

    @Environment(\.dismiss) private var dismiss
    @State private var order: [ProtoQuestion] = []
    @State private var options: [[String]] = []
    @State private var index = 0
    @State private var picked: [Int: String] = [:]
    @State private var finished = false
    @State private var showLeaveConfirm = false
    @State private var feedbackTrigger = 0
    @State private var lastWasRight = false

    private var score: Int { order.indices.filter { picked[$0] == order[$0].correct }.count }

    var body: some View {
        NavigationStack {
            Group {
                if order.isEmpty {
                    ProgressView()
                } else if finished && variant != "C" {
                    endScreen
                } else {
                    switch variant {
                    case "B": playB
                    case "C": playC
                    default: playA
                    }
                }
            }
            .navigationTitle(finished ? "" : quiz.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image(systemName: "xmark").onTapGesture {
                        if finished || picked.isEmpty { dismiss() } else { showLeaveConfirm = true }
                    }
                }
            }
            .confirmationDialog("Leave this quiz?", isPresented: $showLeaveConfirm, titleVisibility: .visible) {
                Button("Leave", role: .destructive) { dismiss() }
            } message: {
                Text("Your answers so far won't be saved.")
            }
        }
        .overlay(alignment: .bottom) { QuizPrototypeSwitcher() }
        .sensoryFeedback(trigger: feedbackTrigger) { _, _ in lastWasRight ? .success : .error }
        .onAppear(perform: shuffle)
    }

    // A: one question per screen, four stacked answer buttons, feedback inline, Next at the bottom.
    private var playA: some View {
        let question = order[index]
        let answer = picked[index]
        return VStack(spacing: 20) {
            ProgressView(value: Double(index + (answer == nil ? 0 : 1)), total: Double(order.count))
                .tint(deckColor)
            Text("Question \(index + 1) of \(order.count)").font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(question.question).font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: 10) {
                ForEach(options[index], id: \.self) { option in
                    answerButton(option, question: question, answer: answer)
                }
            }
            if let answer {
                feedbackText(answer == question.correct, question: question)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(" ").frame(maxHeight: .infinity)
            if answer != nil {
                Text(index + 1 == order.count ? "See Results" : "Next")
                    .font(.headline).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding()
                    .background(RoundedRectangle(cornerRadius: 14).fill(deckColor))
                    .onTapGesture(perform: advance)
            }
        }
        .padding()
        .padding(.bottom, 50)
    }

    // B: question on a big card, 2x2 answer grid, feedback slides up as a sheet with Continue.
    private var playB: some View {
        let question = order[index]
        let answer = picked[index]
        return VStack(spacing: 16) {
            HStack(spacing: 4) {
                ForEach(order.indices, id: \.self) { row in
                    Capsule().fill(dotColor(row)).frame(height: 6)
                }
            }
            Text(question.question).font(.title2.bold()).multilineTextAlignment(.center)
                .padding(24).frame(maxWidth: .infinity, minHeight: 180)
                .background(RoundedRectangle(cornerRadius: 24).fill(deckColor.opacity(0.12)))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(options[index], id: \.self) { option in
                    Text(option).font(.headline).multilineTextAlignment(.center)
                        .padding(8).frame(maxWidth: .infinity, minHeight: 90)
                        .background(RoundedRectangle(cornerRadius: 16).fill(optionFill(option, question: question, answer: answer)))
                        .onTapGesture { pick(option, question: question) }
                }
            }
            Text(" ").frame(maxHeight: .infinity)
        }
        .padding()
        .sheet(isPresented: .init(get: { answer != nil && !finished }, set: { _ in })) {
            VStack(alignment: .leading, spacing: 12) {
                feedbackText(answer == question.correct, question: question)
                Text(index + 1 == order.count ? "See Results" : "Continue")
                    .font(.headline).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding()
                    .background(RoundedRectangle(cornerRadius: 14).fill(answer == question.correct ? .green : .red))
                    .onTapGesture(perform: advance)
            }
            .padding()
            .presentationDetents([.height(260)])
            .interactiveDismissDisabled()
        }
    }

    // C: a scrolling transcript. Answered questions stay above, collapsed with their result;
    // the current one sits at the bottom; the score card appends at the end. No separate end screen.
    private var playC: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(0...min(index, order.count - 1), id: \.self) { row in
                        let question = order[row]
                        let answer = picked[row]
                        VStack(alignment: .leading, spacing: 10) {
                            Text("\(row + 1). \(question.question)").font(.headline)
                            if let answer, row < index || finished {
                                Label(answer, systemImage: answer == question.correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(answer == question.correct ? .green : .red)
                                if answer != question.correct {
                                    Text("Answer: \(question.correct)").font(.subheadline)
                                }
                                Text(question.explanation).font(.caption).foregroundStyle(.secondary)
                            } else {
                                ForEach(options[row], id: \.self) { option in
                                    answerButton(option, question: question, answer: answer)
                                }
                                if let answer {
                                    feedbackText(answer == question.correct, question: question)
                                }
                            }
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
                        .id(row)
                    }
                    if finished {
                        VStack(spacing: 8) {
                            Text("\(score)/\(order.count)").font(.system(size: 48, weight: .bold)).foregroundStyle(deckColor)
                            Text("Quiz complete").font(.headline)
                            HStack {
                                Text("Retake").bold().onTapGesture(perform: shuffle)
                                    .frame(maxWidth: .infinity)
                                Text("Done").bold().onTapGesture { dismiss() }
                                    .frame(maxWidth: .infinity)
                            }
                            .foregroundStyle(deckColor)
                            .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity).padding()
                        .id("end")
                    }
                }
                .padding()
                .padding(.bottom, 60)
            }
            .onChange(of: picked) { _, _ in
                // Auto-advance a beat after answering so the feedback is readable.
                Task {
                    try? await Task.sleep(for: .seconds(1.6))
                    advance()
                    withAnimation { proxy.scrollTo(finished ? AnyHashable("end") : AnyHashable(index), anchor: .bottom) }
                }
            }
        }
    }

    // Shared end screen for A and B.
    private var endScreen: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().stroke(deckColor.opacity(0.15), lineWidth: 14)
                Circle().trim(from: 0, to: Double(score) / Double(order.count))
                    .stroke(deckColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(score)/\(order.count)").font(.system(size: 44, weight: .bold))
            }
            .frame(width: 180, height: 180)
            Text(score == order.count ? "Perfect!" : "Quiz complete").font(.title2.bold())
            Text("Best: \(max(score, quiz.bestScore ?? 0))/\(order.count) · Streak kept going 🔥")
                .font(.subheadline).foregroundStyle(.secondary)
            Text("Retake").font(.headline).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding()
                .background(RoundedRectangle(cornerRadius: 14).fill(deckColor))
                .onTapGesture(perform: shuffle)
            Text("Done").font(.headline).foregroundStyle(deckColor)
                .onTapGesture { dismiss() }
        }
        .padding(32)
    }

    // MARK: Pieces

    private func answerButton(_ option: String, question: ProtoQuestion, answer: String?) -> some View {
        HStack {
            Text(option).frame(maxWidth: .infinity, alignment: .leading)
            if answer != nil, option == question.correct { Image(systemName: "checkmark.circle.fill") }
            if answer == option, option != question.correct { Image(systemName: "xmark.circle.fill") }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(optionFill(option, question: question, answer: answer)))
        .contentShape(Rectangle())
        .onTapGesture { pick(option, question: question) }
    }

    private func feedbackText(_ isRight: Bool, question: ProtoQuestion) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(isRight ? "Correct" : "Not quite — it's \(question.correct)")
                .font(.headline).foregroundStyle(isRight ? .green : .red)
            Text(question.explanation).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func optionFill(_ option: String, question: ProtoQuestion, answer: String?) -> Color {
        guard let answer else { return Color(.secondarySystemBackground) }
        if option == question.correct { return .green.opacity(0.25) }
        if option == answer { return .red.opacity(0.25) }
        return Color(.secondarySystemBackground).opacity(0.5)
    }

    private func dotColor(_ row: Int) -> Color {
        guard let answer = picked[row] else { return row == index ? deckColor : Color(.systemGray5) }
        return answer == order[row].correct ? .green : .red
    }

    private func pick(_ option: String, question: ProtoQuestion) {
        guard picked[index] == nil else { return }
        picked[index] = option
        lastWasRight = option == question.correct
        feedbackTrigger += 1
    }

    private func advance() {
        guard picked[index] != nil else { return }
        if index + 1 < order.count {
            index += 1
        } else {
            finished = true
        }
    }

    private func shuffle() {
        order = quiz.questions.shuffled()
        options = order.map { ([$0.correct] + $0.wrong).shuffled() }
        index = 0
        picked = [:]
        finished = false
    }
}
#endif

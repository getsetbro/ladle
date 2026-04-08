import Foundation

@MainActor
final class TriviaViewModel: ObservableObject {
    @Published var question: TriviaQuestion?
    @Published var isLoading = false
    @Published var didAnswerToday = false
    @Published var todaysWasCorrect: Bool?
    @Published var errorMessage: String?

    @Published private(set) var totalAnswered = 0
    @Published private(set) var totalCorrect = 0

    private let defaults = UserDefaults.standard

    private let triviaBaseURLString = "https://getsetbro.github.io/ladle"

    private enum Keys {
        static let totalAnswered = "trivia.totalAnswered"
        static let totalCorrect = "trivia.totalCorrect"
        static let answeredDate = "trivia.answeredDate"
        static let answeredWasCorrect = "trivia.answeredWasCorrect"
    }

    init() {
        loadTotals()
        loadTodayState()
    }

    var todaysDateString: String {
        Self.dayFormatter.string(from: Date())
    }

    var scorePercentText: String {
        guard totalAnswered > 0 else { return "0%" }
        let percent = (Double(totalCorrect) / Double(totalAnswered)) * 100
        return String(format: "%.1f%%", percent)
    }

    var shareText: String {
        let status = (todaysWasCorrect == true) ? "✅ Correct" : "❌ Incorrect"
        return "Daily Trivia: \(status) today. Total score: \(scorePercentText) (\(totalCorrect)/\(totalAnswered))."
    }

    func load() async {
        loadTotals()
        loadTodayState()

        if didAnswerToday {
            return
        }

        await fetchQuestion()
    }

    func submitAnswer(index: Int) {
        guard let question else { return }
        guard !didAnswerToday else { return }

        let isCorrect = index == question.correctIndex
        didAnswerToday = true
        todaysWasCorrect = isCorrect

        totalAnswered += 1
        if isCorrect {
            totalCorrect += 1
        }

        persistTotals()
        defaults.set(todaysDateString, forKey: Keys.answeredDate)
        defaults.set(isCorrect, forKey: Keys.answeredWasCorrect)
    }

    func clearStats() {
        totalAnswered = 0
        totalCorrect = 0
        didAnswerToday = false
        todaysWasCorrect = nil
        question = nil
        errorMessage = nil

        defaults.removeObject(forKey: Keys.totalAnswered)
        defaults.removeObject(forKey: Keys.totalCorrect)
        defaults.removeObject(forKey: Keys.answeredDate)
        defaults.removeObject(forKey: Keys.answeredWasCorrect)
    }

    func retryFetch() async {
        errorMessage = nil
        await fetchQuestion()
    }

    private func fetchQuestion() async {
        guard let url = URL(string: "\(triviaBaseURLString)/\(dayOfYearString).json") else {
            errorMessage = "Invalid trivia URL. Update the URL in TriviaViewModel."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200 ... 299).contains(httpResponse.statusCode) else {
                errorMessage = "Could not load today's question from GitHub."
                return
            }

            let decoded = try JSONDecoder().decode(TriviaQuestion.self, from: data)
            guard !decoded.question.isEmpty, decoded.choices.count >= 2 else {
                errorMessage = "Trivia data is missing required fields."
                return
            }
            guard decoded.correctIndex >= 0 && decoded.correctIndex < decoded.choices.count else {
                errorMessage = "Trivia data has an invalid correct answer index."
                return
            }

            question = decoded
        } catch {
            errorMessage = "Failed to download question. Check internet/GitHub URL and try again."
        }
    }

    private func loadTotals() {
        totalAnswered = defaults.integer(forKey: Keys.totalAnswered)
        totalCorrect = defaults.integer(forKey: Keys.totalCorrect)
    }

    private func persistTotals() {
        defaults.set(totalAnswered, forKey: Keys.totalAnswered)
        defaults.set(totalCorrect, forKey: Keys.totalCorrect)
    }

    private func loadTodayState() {
        let answeredDate = defaults.string(forKey: Keys.answeredDate)
        if answeredDate == todaysDateString {
            didAnswerToday = true
            todaysWasCorrect = defaults.object(forKey: Keys.answeredWasCorrect) as? Bool
        } else {
            didAnswerToday = false
            todaysWasCorrect = nil
        }
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private var dayOfYearString: String {
        let dayOfYear = Calendar(identifier: .gregorian).ordinality(of: .day, in: .year, for: Date()) ?? 1
        return String(format: "%03d", dayOfYear)
    }
}

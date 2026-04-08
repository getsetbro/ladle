import Foundation

struct TriviaQuestion: Codable, Equatable {
    let date: String
    let question: String
    let choices: [String]
    let correctIndex: Int
}

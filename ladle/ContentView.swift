//
//  ContentView.swift
//  ladle
//
//  Created by Seth Broweleit on 4/8/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TriviaViewModel()
    @State private var showingClearConfirmation = false
    @State private var showingActions = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    scoreCard

                    if viewModel.isLoading {
                        ProgressView("Loading today's question...")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    } else if viewModel.didAnswerToday {
                        answeredTodayCard
                    } else if let question = viewModel.question {
                        questionCard(question)
                    } else if let errorMessage = viewModel.errorMessage {
                        errorCard(errorMessage)
                    } else {
                        ProgressView("Preparing game...")
                    }
                }
                .padding()
            }
            .navigationTitle("Ladle")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    ShareLink(item: viewModel.shareText) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .disabled(!viewModel.didAnswerToday)

                    Button {
                        showingActions = true
                    } label: {
                        Label("Actions", systemImage: "ellipsis.circle")
                    }
                }
            }
            .confirmationDialog("Actions", isPresented: $showingActions, titleVisibility: .visible) {
                Button("Clear Total", role: .destructive) {
                    showingClearConfirmation = true
                }

                Button("Cancel", role: .cancel) {}
            }
            .alert("Clear your total progress?", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    viewModel.clearStats()
                    Task {
                        await viewModel.load()
                    }
                }
            } message: {
                Text("This resets today's result and your running score.")
            }
            .task {
                await viewModel.load()
            }
        }
    }

    private var scoreCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overall Score")
                .font(.headline)
            Text(viewModel.scorePercentText)
                .font(.largeTitle.weight(.semibold))
            Text("\(viewModel.totalCorrect)/\(viewModel.totalAnswered) correct")
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.2), Color.green.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16)
        )
    }

    private var answeredTodayCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today's Question Complete")
                .font(.headline)

            Text(viewModel.todaysWasCorrect == true ? "You got it right today." : "You missed today's question.")
                .font(.body)

            Text("Come back tomorrow for a new question.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func questionCard(_ question: TriviaQuestion) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Question \(question.date)")
                .font(.headline)

            Text(question.question)
                .font(.system(size: 28, weight: .semibold, design: .serif))

            VStack(spacing: 10) {
                ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                    Button {
                        viewModel.submitAnswer(index: index)
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Text(letter(for: index))
                                .font(.headline)
                                .frame(width: 24, height: 24)
                                .background(Color.accentColor.opacity(0.15), in: Circle())

                            Text(choice)
                                .font(.system(size: 18, weight: .regular, design: .serif))
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Could not load today's question")
                .font(.headline)
            Text(message)
                .foregroundStyle(.secondary)

            Button("Try Again") {
                Task {
                    await viewModel.retryFetch()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func letter(for index: Int) -> String {
        let scalars = UnicodeScalar(65 + index)
        if let value = scalars {
            return String(value)
        }
        return "?"
    }
}

#Preview {
    ContentView()
}

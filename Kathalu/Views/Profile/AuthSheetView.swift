import SwiftUI

/// Username + password sign in / sign up, mirroring the web app's modal
/// (username maps to username@kathalu.local under the hood).
struct AuthSheetView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case signIn = "Sign in"
        case signUp = "Sign up"
        var id: String { rawValue }
    }

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let startMode: Mode
    var onSuccess: () -> Void = {}

    @State private var mode: Mode
    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isWorking = false

    init(startMode: Mode = .signIn, onSuccess: @escaping () -> Void = {}) {
        self.startMode = startMode
        self.onSuccess = onSuccess
        _mode = State(initialValue: startMode)
    }

    private var isValid: Bool {
        username.trimmingCharacters(in: .whitespaces).count >= 2 && password.count >= 6
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                VStack(spacing: 12) {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .authField()
                    SecureField("Password (6+ characters)", text: $password)
                        .textContentType(mode == .signUp ? .newPassword : .password)
                        .authField()
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    submit()
                } label: {
                    Group {
                        if isWorking {
                            ProgressView().tint(.white)
                        } else {
                            Text(mode.rawValue)
                        }
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(isValid ? Theme.accent : Theme.textTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                }
                .disabled(!isValid || isWorking)

                Text("No email needed — just pick a username.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textTertiary)

                Spacer()
            }
            .padding(24)
            .background(Theme.pageBackground)
            .navigationTitle(mode.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func submit() {
        errorMessage = nil
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                let name = username.trimmingCharacters(in: .whitespaces)
                switch mode {
                case .signIn: try await model.signIn(username: name, password: password)
                case .signUp: try await model.signUp(username: name, password: password)
                }
                onSuccess()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private extension View {
    func authField() -> some View {
        self.padding(.horizontal, 14)
            .frame(height: 48)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.divider))
    }
}

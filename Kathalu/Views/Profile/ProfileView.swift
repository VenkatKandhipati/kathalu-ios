import SwiftUI

/// Profile tab: account card, grouped reading settings, sign in/out.
struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @State private var showAuth = false
    @State private var showDeleteConfirm = false
    @State private var deleteError: String?

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            List {
                Section {
                    if let username = model.username {
                        signedInCard(username: username)
                    } else {
                        signedOutCard
                    }
                }
                .listRowBackground(Theme.card)

                Section("Reading") {
                    Picker(selection: $model.appearance) {
                        ForEach(AppModel.Appearance.allCases) { Text($0.label).tag($0) }
                    } label: {
                        settingLabel("Appearance", systemImage: "sun.max")
                    }

                    Picker(selection: $model.fontSize) {
                        ForEach(AppModel.ReadingFontSize.allCases) { Text($0.label).tag($0) }
                    } label: {
                        settingLabel("Reading font size", systemImage: "textformat.size")
                    }
                }
                .listRowBackground(Theme.card)

                if model.isSignedIn {
                    Section {
                        Button("Sign out") {
                            model.signOut()
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(Theme.accent)
                    }
                    .listRowBackground(Theme.card)

                    Section {
                        Button("Delete account", role: .destructive) {
                            showDeleteConfirm = true
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .listRowBackground(Theme.card)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Profile")
            .sheet(isPresented: $showAuth) {
                AuthSheetView(startMode: .signIn) {}
            }
            .confirmationDialog(
                "Delete your account and all synced data? This cannot be undone.",
                isPresented: $showDeleteConfirm, titleVisibility: .visible
            ) {
                Button("Delete account", role: .destructive) {
                    Task {
                        do { try await model.deleteAccount() }
                        catch { deleteError = error.localizedDescription }
                    }
                }
            }
            .alert("Couldn't delete account", isPresented: .init(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteError ?? "")
            }
        }
    }

    private func signedInCard(username: String) -> some View {
        HStack(spacing: 16) {
            Text(String(username.prefix(1)).uppercased())
                .font(Theme.latinSerif(26, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 62, height: 62)
                .background(
                    LinearGradient(
                        colors: [Theme.accent, Theme.accentDeep],
                        startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text("@\(username)")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Theme.textHeading)
                HStack(spacing: 5) {
                    switch model.syncStatus {
                    case .synced, .idle:
                        Image(systemName: "checkmark.icloud")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.green)
                        Text("Synced")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(Theme.green)
                    case .syncing:
                        ProgressView().controlSize(.mini)
                        Text("Syncing…")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.textTertiary)
                    case .offline:
                        Image(systemName: "icloud.slash")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textTertiary)
                        Text("Offline — changes saved locally")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var signedOutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reading anonymously")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.textHeading)
            Text("Your progress is saved on this device. Create a free account to sync it across devices.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
            Button {
                showAuth = true
            } label: {
                Text("Sign in or create account")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.vertical, 8)
    }

    private func settingLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 14))
                .foregroundStyle(Theme.accent)
                .frame(width: 30, height: 30)
                .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            Text(title)
                .foregroundStyle(Theme.textBody)
        }
    }
}

#Preview {
    ProfileView()
        .environment(AppModel())
}

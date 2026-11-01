import SwiftUI
import BloomKit

struct OnboardingView: View {
    @AppStorage(SettingsKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @AppStorage(SettingsKey.typicalCycleLength) private var typicalCycleLength = 28
    @AppStorage(SettingsKey.typicalPeriodLength) private var typicalPeriodLength = 5
    @AppStorage(SettingsKey.lastPeriodStartHint) private var lastPeriodStartHint = ""

    @State private var page = 0
    @State private var remembersLastPeriod = true
    @State private var lastPeriodStart = Date.now

    private let lastPage = 2

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcome.tag(0)
                privacy.tag(1)
                setup.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < lastPage {
                    withAnimation { page += 1 }
                } else {
                    finish()
                }
            } label: {
                Text(page < lastPage ? LocalizedStringKey("Continue") : LocalizedStringKey("Get started"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .padding()
        }
        .background(BloomColor.groupedBackground)
        .tint(BloomColor.accent)
        .interactiveDismissDisabled()
    }

    private var welcome: some View {
        OnboardingPage(
            systemImage: "camera.macro",
            title: "Welcome to bloom",
            message: "Log your period, symptoms and more. bloom learns from your own data to predict your period, ovulation and fertile window."
        )
    }

    private var privacy: some View {
        OnboardingPage(
            systemImage: "lock.shield.fill",
            title: "Private by design",
            message: "Your data never leaves your device. No account, no cloud, no tracking. bloom is open source, so anyone can check this."
        ) {
            Label("bloom is not a contraceptive and does not replace medical advice.", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .padding()
                .background(BloomColor.cardBackground, in: .rect(cornerRadius: 16))
        }
    }

    private var setup: some View {
        Form {
            Section {
                Toggle("I know when my last period started", isOn: $remembersLastPeriod)
                if remembersLastPeriod {
                    DatePicker(
                        "Last period started",
                        selection: $lastPeriodStart,
                        in: ...Date.now,
                        displayedComponents: .date
                    )
                }
            } header: {
                Text("A few details")
            }

            Section {
                Stepper(value: $typicalCycleLength, in: 18...45) {
                    LabeledContent("Cycle length") { Text("\(typicalCycleLength) days") }
                }
                Stepper(value: $typicalPeriodLength, in: 2...10) {
                    LabeledContent("Period length") { Text("\(typicalPeriodLength) days") }
                }
            } footer: {
                Text("Not sure? Keep the defaults. You can change everything later in Settings.")
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func finish() {
        lastPeriodStartHint = remembersLastPeriod ? CalendarDay(lastPeriodStart).isoString : ""
        hasCompletedOnboarding = true
    }
}

private struct OnboardingPage<Accessory: View>: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let accessory: Accessory

    init(
        systemImage: String,
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.accessory = accessory()
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: systemImage)
                .font(.system(size: 72))
                .foregroundStyle(BloomColor.accent)
                .accessibilityHidden(true)
            Text(title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            accessory
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

#Preview {
    OnboardingView()
}

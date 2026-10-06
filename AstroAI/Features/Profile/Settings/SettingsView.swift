//
//  SettingsView.swift
//  AstroAI
//

import SwiftUI

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                header
                calculationSection
                notificationsSection
                privacySection
                membershipCard
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xl)
        }
        .scrollIndicators(.hidden)
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.refresh() }
        .confirmationDialog(
            "Purge Enclave & Ephemeris Cache?",
            isPresented: $viewModel.isConfirmingPurge,
            titleVisibility: .visible
        ) {
            Button("Purge & Sign Out", role: .destructive, action: viewModel.confirmPurge)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This irrevocably erases your chart, journal and local ephemeris calculations from this device.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Eyebrow(text: "Settings", icon: "sun.max")
            Text("Chart & notifications")
                .font(AppFont.displayMobile)
                .foregroundStyle(AppColor.onSurface)
            Text("House system, zodiac, and when the app may reach you.")
                .font(AppFont.bodyLarge)
                .foregroundStyle(AppColor.onSurfaceVariant)
        }
    }

    // MARK: - Calculation

    private var calculationSection: some View {
        SettingsSection(title: "Calculation Engine", icon: "scope", trailing: "") {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("House system")
                        .font(AppFont.bodyLarge.weight(.medium))
                        .foregroundStyle(AppColor.onSurface)
                }
                ScrollView(.horizontal) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(viewModel.houseSystems, id: \.self) { system in
                            houseChip(system)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .padding(.vertical, Spacing.xs)
                Text(viewModel.houseDescription)
                    .font(AppFont.bodySmall.italic())
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColor.surfaceContainerLow, in: .rect(cornerRadius: Radius.sm))
                    .animation(.easeOut(duration: 0.2), value: viewModel.prefs.houseSystem)
            }
            .padding(Spacing.md)

            SectionDivider()

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Zodiac")
                    .font(AppFont.bodyLarge.weight(.medium))
                    .foregroundStyle(AppColor.onSurface)
                HStack(spacing: Spacing.xs) {
                    ForEach(viewModel.zodiacOptions) { option in
                        zodiacSegment(option)
                    }
                }
                .padding(Spacing.xs)
                .background(AppColor.surfaceContainer, in: .rect(cornerRadius: Radius.md))
                .padding(.top, Spacing.xs)
            }
            .padding(Spacing.md)

            SectionDivider()

            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Lunar node")
                        .font(AppFont.bodyLarge.weight(.medium))
                        .foregroundStyle(AppColor.onSurface)
                    Text("True node follows the actual path. Mean node uses the average.")
                        .font(AppFont.bodySmall)
                        .foregroundStyle(AppColor.onSurfaceVariant)
                }
                Spacer(minLength: 0)
                HStack(spacing: 2) {
                    ForEach(viewModel.nodeOptions) { option in
                        nodeSegment(option)
                    }
                }
                .padding(2)
                .background(AppColor.surfaceContainer, in: .capsule)
            }
            .padding(Spacing.md)
        }
    }

    private func houseChip(_ system: String) -> some View {
        let isSelected = viewModel.prefs.houseSystem == system
        return Button {
            viewModel.selectHouseSystem(system)
        } label: {
            Text(system)
                .font(AppFont.bodySmall.weight(.medium))
                .foregroundStyle(isSelected ? AppColor.onPrimary : AppColor.onSurfaceVariant)
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(isSelected ? AppColor.primary : AppColor.surfaceContainer, in: .capsule)
        }
        .buttonStyle(.plain)
    }

    private func zodiacSegment(_ option: SettingsViewModel.Option) -> some View {
        let isSelected = viewModel.prefs.zodiac == option.value
        return Button {
            viewModel.selectZodiac(option.value)
        } label: {
            VStack(spacing: 2) {
                Text(option.value)
                    .font(AppFont.bodySmall.weight(.medium))
                if let caption = option.caption {
                    Text(caption)
                        .font(AppFont.labelSmall)
                }
            }
            .foregroundStyle(isSelected ? AppColor.primary : AppColor.onSurfaceVariant)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(isSelected ? AppColor.surfaceContainerLowest : .clear, in: .rect(cornerRadius: Radius.sm))
            .shadow(color: .black.opacity(isSelected ? 0.05 : 0), radius: 2, y: 1)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func nodeSegment(_ option: SettingsViewModel.Option) -> some View {
        let isSelected = viewModel.prefs.lunarNode == option.value
        return Button {
            viewModel.selectLunarNode(option.value)
        } label: {
            Text(option.value)
                .font(AppFont.labelMedium.weight(.semibold))
                .foregroundStyle(isSelected ? AppColor.onPrimary : AppColor.onSurfaceVariant)
                .padding(.horizontal, 12)
                .frame(height: 26)
                .background(isSelected ? AppColor.primary : .clear, in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        SettingsSection(title: "Notifications", icon: "clock", trailing: "") {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                NotificationToggleRow(
                    title: "Daily Morning Attunement",
                    glyph: "☉",
                    text: "Delivers poetic synthesis and transits at dawn.",
                    isOn: $viewModel.prefs.morningAttunement
                )
                Label("Scheduled for 08:00 AM Local", systemImage: "alarm")
                    .font(AppFont.labelSmall)
                    .foregroundStyle(AppColor.onSurfaceVariant)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 4)
                    .background(AppColor.surfaceContainer, in: .capsule)
            }
            .padding(Spacing.md)

            SectionDivider()

            NotificationToggleRow(
                title: "Exact Planetary Aspects",
                glyph: "☌ ☍ △",
                text: "Signals culminating conjunctions, trines, and oppositions within 0°15' orb.",
                isOn: $viewModel.prefs.exactAspects
            )
            .padding(Spacing.md)

            SectionDivider()

            NotificationToggleRow(
                title: "Lunar Phase Transitions",
                glyph: "☽",
                text: "Notifies ingresses, New Moons, First Quarters, and Full Illumination.",
                isOn: $viewModel.prefs.lunarPhases
            )
            .padding(Spacing.md)

            SectionDivider()

            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Sanctuary Quiet Window")
                        .font(AppFont.bodyLarge.weight(.medium))
                        .foregroundStyle(AppColor.onSurface)
                    Text("Suppresses all cosmic pings during deep rest")
                        .font(AppFont.bodySmall)
                        .foregroundStyle(AppColor.onSurfaceVariant)
                }
                Spacer(minLength: 0)
                Button(action: viewModel.toggleQuietWindow) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: viewModel.prefs.quietWindow ? "moon.fill" : "moon")
                        Text(viewModel.prefs.quietWindow ? "22:00 —\n07:30" : "Off")
                            .multilineTextAlignment(.leading)
                    }
                    .font(AppFont.bodySmall.weight(.medium))
                    .foregroundStyle(viewModel.prefs.quietWindow ? AppColor.onSurface : AppColor.outline)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(AppColor.surfaceContainer, in: .rect(cornerRadius: Radius.sm))
                }
                .buttonStyle(.plain)
            }
            .padding(Spacing.md)
        }
    }

    // MARK: - Privacy

    private var privacySection: some View {
        SettingsSection(title: "Privacy", icon: "lock.shield", trailing: "") {
            PrivacyRow(
                icon: "lock.doc",
                title: "Local Cryptographic Enclave",
                badge: "AES-GCM-256",
                text: "Your natal chart coordinates, exact latitude/longitude, and journal annotations never touch third-party servers unencrypted."
            )
            SectionDivider()
            PrivacyRow(
                icon: "brain.head.profile",
                title: "Context Anonymization",
                badge: "Active",
                text: "AI oracle queries strip names, places of birth, and identity markers prior to celestial pattern synthesis."
            )
            SectionDivider()
            ActionRow(
                icon: "xmark.bin",
                title: "Purge Enclave & Ephemeris Cache",
                text: "Irrevocably erase local ephemeris calculations",
                tint: AppColor.error,
                action: viewModel.requestPurge
            )
        }
    }

    // MARK: - Membership

    private var membershipCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Eyebrow(text: "Membership Tier", icon: "infinity", color: AppColor.champagne)
                Spacer()
                Text(viewModel.membershipBadge)
                    .font(AppFont.labelSmall)
                    .foregroundStyle(AppColor.onPrimary.opacity(0.8))
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 3)
                    .background(AppColor.onPrimary.opacity(0.12), in: .capsule)
            }
            Text(viewModel.membershipTitle)
                .font(AppFont.headlineLarge)
                .foregroundStyle(AppColor.onPrimary)
            Text(viewModel.membershipText)
                .font(AppFont.bodyMedium)
                .foregroundStyle(AppColor.onPrimary.opacity(0.75))
            if !viewModel.isPremium {
                Rectangle()
                    .fill(AppColor.onPrimary.opacity(0.15))
                    .frame(height: 0.5)
                HStack {
                    Spacer()
                    Button(action: viewModel.manageSubscription) {
                        Text(viewModel.membershipAction)
                            .font(AppFont.bodySmall.weight(.semibold))
                            .underline()
                            .foregroundStyle(AppColor.champagne)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .card(.accent, padding: Spacing.lg)
    }
}

// MARK: - Building blocks

private struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let trailing: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Label(title.uppercased(), systemImage: icon)
                    .font(AppFont.labelLarge)
                    .tracking(1)
                    .foregroundStyle(AppColor.onSurface)
                if !trailing.isEmpty {
                    Spacer()
                    Text(trailing)
                        .font(AppFont.labelSmall)
                        .foregroundStyle(AppColor.onSurfaceVariant)
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .card(padding: 0)
        }
    }
}

private struct SectionDivider: View {
    var body: some View {
        HairlineDivider(inset: Spacing.md)
    }
}

private struct NotificationToggleRow: View {
    let title: String
    let glyph: String
    let text: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    Text(title)
                        .font(AppFont.bodyLarge.weight(.medium))
                        .foregroundStyle(AppColor.onSurface)
                    Text(glyph)
                        .font(.system(size: 12, design: .serif))
                        .foregroundStyle(AppColor.secondary)
                }
                Text(text)
                    .font(AppFont.bodySmall)
                    .foregroundStyle(AppColor.onSurfaceVariant)
            }
        }
        .tint(AppColor.primary)
    }
}

private struct PrivacyRow: View {
    let icon: String
    let title: String
    let badge: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            IconBadge(systemName: icon, size: 32, background: AppColor.surfaceContainer)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(AppFont.bodyLarge.weight(.medium))
                        .foregroundStyle(AppColor.onSurface)
                    Spacer(minLength: Spacing.sm)
                    Text(badge)
                        .font(AppFont.labelSmall)
                        .tracking(0.6)
                        .foregroundStyle(AppColor.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppColor.surfaceContainer, in: .capsule)
                }
                Text(text)
                    .font(AppFont.bodySmall)
                    .foregroundStyle(AppColor.onSurfaceVariant)
            }
        }
        .padding(Spacing.md)
    }
}

private struct ActionRow: View {
    let icon: String
    let title: String
    let text: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                IconBadge(
                    systemName: icon,
                    size: 32,
                    foreground: tint,
                    background: tint == AppColor.error ? AppColor.error.opacity(0.08) : AppColor.surfaceContainer
                )
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(title)
                        .font(AppFont.bodyLarge.weight(.medium))
                        .foregroundStyle(tint)
                    Text(text)
                        .font(AppFont.bodySmall)
                        .foregroundStyle(AppColor.onSurfaceVariant)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(tint)
            }
            .padding(Spacing.md)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

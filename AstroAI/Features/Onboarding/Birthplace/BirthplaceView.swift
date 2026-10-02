//
//  BirthplaceView.swift
//  AstroAI
//

import SwiftUI

struct BirthplaceView: View {
    @State private var viewModel: BirthplaceViewModel
    @FocusState private var isSearchFocused: Bool

    init(viewModel: BirthplaceViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                stepRow

                ScreenTitle(
                    eyebrow: "Topocentric Horizon",
                    title: "Where were you born?",
                    subtitle: "Your birthplace determines the geographical latitude and longitude for exact topocentric ephemeris calculations and precise house cusps."
                )

                searchField
                resultsSection
                engineCard
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.vertical, Spacing.md)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .top, spacing: 0) {
            OnboardingHeader(step: 3, onBack: viewModel.back)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: Spacing.md) {
                PrimaryButton(title: "Continue", action: viewModel.continueTapped)
                    .disabled(!viewModel.canContinue)
                Button(action: viewModel.skipPlace) {
                    HStack(spacing: Spacing.xs) {
                        Text("I do not know my birth city")
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 14))
                    }
                }
                .buttonStyle(.astroGhost)
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.vertical, Spacing.md)
            .background(AppColor.surface)
        }
        .screenBackground()
        .toolbarVisibility(.hidden, for: .navigationBar)
        .animation(.easeInOut(duration: 0.2), value: viewModel.results)
    }

    private var stepRow: some View {
        HStack {
            HStack(spacing: Spacing.sm) {
                Circle().fill(AppColor.primary).frame(width: 5, height: 5)
                Text("STEP 3 OF \(OnboardingCoordinator.steps.count)")
                    .font(AppFont.labelMedium.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(AppColor.onSurfaceVariant)
            }
            Spacer()
            Text("EPHEMERIS LOCATOR")
                .font(AppFont.labelMedium)
                .tracking(0.8)
                .foregroundStyle(AppColor.secondary)
        }
    }

    private var searchField: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AppColor.onSurfaceVariant)
            TextField("Enter city, region, or country", text: $viewModel.query)
                .font(AppFont.bodyLarge)
                .foregroundStyle(AppColor.onSurface)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isSearchFocused)
            if viewModel.isSearching {
                ProgressView().controlSize(.small)
            } else if !viewModel.query.isEmpty {
                Button(action: viewModel.clearQuery) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColor.onSurfaceVariant)
                        .frame(width: 28, height: 28)
                        .background(AppColor.surfaceContainerHigh, in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear location input")
            }
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: 52)
        .background(AppColor.surfaceContainer, in: .rect(cornerRadius: Radius.md))
    }

    @ViewBuilder
    private var resultsSection: some View {
        if let hint = viewModel.emptyHint {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "mappin.and.ellipse")
                Text(hint)
            }
            .font(AppFont.bodyMedium)
            .foregroundStyle(AppColor.outline)
            .padding(.horizontal, Spacing.xs)
        } else if !viewModel.results.isEmpty {
            VStack(spacing: 0) {
                ForEach(viewModel.resultRows) { row in
                    if row.showsDivider {
                        Rectangle()
                            .fill(AppColor.outlineVariant.opacity(0.6))
                            .frame(height: 0.5)
                            .padding(.horizontal, Spacing.md)
                    }
                    PlaceRow(place: row.place, isSelected: row.isSelected) {
                        isSearchFocused = false
                        viewModel.select(row.place)
                    }
                }
            }
            .padding(Spacing.xs)
            .background(AppColor.surfaceContainerLowest, in: .rect(cornerRadius: Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .stroke(AppColor.hairline.opacity(0.12), lineWidth: 0.5)
            )
        }
    }

    private var engineCard: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "safari")
                .font(.system(size: 18))
                .foregroundStyle(AppColor.secondary)
                .frame(width: 36, height: 36)
                .background(AppColor.secondaryContainer, in: .rect(cornerRadius: Radius.sm))
            VStack(alignment: .leading, spacing: 2) {
                Text("Swiss Ephemeris Topocentric Engine Active")
                    .font(AppFont.bodySmall.weight(.medium))
                    .foregroundStyle(AppColor.onSurface)
                Text("Moshier analytical orbital matrix calibrated to sea level")
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(AppColor.onSurfaceVariant)
            }
            .lineLimit(1)
            Spacer(minLength: 0)
            Circle().fill(AppColor.secondary).frame(width: 8, height: 8)
        }
        .padding(Spacing.md)
        .background(AppColor.surfaceContainerLow, in: .rect(cornerRadius: Radius.lg))
    }
}

private struct PlaceRow: View {
    let place: BirthPlace
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: Spacing.md) {
                IconBadge(
                    systemName: isSelected ? "mappin.circle" : "clock",
                    size: 32,
                    foreground: isSelected ? AppColor.primaryContainer : AppColor.onSurfaceVariant,
                    background: isSelected ? AppColor.primaryFixed : AppColor.surfaceContainerHigh
                )

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(place.city)
                            .font(AppFont.headlineMedium)
                            .foregroundStyle(AppColor.onSurface)
                        Text(", \(place.region)")
                            .font(AppFont.bodyLarge)
                            .foregroundStyle(AppColor.onSurfaceVariant)
                    }
                    Text("\(place.coordinates) · \(place.timeZone)")
                        .font(AppFont.bodySmall)
                        .foregroundStyle(isSelected ? AppColor.secondary : AppColor.onSurfaceVariant)
                        .lineLimit(1)
                    if isSelected {
                        HStack(spacing: Spacing.xs) {
                            Circle().fill(AppColor.secondary).frame(width: 5, height: 5)
                            Text("TOPOCENTRIC PARALLAX ACTIVE")
                                .font(AppFont.labelSmall)
                                .tracking(1)
                                .foregroundStyle(AppColor.onSurfaceVariant)
                        }
                    }
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppColor.onPrimary)
                        .frame(width: 24, height: 24)
                        .background(AppColor.primary, in: .circle)
                } else {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColor.outlineVariant)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? AppColor.surfaceContainer : .clear, in: .rect(cornerRadius: Radius.md))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

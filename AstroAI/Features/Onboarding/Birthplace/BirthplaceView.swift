//
//  BirthplaceView.swift
//  AstroAI
//

import MapKit
import SwiftUI

struct BirthplaceView: View {
    @State private var viewModel: BirthplaceViewModel
    @FocusState private var isSearchFocused: Bool

    init(viewModel: BirthplaceViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.block) {
                stepRow

                ScreenTitle(
                    eyebrow: "Birthplace",
                    title: "Where were you born?",
                    subtitle: "The city sets the houses of your chart."
                )

                searchField
                resultsSection
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
        .background {
            BirthplaceMap(place: viewModel.selectedPlace)
                .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
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
            .card(.elevated, padding: Spacing.xs)
        }
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

/// Dimmed map behind the birthplace form. It rests on a wide view until a city is chosen.
private struct BirthplaceMap: View {
    let place: BirthPlace?

    @State private var position: MapCameraPosition
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(place: BirthPlace?) {
        self.place = place
        _position = State(initialValue: Self.camera(for: place))
    }

    var body: some View {
        Map(position: $position, interactionModes: []) {
            if let place {
                Marker(place.city, coordinate: Self.coordinate(place))
                    .tint(Color(hex: 0xE4C992))
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        .mapControls {}
        .environment(\.colorScheme, .dark)
        .safeAreaPadding(.bottom, 150)
        .overlay(dim)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: place) { _, newPlace in
            let next = Self.camera(for: newPlace)
            if reduceMotion {
                position = next
            } else {
                withAnimation(.easeInOut(duration: 0.95)) {
                    position = next
                }
            }
        }
    }

    /// Keeps the geography visible and pulls the brightness down so the map stays behind the form.
    private var dim: some View {
        ZStack {
            Color.black.opacity(0.46)
            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.42), location: 0),
                    .init(color: Color.black.opacity(0.12), location: 0.42),
                    .init(color: Color.black.opacity(0.38), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .allowsHitTesting(false)
    }

    private static func camera(for place: BirthPlace?) -> MapCameraPosition {
        let center: CLLocationCoordinate2D
        let distance: CLLocationDistance
        if let place {
            center = coordinate(place)
            distance = 34_000
        } else {
            center = CLLocationCoordinate2D(latitude: 28, longitude: 8)
            distance = 14_000_000
        }
        return .camera(MapCamera(centerCoordinate: center, distance: distance, heading: 0, pitch: 0))
    }

    private static func coordinate(_ place: BirthPlace) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
    }
}

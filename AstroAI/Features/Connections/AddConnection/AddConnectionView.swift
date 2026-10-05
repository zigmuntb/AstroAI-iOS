//
//  AddConnectionView.swift
//  AstroAI
//

import SwiftUI

struct AddConnectionView: View {
    @State private var viewModel: AddConnectionViewModel

    init(viewModel: AddConnectionViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.block) {
                intro
                identitySection
                coordinatesSection
                archetypeSnapshot
                privacyNote

                Button(action: viewModel.save) {
                    HStack(spacing: Spacing.sm) {
                        Text("Calculate Synastry Matrix")
                            .font(AppFont.headlineMedium)
                        Image(systemName: "infinity")
                    }
                }
                .buttonStyle(.astroPrimary)
                .disabled(!viewModel.canSave)
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .top) { header }
        .screenBackground()
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Eyebrow(text: "Fascicle IV · Relational Ephemeris")
                Text("Add Connection")
                    .font(AppFont.headlineMedium)
                    .foregroundStyle(AppColor.onSurface)
            }
            Spacer()
            Button(action: viewModel.close) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppColor.onSurface)
                    .frame(width: 36, height: 36)
                    .background(AppColor.surfaceContainerHigh, in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, Spacing.margin)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
        .background(AppColor.surface)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Who are you inviting into your celestial wheel?")
                .font(AppFont.headlineLarge)
                .foregroundStyle(AppColor.onSurface)
            Text("Synastry weighs the gravities between two planetary configurations. Exact birth coordinates illuminate ascendant axes, precise Moon degrees, and the intimate geometry of house overlays.")
                .font(AppFont.bodyLarge)
                .lineSpacing(3)
                .foregroundStyle(AppColor.onSurfaceVariant)
        }
    }

    // MARK: - Identity

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                FieldLabel(text: "Full or Chosen Name")
                HStack {
                    TextField("e.g. Julian Mercer", text: $viewModel.name)
                        .font(AppFont.headlineMedium)
                        .textContentType(.name)
                        .submitLabel(.done)
                    Image(systemName: "touchid")
                        .foregroundStyle(AppColor.outline)
                }
                .fieldBackground()
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                FieldLabel(text: "Sphere of Kinship")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.sm), GridItem(.flexible())], spacing: Spacing.sm) {
                    ForEach(Kinship.allCases) { kinship in
                        KinshipTile(kinship: kinship, isSelected: viewModel.kinship == kinship) {
                            viewModel.kinship = kinship
                        }
                    }
                }
            }
        }
        .card(.elevated, padding: Spacing.margin)
    }

    // MARK: - Coordinates

    private var coordinatesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    FieldLabel(text: "Solar Date of Birth")
                    Spacer()
                    Caption(text: "Gregorian Ephemeris")
                }
                HStack {
                    DatePicker("Date of birth", selection: $viewModel.birthDate, in: ...Date.now, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    Spacer()
                    Text(viewModel.sunSign.glyph)
                        .font(.system(size: 15))
                        .foregroundStyle(AppColor.dustyRose)
                    Image(systemName: "calendar")
                        .foregroundStyle(AppColor.onSurfaceVariant)
                }
                .fieldBackground()
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    FieldLabel(text: "Exact Sidereal Time")
                    Spacer()
                    Toggle(isOn: $viewModel.isTimeApproximate.animation()) {
                        Caption(text: "Time approximate")
                    }
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .tint(AppColor.primaryContainer)
                    .fixedSize()
                }
                HStack {
                    DatePicker("Time of birth", selection: $viewModel.birthTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    Spacer()
                    Image(systemName: "clock")
                        .foregroundStyle(AppColor.onSurfaceVariant)
                }
                .fieldBackground()
                .disabled(viewModel.isTimeApproximate)
                .opacity(viewModel.isTimeApproximate ? 0.4 : 1)

                if viewModel.isTimeApproximate {
                    Label("Without recorded minute, lunar positions will approximate around 12:00 Solar Noon default. House cusps and exact Rising axis will remain uncalculated.", systemImage: "info.circle")
                        .font(AppFont.bodySmall)
                        .foregroundStyle(AppColor.onSurfaceVariant)
                        .transition(.opacity)
                }
            }

            placeField
        }
        .card(.elevated, padding: Spacing.margin)
    }

    private var placeField: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                FieldLabel(text: "Natal Horizon (Place of Birth)")
                Spacer(minLength: Spacing.xs)
                if viewModel.selectedPlace != nil {
                    Caption(text: "Verified Observatory")
                }
            }
            HStack {
                TextField("Search city, district or country", text: $viewModel.placeQuery)
                    .font(AppFont.bodyLarge)
                    .textContentType(.addressCity)
                    .autocorrectionDisabled()
                if viewModel.isSearching {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: viewModel.selectedPlace == nil ? "magnifyingglass" : "checkmark.circle")
                        .foregroundStyle(AppColor.onSurfaceVariant)
                }
            }
            .fieldBackground()

            if let place = viewModel.selectedPlace {
                HStack {
                    Text(place.coordinates)
                    Spacer(minLength: Spacing.xs)
                    Text(place.timeZone)
                        .foregroundStyle(AppColor.secondary)
                        .multilineTextAlignment(.trailing)
                }
                .font(AppFont.labelMedium)
                .tracking(0.4)
                .foregroundStyle(AppColor.onSurfaceVariant)
                .padding(.horizontal, Spacing.xs)
            } else if !viewModel.placeResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(viewModel.placeResults) { place in
                        Button { viewModel.select(place) } label: {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundStyle(AppColor.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(place.city)
                                        .font(AppFont.bodyMedium.weight(.medium))
                                        .foregroundStyle(AppColor.onSurface)
                                    Text(place.region)
                                        .font(AppFont.bodySmall)
                                        .foregroundStyle(AppColor.onSurfaceVariant)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, Spacing.md)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        if place.id != viewModel.placeResults.last?.id {
                            HairlineDivider(inset: Spacing.md)
                        }
                    }
                }
                .card(.elevated, padding: 0)
            } else if viewModel.showsNoResults {
                Caption(text: "No matching places found")
                    .padding(.horizontal, Spacing.xs)
            }
        }
    }

    // MARK: - Snapshot & privacy

    private var archetypeSnapshot: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top) {
                Eyebrow(text: "Computed Archetype Snapshot")
                Spacer()
                Caption(text: "\(viewModel.sunSign.name) Sun")
            }
            HStack(spacing: Spacing.md) {
                Text(viewModel.sunSign.glyph)
                    .font(.system(size: 24))
                    .foregroundStyle(AppColor.dustyRose)
                    .frame(width: 56, height: 56)
                    .background(AppColor.primary, in: .circle)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(viewModel.archetypeTitle)
                        .font(AppFont.headlineMedium)
                        .foregroundStyle(AppColor.onSurface)
                    Text(viewModel.archetypeText)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(AppColor.onSurfaceVariant)
                }
            }
        }
        .card(.tinted, padding: Spacing.margin)
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "lock.open")
                .foregroundStyle(AppColor.secondary)
            Text("\(Text("Sacred Data Architecture:").fontWeight(.semibold).foregroundStyle(AppColor.onSurface)) Calculations run purely on-device. Astronomical coordinate ephemerides are shielded under local zero-knowledge secure enclave.")
                .font(AppFont.bodyMedium)
                .lineSpacing(3)
                .foregroundStyle(AppColor.onSurfaceVariant)
        }
        .card(.elevated)
    }
}

// MARK: - Pieces

private struct FieldLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(AppFont.labelMedium)
            .tracking(1.2)
            .foregroundStyle(AppColor.secondary)
    }
}

private struct Caption: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AppFont.labelMedium)
            .tracking(0.4)
            .foregroundStyle(AppColor.onSurfaceVariant)
    }
}

private struct KinshipTile: View {
    let kinship: Kinship
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(kinship.title)
                    .font(AppFont.bodyMedium.weight(.semibold))
                Text(kinship.caption)
                    .font(AppFont.bodyMedium)
                    .opacity(0.8)
            }
            .foregroundStyle(isSelected ? AppColor.onPrimary : AppColor.onSurface)
            .multilineTextAlignment(.leading)
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .background(isSelected ? AppColor.primaryContainer : AppColor.surfaceContainerLowest, in: panelShape(Radius.md))
            .cardEdge(radius: Radius.md, border: isSelected ? AppColor.champagne.opacity(0.7) : AppColor.outlineVariant, shadowOpacity: isSelected ? 0.1 : 0.06)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private extension View {
    func fieldBackground() -> some View {
        padding(.horizontal, Spacing.md + 4)
            .frame(minHeight: 56)
            .background(AppColor.surfaceContainerLowest, in: panelShape(Radius.md))
            .cardEdge(radius: Radius.md, shadowOpacity: 0)
    }
}

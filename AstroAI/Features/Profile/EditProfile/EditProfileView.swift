//
//  EditProfileView.swift
//  AstroAI
//

import PhotosUI
import SwiftUI

struct EditProfileView: View {
    @State private var viewModel: EditProfileViewModel
    @State private var pickerItem: PhotosPickerItem?
    @FocusState private var isNameFocused: Bool

    init(viewModel: EditProfileViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.block) {
                photoSection
                nameSection
                personalSection
            }
            .padding(.horizontal, Spacing.margin)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .top) { header }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PrimaryButton(title: "Save Changes", icon: nil, isLoading: viewModel.isSaving, action: viewModel.save)
                .disabled(!viewModel.canSave)
                .padding(.horizontal, Spacing.margin)
                .padding(.vertical, Spacing.md)
                .background(AppColor.surface)
        }
        .screenBackground()
        .onChange(of: pickerItem) { _, item in
            loadPhoto(from: item)
        }
        .alert("Profile", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Eyebrow(text: "Personal Signature")
                Text("Edit Profile")
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

    // MARK: - Photo

    private var photoSection: some View {
        VStack(spacing: Spacing.md) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(content: viewModel.avatar, size: 120)
                        .padding(4)
                        .overlay(Circle().stroke(AppColor.champagne.opacity(0.5), lineWidth: 1))
                        .overlay {
                            if viewModel.isLoadingPhoto {
                                ProgressView()
                                    .tint(AppColor.onPrimary)
                                    .frame(width: 120, height: 120)
                                    .background(.black.opacity(0.3), in: .circle)
                            }
                        }
                    Image(systemName: "camera")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColor.onPrimary)
                        .frame(width: 34, height: 34)
                        .background(AppColor.primaryContainer, in: .circle)
                        .overlay(Circle().stroke(AppColor.surface, lineWidth: 2))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choose profile photo")

            HStack(spacing: Spacing.lg) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label(viewModel.hasPhoto ? "Change Photo" : "Choose Photo", systemImage: "photo.on.rectangle")
                }
                if viewModel.hasPhoto {
                    Button(role: .destructive) {
                        pickerItem = nil
                        viewModel.removePhoto()
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
            .font(AppFont.labelLarge)
            .foregroundStyle(AppColor.primaryContainer)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Name

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Label("FULL OR CHOSEN NAME", systemImage: "person.text.rectangle")
                    .font(AppFont.labelLarge)
                    .tracking(0.6)
                    .foregroundStyle(AppColor.onSurface)
                Spacer()
                Text(viewModel.counterText)
                    .font(AppFont.labelMedium)
                    .foregroundStyle(AppColor.outline)
                    .monospacedDigit()
            }

            HStack(spacing: Spacing.md) {
                TextField("e.g. Elena", text: $viewModel.name)
                    .font(AppFont.headlineMedium)
                    .foregroundStyle(AppColor.onSurface)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($isNameFocused)
                    .onSubmit(viewModel.save)

                if !viewModel.name.isEmpty {
                    Button { viewModel.name = "" } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColor.onSurfaceVariant)
                            .frame(width: 28, height: 28)
                            .background(AppColor.surfaceContainerHigh, in: .circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear name")
                }
            }
            .padding(.horizontal, Spacing.md)
            .frame(height: 56)
            .background(AppColor.surfaceContainerLowest, in: .rect(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(isNameFocused ? AppColor.champagne : AppColor.outlineVariant, lineWidth: isNameFocused ? 1.5 : 1)
            )
            .animation(.easeInOut(duration: 0.2), value: isNameFocused)

            if let hint = viewModel.nameHint {
                Text(hint)
                    .font(AppFont.bodySmall)
                    .foregroundStyle(AppColor.error)
            }
        }
        .card(.elevated, padding: Spacing.md)
    }

    // MARK: - Personal Context

    private var personalSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Label("ABOUT YOU NOW", systemImage: "sparkles")
                    .font(AppFont.labelLarge)
                    .tracking(0.6)
                    .foregroundStyle(AppColor.onSurface)
                Text("Optional. Helps the Oracle tailor its answers to your situation.")
                    .font(AppFont.bodySmall)
                    .foregroundStyle(AppColor.onSurfaceVariant)
            }
            PersonalContextForm(context: $viewModel.personal)
        }
        .card(.elevated, padding: Spacing.md)
    }

    // MARK: - Helpers

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item else { return }
        viewModel.photoLoadingStarted()
        Task {
            let data = try? await item.loadTransferable(type: Data.self)
            viewModel.setPhoto(data)
        }
    }
}

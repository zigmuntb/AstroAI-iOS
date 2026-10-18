//
//  DateWheelColumn.swift
//  AstroAI
//

import SwiftUI

struct DateWheelChoice: Identifiable, Equatable {
    let value: Int
    let title: String
    var id: Int { value }
}

/// One vertical wheel. Rows snap to center, and neighbors fade as they leave the selection band.
struct DateWheelColumn: View {
    let choices: [DateWheelChoice]
    @Binding var selection: Int
    var accessibilityName: String
    var rowHeight: CGFloat
    var selectedSize: CGFloat

    @State private var position: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        choices: [DateWheelChoice],
        selection: Binding<Int>,
        accessibilityName: String,
        rowHeight: CGFloat,
        selectedSize: CGFloat
    ) {
        self.choices = choices
        self._selection = selection
        self.accessibilityName = accessibilityName
        self.rowHeight = rowHeight
        self.selectedSize = selectedSize
        // Leave the scroll target unset until after layout. Seeding it here is ignored
        // by the scroll view, and a later write of the same value then does nothing.
        self._position = State(initialValue: nil)
    }

    var body: some View {
        let scrollHeight = rowHeight * 5
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                ForEach(choices) { choice in
                    row(choice)
                        .frame(height: rowHeight)
                        .id(choice.id)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.vertical, rowHeight * 2, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $position, anchor: .center)
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: scrollHeight)
        .mask(fadeMask)
        .task(id: choices.map(\.id)) {
            align(to: selection, animated: false)
            // A second pass catches the case where the first assignment landed before layout.
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
            align(to: selection, animated: false)
        }
        .onChange(of: selection) { _, new in
            guard position != new else { return }
            align(to: new, animated: !reduceMotion)
        }
        .onChange(of: position) { _, new in
            guard let new, new != selection, choices.contains(where: { $0.id == new }) else { return }
            selection = new
            // The model clamps future dates and dates older than 112 years back into range.
            if selection != new {
                align(to: selection, animated: !reduceMotion)
            }
        }
        .onChange(of: choices.map(\.id)) { _, ids in
            guard let position, !ids.contains(position) else { return }
            align(to: selection, animated: false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityName)
        .accessibilityValue(currentTitle)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(1)
            case .decrement: step(-1)
            default: break
            }
        }
        .accessibilityHint("Swipe up or down to adjust")
    }

    private var currentTitle: String {
        choices.first { $0.value == selection }?.title ?? ""
    }

    private func row(_ choice: DateWheelChoice) -> some View {
        let selected = choice.value == selection
        return Text(choice.title)
            .font(.system(size: selectedSize, weight: selected ? .medium : .regular, design: .serif))
            .foregroundStyle(AppColor.onSurface)
            .lineLimit(1)
            .minimumScaleFactor(0.45)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 2)
            .scrollTransition(.interactive, axis: .vertical) { content, phase in
                let distance = min(abs(phase.value), 2.2)
                return content
                    .opacity(max(0.14, 1 - distance * 0.36))
                    .scaleEffect(max(0.58, 1 - distance * 0.18))
            }
            .accessibilityHidden(true)
    }

    private var fadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.18),
                .init(color: .black, location: 0.82),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func align(to value: Int, animated: Bool) {
        guard choices.contains(where: { $0.id == value }) else { return }
        let commit = {
            if animated {
                withAnimation(.snappy(duration: 0.28)) {
                    self.position = value
                }
            } else {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    self.position = value
                }
            }
        }
        // Writing the same id again does not move a scroll view that ignored the first one.
        if position == value {
            position = nil
            DispatchQueue.main.async(execute: commit)
        } else {
            commit()
        }
    }

    private func step(_ offset: Int) {
        guard let index = choices.firstIndex(where: { $0.value == selection }) else { return }
        let next = index + offset
        guard choices.indices.contains(next) else { return }
        selection = choices[next].value
    }
}

/// Day, month, and year wheels sharing one selection band.
struct BirthDateWheels: View {
    @Bindable var viewModel: DateOfBirthViewModel
    var height: CGFloat

    /// Label row plus the stack spacing, kept out of the five wheel rows.
    private var rowHeight: CGFloat { max((height - 18 - Spacing.sm) / 5, 1) }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: 0) {
                columnLabel("Day").frame(maxWidth: .infinity)
                columnLabel("Month").frame(maxWidth: .infinity)
                columnLabel("Year").frame(maxWidth: .infinity)
            }

            ZStack {
                selectionBand
                HStack(spacing: 0) {
                    DateWheelColumn(
                        choices: dayChoices,
                        selection: $viewModel.day,
                        accessibilityName: "Day",
                        rowHeight: rowHeight,
                        selectedSize: min(rowHeight * 0.52, 36)
                    )
                    .frame(maxWidth: .infinity)

                    DateWheelColumn(
                        choices: monthChoices,
                        selection: $viewModel.month,
                        accessibilityName: "Month",
                        rowHeight: rowHeight,
                        selectedSize: min(rowHeight * 0.40, 26)
                    )
                    .frame(maxWidth: .infinity)

                    DateWheelColumn(
                        choices: yearChoices,
                        selection: $viewModel.year,
                        accessibilityName: "Year",
                        rowHeight: rowHeight,
                        selectedSize: min(rowHeight * 0.46, 32)
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: rowHeight * 5)
        }
        .frame(height: height)
        .sensoryFeedback(.selection, trigger: viewModel.birthDate)
    }

    private var selectionBand: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppColor.champagne.opacity(0.7))
                .frame(height: 0.5)
            Spacer(minLength: 0)
            Rectangle()
                .fill(AppColor.champagne.opacity(0.7))
                .frame(height: 0.5)
        }
        .frame(height: rowHeight)
        .background(Color.black.opacity(0.28))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func columnLabel(_ title: String) -> some View {
        Text(title)
            .font(AppFont.labelSmall)
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(AppColor.onSurfaceVariant)
            .accessibilityHidden(true)
    }

    private var dayChoices: [DateWheelChoice] {
        viewModel.selectableDays.map { value in
            DateWheelChoice(value: value, title: formatted(value))
        }
    }

    private var monthChoices: [DateWheelChoice] {
        viewModel.selectableMonths.map { value in
            DateWheelChoice(value: value, title: viewModel.monthTitle(value))
        }
    }

    private var yearChoices: [DateWheelChoice] {
        viewModel.selectableYears.map { value in
            DateWheelChoice(value: value, title: formatted(value))
        }
    }

    private func formatted(_ value: Int) -> String {
        value.formatted(.number.grouping(.never))
    }
}

//
//  RecipeFormComponents.swift
//  CookieNotes
//

import SwiftUI

struct RecipeFormSection<Content: View>: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.paddingMedium) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(AppTheme.sectionLabel)
                    .foregroundStyle(AppTheme.burntOrange)
                Spacer(minLength: 8)
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .font(AppTheme.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.burntOrange)
                        .frame(minHeight: 44)
                }
            }
            content()
        }
        .sectionSurface()
    }
}

struct RecipeEditableLines: View {
    let title: String
    let addTitle: String
    let placeholder: String
    @Binding var lines: [EditableLine]
    var numbered: Bool = false
    var illustrated: Bool = false
    var onPickIllustration: ((UUID) -> Void)? = nil

    @FocusState private var focusedLineID: UUID?

    var body: some View {
        RecipeFormSection(
            title: title,
            actionTitle: addTitle,
            action: addLine
        ) {
            if lines.isEmpty {
                Text("Tap \(addTitle) to start writing.")
                    .font(AppTheme.caption)
                    .foregroundStyle(AppTheme.tertiaryText)
            }

            ForEach($lines) { $line in
                HStack(alignment: .top, spacing: AppTheme.paddingSmall) {
                    if illustrated {
                        Button {
                            focusedLineID = nil
                            onPickIllustration?(line.id)
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(AppTheme.parchment)
                                    .frame(width: 44, height: 44)
                                if !line.iconID.isEmpty {
                                    FoodIconView(iconID: line.iconID, size: 36)
                                } else {
                                    Image(systemName: "plus")
                                        .foregroundStyle(AppTheme.burntOrange)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Choose ingredient")
                    } else if numbered {
                        Text("\(lineNumber(for: line.id)).")
                            .font(AppTheme.body.weight(.bold))
                            .foregroundStyle(AppTheme.burntOrange)
                            .frame(width: 28, alignment: .leading)
                            .padding(.top, 14)
                    }

                    TextField(placeholder, text: $line.text, axis: .vertical)
                        .textFieldStyle(CustomTextFieldStyle())
                        .lineLimit(numbered ? 2...8 : 1...3)
                        .textInputAutocapitalization(numbered ? .sentences : .words)
                        .focused($focusedLineID, equals: line.id)
                        .submitLabel(.next)

                    if lines.count > 1 {
                        Button {
                            removeLine(id: line.id)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(AppTheme.error.opacity(0.85))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(placeholder.lowercased())")
                    }
                }
            }
        }
        .onAppear {
            if lines.isEmpty {
                lines = [EditableLine(text: "")]
            }
        }
    }

    private func addLine() {
        let line = EditableLine(text: "")
        lines.append(line)
        DispatchQueue.main.async {
            focusedLineID = line.id
        }
    }

    private func removeLine(id: UUID) {
        // Clear focus before mutating so TextField bindings are not torn down mid-update.
        focusedLineID = nil
        DispatchQueue.main.async {
            guard lines.count > 1 else { return }
            lines.removeAll { $0.id == id }
            if lines.isEmpty {
                lines = [EditableLine(text: "")]
            }
        }
    }

    private func lineNumber(for id: UUID) -> Int {
        (lines.firstIndex(where: { $0.id == id }) ?? 0) + 1
    }
}

struct RecipeTimeRow: View {
    @Binding var prepTime: Int
    @Binding var cookTime: Int
    @Binding var servings: Int

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.paddingSmall) {
            TimeInputView(title: "Prep", value: $prepTime, step: 1)
            TimeInputView(title: "Cook", value: $cookTime, step: 1)
            TimeInputView(title: "Serves", value: $servings, unit: "", step: 1, maxValue: RecipeInputLimits.maxServings)
        }
    }
}

struct TimeInputView: View {
    let title: String
    @Binding var value: Int
    var unit: String = "min"
    var step: Int = 1
    var maxValue: Int = RecipeInputLimits.maxMinutes

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.paddingSmall) {
            Text(title)
                .font(AppTheme.sectionLabel)
                .foregroundStyle(AppTheme.secondaryText)

            HStack(spacing: 0) {
                Button {
                    value = Swift.max(0, value - step)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(value <= 0 ? AppTheme.tertiaryText : AppTheme.burntOrange)
                        .frame(width: 40, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(value <= 0)

                VStack(spacing: 0) {
                    Text("\(value)")
                        .font(AppTheme.caption.weight(.bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(AppTheme.smallCaption.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .multilineTextAlignment(.center)

                Button {
                    value = Swift.min(maxValue, value + step)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(value >= maxValue ? AppTheme.tertiaryText : AppTheme.burntOrange)
                        .frame(width: 40, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(value >= maxValue)
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .background(AppTheme.surfaceBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

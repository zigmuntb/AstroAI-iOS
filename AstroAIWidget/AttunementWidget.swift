//
//  AttunementWidget.swift
//  AstroAIWidget
//

import WidgetKit
import SwiftUI

private struct AttunementSnapshot: Codable {
    var moonGlyph: String
    var moonLine: String
    var transitLine: String
    var updated: Date
}

private enum SnapshotStore {
    static let suite = "group.com.BogdanArsenkin.AstroAI"
    static let key = "attunement.snapshot"

    static func load() -> AttunementSnapshot? {
        guard let data = UserDefaults(suiteName: suite)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(AttunementSnapshot.self, from: data)
    }
}

private struct AttunementEntry: TimelineEntry {
    let date: Date
    let moonGlyph: String
    let moonLine: String
    let transitLine: String

    static let placeholder = AttunementEntry(
        date: .now,
        moonGlyph: "☽",
        moonLine: "Moon in Scorpio",
        transitLine: "Venus △ natal Moon"
    )

    static func current() -> AttunementEntry {
        guard let snapshot = SnapshotStore.load() else {
            return AttunementEntry(date: .now, moonGlyph: "☽", moonLine: "AstroAI", transitLine: "Open the app to attune")
        }
        return AttunementEntry(
            date: snapshot.updated,
            moonGlyph: snapshot.moonGlyph,
            moonLine: snapshot.moonLine,
            transitLine: snapshot.transitLine
        )
    }
}

private struct AttunementProvider: TimelineProvider {
    func placeholder(in context: Context) -> AttunementEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (AttunementEntry) -> Void) {
        completion(context.isPreview ? .placeholder : .current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AttunementEntry>) -> Void) {
        let entry = AttunementEntry.current()
        let next = Calendar.current.date(byAdding: .hour, value: 4, to: .now) ?? .now.addingTimeInterval(4 * 3_600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

private struct AttunementWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AttunementEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            Text(entry.moonGlyph)
                .font(.title2)
                .widgetAccentable()
        case .accessoryInline:
            Text("\(entry.moonGlyph) \(entry.moonLine)")
        default:
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.moonLine)
                    .font(.headline)
                    .widgetAccentable()
                Text(entry.transitLine)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct AttunementWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Attunement", provider: AttunementProvider()) { entry in
            AttunementWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Morning attunement")
        .description("The Moon sign and the tightest transit to your chart.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct AttunementBundle: WidgetBundle {
    var body: some Widget {
        AttunementWidget()
    }
}

import WidgetKit
import SwiftUI

struct ZaluzkyLaunchComplication: Widget {
    let kind: String = "ZaluzkyLaunch"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LaunchProvider()) { _ in
            LaunchComplicationView()
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Žaluzky")
        .description("Spustit ovládání žaluzií jedním tapnutím.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

struct LaunchEntry: TimelineEntry {
    let date: Date
}

struct LaunchProvider: TimelineProvider {
    func placeholder(in context: Context) -> LaunchEntry { LaunchEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (LaunchEntry) -> Void) {
        completion(LaunchEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<LaunchEntry>) -> Void) {
        completion(Timeline(entries: [LaunchEntry(date: .now)], policy: .never))
    }
}

struct LaunchComplicationView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                BlindsGlyph()
                    .font(.system(size: 18, weight: .semibold))
            }
        case .accessoryCorner:
            BlindsGlyph()
                .font(.system(size: 18, weight: .semibold))
                .widgetLabel("Žaluzky")
        case .accessoryRectangular:
            HStack(spacing: 8) {
                BlindsGlyph()
                    .font(.system(size: 22, weight: .semibold))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Žaluzky").font(.headline)
                    Text("Tap to open").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        case .accessoryInline:
            Label("Žaluzky", systemImage: "blinds.horizontal.closed")
        default:
            EmptyView()
        }
    }
}

private struct BlindsGlyph: View {
    var body: some View {
        Image(systemName: "blinds.horizontal.closed")
    }
}

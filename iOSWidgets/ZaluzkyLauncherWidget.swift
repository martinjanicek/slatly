import WidgetKit
import SwiftUI

/// Minimal launcher widget: shows the app icon + tab shortcuts. Tap opens the
/// app via a deep link. The richer "scene runner" widget that executes a scene
/// inline lives behind App Group + iCloud entitlement work — see README for the
/// release checklist.
struct ZaluzkyLauncherWidget: Widget {
    let kind: String = "ZaluzkyLauncher"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LauncherProvider()) { _ in
            LauncherWidgetView()
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Slatly")
        .description("Quick access to your blinds and scenes.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct LauncherEntry: TimelineEntry {
    let date: Date
}

struct LauncherProvider: TimelineProvider {
    func placeholder(in context: Context) -> LauncherEntry { LauncherEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (LauncherEntry) -> Void) {
        completion(LauncherEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<LauncherEntry>) -> Void) {
        completion(Timeline(entries: [LauncherEntry(date: .now)], policy: .never))
    }
}

struct LauncherWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            small
        case .systemMedium:
            medium
        default:
            small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "blinds.horizontal.closed")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.tint)
            Spacer(minLength: 0)
            Text("Slatly")
                .font(.headline)
            Text("Tap to open")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: "zaluzky://blinds"))
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "blinds.horizontal.closed")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Slatly").font(.headline)
                    Text("Quick access")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                Link(destination: URL(string: "zaluzky://blinds")!) {
                    label(icon: "rectangle.3.group.fill", text: "Blinds")
                }
                Link(destination: URL(string: "zaluzky://scenes")!) {
                    label(icon: "sparkles", text: "Scenes")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: "zaluzky://blinds"))
    }

    private func label(icon: String, text: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
            Text(text)
                .font(.subheadline.weight(.medium))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.tint.opacity(0.18))
        )
        .foregroundStyle(.tint)
    }
}

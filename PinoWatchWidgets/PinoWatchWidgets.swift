import SwiftUI
import WidgetKit

private let pinoFamilies: [WidgetFamily] = [
    .accessoryCircular,
    .accessoryCorner,
    .accessoryInline,
    .accessoryRectangular
]

struct WidgetSnapshot: Codable {
    var count: Int
    var lastName: String
    var lastSymbol: String
}

struct PinEntry: TimelineEntry {
    let date: Date
    let count: Int
    let lastName: String
    let lastSymbol: String
}

struct PinProvider: TimelineProvider {
    func placeholder(in context: Context) -> PinEntry {
        PinEntry(date: .now, count: 0, lastName: "", lastSymbol: "📍")
    }

    func getSnapshot(in context: Context, completion: @escaping (PinEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PinEntry>) -> Void) {
        completion(Timeline(entries: [entry()], policy: .after(.now.addingTimeInterval(15 * 60))))
    }

    private func entry() -> PinEntry {
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.it.devben.pino"
        )?.appendingPathComponent("widget.json"),
              let data = try? Data(contentsOf: url),
              let snap = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return PinEntry(date: .now, count: 0, lastName: "", lastSymbol: "📍")
        }
        return PinEntry(date: .now, count: snap.count, lastName: snap.lastName, lastSymbol: snap.lastSymbol)
    }
}

struct SaveWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "it.devben.pino.save", provider: PinProvider()) { entry in
            SaveWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    AccessoryWidgetBackground()
                }
        }
        .configurationDisplayName("Save")
        .description("Save a pin.")
        .supportedFamilies(pinoFamilies)
    }
}

struct LastPinWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "it.devben.pino.find", provider: PinProvider()) { entry in
            LastPinWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    AccessoryWidgetBackground()
                }
        }
        .configurationDisplayName("Find")
        .description("Find your last pin.")
        .supportedFamilies(pinoFamilies)
    }
}

struct SaveWidgetView: View {
    var entry: PinEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Text("Save pin")
            case .accessoryCorner:
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .widgetLabel("Save")
            default:
                VStack(spacing: 2) {
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                    Text("Save")
                        .font(.caption2)
                }
            }
        }
        .widgetURL(URL(string: "pino://save"))
    }
}

struct LastPinWidgetView: View {
    var entry: PinEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if entry.count == 0 {
                switch family {
                case .accessoryInline:
                    Text("PinO")
                case .accessoryCorner:
                    Text("📍")
                        .widgetLabel("PinO")
                case .accessoryRectangular:
                    VStack(alignment: .leading) {
                        Text("PinO")
                            .font(.headline)
                        Text("Tap to save")
                            .font(.caption)
                    }
                default:
                    Text("📍")
                }
            } else {
                switch family {
                case .accessoryInline:
                    Text("Find \(entry.lastName)")
                case .accessoryCorner:
                    Text(entry.lastSymbol)
                        .widgetLabel(entry.lastName)
                case .accessoryRectangular:
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.lastSymbol + " " + entry.lastName)
                            .font(.headline)
                            .lineLimit(1)
                        Text("Find")
                            .font(.caption)
                    }
                default:
                    VStack(spacing: 1) {
                        Text(entry.lastSymbol)
                        Text("\(entry.count)")
                            .font(.caption2)
                    }
                }
            }
        }
        .widgetURL(URL(string: entry.count == 0 ? "pino://save" : "pino://find"))
    }
}

@main
struct PinoWatchWidgets: WidgetBundle {
    var body: some Widget {
        SaveWidget()
        LastPinWidget()
    }
}

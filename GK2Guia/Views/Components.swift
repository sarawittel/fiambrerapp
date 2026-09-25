import GK2Core
import SwiftUI

struct Panel<Content: View>: View {
    var title: String?
    var style: BoxStyle = .wood
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.pixelTitle(11))
                    .foregroundStyle(style == .parchment ? Theme.parchmentInk : Theme.candle)
                    .shadow(color: style == .parchment ? .clear : Theme.outline, radius: 0, x: 2, y: 2)
            }
            content()
        }
        .font(.pixelBody())
        .padding(16 + Theme.px)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pixelBox(style)
    }
}

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.pixelTitle(10))
            .padding(.top, 10)
    }
}

struct Tag: View {
    let text: String
    var highlighted = false
    init(_ text: String, highlighted: Bool = false) {
        self.text = text
        self.highlighted = highlighted
    }

    var body: some View {
        Text(text)
            .font(.pixelBody(20))
            .padding(.horizontal, 8)
            .padding(.vertical, 1)
            .foregroundStyle(highlighted ? AnyShapeStyle(Theme.parchmentInk) : AnyShapeStyle(.primary))
            .background(highlighted ? AnyShapeStyle(Theme.moss) : AnyShapeStyle(.quinary))
            .overlay(Rectangle().strokeBorder(highlighted ? AnyShapeStyle(Theme.outline) : AnyShapeStyle(.tertiary), lineWidth: 2))
    }
}

struct NoteView: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Theme.candleDark.frame(width: Theme.px + 1)
            Text(text).foregroundStyle(Theme.parchmentMuted)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Objeto con icono. Si es fabricable, lleva a su receta.
struct ItemChip: View {
    let itemId: String
    var qty: Int?
    @Environment(AppState.self) private var state
    @Environment(Router.self) private var router

    var body: some View {
        if let recipe = state.data.recipe(producing: itemId) {
            Button { router.openRecipe(recipe.id) } label: { label(link: true) }
                .buttonStyle(.plain)
                .help("Ver receta")
        } else {
            label(link: false)
        }
    }

    private func label(link: Bool) -> some View {
        let item = state.data.item(itemId)
        return HStack(spacing: 6) {
            PixelIcon(name: item?.icon ?? "skull", size: 24)
            Text(item?.name ?? itemId)
            if let qty {
                Text("×\(qty)").foregroundStyle(Theme.blood)
            }
            if link { Text("›").foregroundStyle(.secondary) }
        }
        .font(.pixelBody(21))
        .padding(.vertical, 2)
        .padding(.leading, 4)
        .padding(.trailing, 10)
        .background(.quinary)
        .overlay(Rectangle().strokeBorder(.tertiary, lineWidth: 2))
        .contentShape(Rectangle())
    }
}

struct ChipFlow: View {
    let itemIds: [String]

    var body: some View {
        FlowLayout {
            ForEach(itemIds, id: \.self) { ItemChip(itemId: $0) }
        }
    }
}

/// Fila de lista con icono, título y subtítulo.
struct ListRow: View {
    let icon: String
    let title: String
    var subtitle: String?
    var badge: String?
    var selected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                PixelIcon(name: icon, size: 32)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(.pixelBody(23))
                    if let subtitle {
                        Text(subtitle).font(.pixelBody(18)).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 4)
                if let badge { Tag(badge, highlighted: true) }
                Text("›").foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background {
                if selected {
                    Color.clear.pixelBox(.woodSelected, edge: Theme.candle)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct TodayBadge: View {
    @Environment(AppState.self) private var state
    @Environment(Router.self) private var router

    var body: some View {
        Button { router.tab = .calendar } label: {
            HStack(spacing: 6) {
                PixelIcon(name: state.todayDay.icon, size: 24)
                Text("Hoy: \(state.todayDay.short)")
            }
        }
        .buttonStyle(.pixel(.wood, compact: true))
        .help("Cambiar día")
    }
}

/// La semana, marcando los días en que aparece un personaje.
struct DayBadges: View {
    let active: [String]
    @Environment(AppState.self) private var state

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(state.data.days) { day in
                let on = active.isEmpty || active.contains(day.id)
                HStack(spacing: 6) {
                    PixelIcon(name: day.icon, size: 16)
                    Text(day.short).font(.pixelBody(20))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(day.id == state.today ? Theme.candle.opacity(0.3) : .clear)
                .overlay(Rectangle().strokeBorder(on ? Color(hexString: day.color) : Theme.parchmentInk.opacity(0.2), lineWidth: 3))
                .opacity(on ? 1 : 0.35)
                .accessibilityLabel("\(day.name): \(on ? "sí" : "no")")
            }
        }
    }
}

struct PixelTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        // Placeholder propio: el prompt del sistema ignora el color en macOS
        TextField(placeholder, text: $text, prompt: Text(""))
        .textFieldStyle(.plain)
        .background(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder).foregroundStyle(Theme.parchmentMuted).allowsHitTesting(false)
            }
        }
        .font(.pixelBody(22))
        .foregroundStyle(Theme.parchmentInk)
        .padding(.horizontal, 10 + Theme.px)
        .padding(.vertical, 6 + Theme.px)
        .pixelBox(.field)
        #if os(iOS)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        #endif
    }
}

/// − valor +, con el valor editable a mano.
struct CountField: View {
    let value: Int
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button("−") { onChange(value - 1) }
                .buttonStyle(.pixel(.button, compact: true))
                .accessibilityLabel("Menos")
            TextField("", value: Binding(get: { value }, set: { onChange($0) }), format: .number)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .font(.pixelBody(22))
                .foregroundStyle(Theme.parchmentInk)
                .frame(width: 40)
                .padding(.vertical, 2 + Theme.px)
                .pixelBox(.field)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
            Button("+") { onChange(value + 1) }
                .buttonStyle(.pixel(.button, compact: true))
                .accessibilityLabel("Más")
        }
    }
}

struct PixelCheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 10) {
                Text(configuration.isOn ? "✓" : " ")
                    .font(.pixelBody(22))
                    .frame(width: 18, height: 18)
                    .padding(Theme.px)
                    .pixelBox(.field)
                configuration.label
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SampleDataNotice: View {
    var body: some View {
        Text("! Datos de ejemplo – edita los JSON de GK2Core/Resources con la información real del juego.")
            .font(.pixelBody(18))
            .foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

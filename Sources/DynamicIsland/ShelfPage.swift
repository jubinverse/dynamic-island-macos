import SwiftUI

struct ShelfPage: View {
    @ObservedObject var shelf: ShelfStore
    let isDropTargeted: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isDropTargeted ? Color.accentColor.opacity(0.14) : Color.white.opacity(0.04))
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .foregroundStyle(isDropTargeted ? Color.accentColor : Color.white.opacity(0.16))

            if shelf.items.isEmpty {
                VStack(spacing: Island.tightGap) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(isDropTargeted ? Color.accentColor : Island.tertiary)
                        .symbolEffect(.bounce, value: isDropTargeted)
                        .padding(.bottom, 4)
                    Text("Drop Files Here")
                        .font(Island.headline)
                        .foregroundStyle(Island.primary)
                    Text("Keep files handy and drag them out when you need them.")
                        .font(Island.body)
                        .foregroundStyle(Island.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("\(shelf.items.count) Item\(shelf.items.count == 1 ? "" : "s")")
                            .font(Island.caption)
                            .foregroundStyle(Island.tertiary)
                        Spacer()
                        Button("Clear All", action: shelf.clear)
                            .buttonStyle(.plain)
                            .font(Island.caption)
                            .foregroundStyle(Island.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(shelf.items, id: \.self) { url in
                                ShelfItemView(url: url, shelf: shelf)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }
            }
        }
    }
}

private struct ShelfItemView: View {
    let url: URL
    @ObservedObject var shelf: ShelfStore
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 44, height: 44)
            Text(url.lastPathComponent)
                .font(.system(size: 10))
                .foregroundStyle(Island.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .truncationMode(.middle)
                .frame(width: 72, height: 24, alignment: .top)
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(hovering ? Island.fill : .clear))
        .overlay(alignment: .topTrailing) {
            if hovering {
                Button {
                    shelf.remove(url)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.black, .white.opacity(0.85))
                }
                .buttonStyle(.plain)
                .offset(x: 2, y: -2)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { shelf.open(url) }
        .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
        .contextMenu {
            Button("Open") { shelf.open(url) }
            Button("Show in Finder") { shelf.revealInFinder(url) }
            Divider()
            Button("Remove from Shelf") { shelf.remove(url) }
        }
        .help(url.path)
    }
}

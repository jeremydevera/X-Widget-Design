import SwiftUI

let brandName = "xcode"  // display brand only — project/bundle stays "Islet"

struct ContentView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                BrandHeader()
                Divider().background(Theme.line)
                StickyPreviewArea()
                FilterChipsBar()
                Divider().background(Theme.line)
                DesignList()
            }
        }
    }
}

// MARK: - Brand header

struct BrandHeader: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: 4) {
                Text("▸").font(Theme.mono(20)).foregroundStyle(Theme.hi)
                Text(brandName).font(Theme.mono(20, weight: .bold)).foregroundStyle(Theme.text)
            }
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(Theme.hi).frame(width: 6, height: 6)
                Text("LIVE").font(Theme.mono(10, weight: .medium)).foregroundStyle(Theme.hi).tracking(1.5)
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .overlay(Rectangle().stroke(Theme.line3))
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

// MARK: - Sticky preview area

struct StickyPreviewArea: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(focusedDesign?.name ?? "—")
                        .font(Theme.mono(14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text(focusedDesign?.category ?? "—")
                        .font(Theme.mono(9.5, weight: .medium))
                        .foregroundStyle(Theme.text3).tracking(1.5)
                }
                Spacer()
                StateTag(applied: focusedDesign?.id == store.appliedId)
            }

            PreviewFrame()
                .frame(height: 156)

            HStack(spacing: 8) {
                SegmentedSizeToggle()
                ApplyButton()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Theme.bg)
    }

    private var focusedDesign: Design? {
        DesignCatalog.byId(store.focusedId)
    }
}

struct StateTag: View {
    let applied: Bool
    var body: some View {
        Text(applied ? "APPLIED" : "PREVIEWING")
            .font(Theme.mono(9, weight: applied ? .bold : .medium))
            .tracking(1.5)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .foregroundStyle(applied ? .black : Theme.text3)
            .background(applied ? Theme.hi : Color.clear)
            .overlay(Rectangle().stroke(applied ? Theme.hi : Theme.line3))
    }
}

// MARK: - Preview frame (the dark phone-top with the centered Dynamic Island)

struct PreviewFrame: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color(hex: 0x1C1C1C), Color(hex: 0x0D0D0D)],
                center: .top, startRadius: 10, endRadius: 240
            )
            DesignView(designId: store.focusedId, size: store.size, ctx: store.ctx)
                .id(store.focusedId)        // force re-mount on change for animation
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .animation(.easeOut(duration: 0.18), value: store.focusedId)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.size)
        }
        .clipShape(.rect(topLeadingRadius: 22, topTrailingRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22).stroke(Theme.line2, lineWidth: 1)
        )
        .background(Theme.surface)
    }
}

// MARK: - Size toggle + Apply

struct SegmentedSizeToggle: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        HStack(spacing: 0) {
            ForEach(SizeMode.allCases) { mode in
                Button {
                    store.size = mode
                } label: {
                    Text(mode.label)
                        .font(Theme.mono(11, weight: store.size == mode ? .bold : .medium))
                        .tracking(1.5)
                        .foregroundStyle(store.size == mode ? .black : Theme.text3)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(store.size == mode ? Theme.hi : Color.clear)
                }
                .buttonStyle(.plain)
                if mode == .short { Divider().frame(height: 32).background(Theme.line2) }
            }
        }
        .overlay(Rectangle().stroke(Theme.line2))
        .frame(maxWidth: .infinity)
    }
}

struct ApplyButton: View {
    @EnvironmentObject var store: AppStore

    private var isApplied: Bool { store.focusedId == store.appliedId }

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { store.apply() }
        } label: {
            Text(isApplied ? "✓ applied" : "apply")
                .font(Theme.mono(11, weight: .bold))
                .tracking(1)
                .foregroundStyle(isApplied ? Theme.hi : .black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isApplied ? Color.clear : Theme.hi)
                .overlay(
                    Rectangle().stroke(isApplied ? Theme.hi : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(isApplied)
    }
}

// MARK: - Filter chips

struct FilterChipsBar: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Chip(label: "ALL", count: DesignCatalog.all.count, on: store.filter == .all) {
                    store.filter = .all
                }
                ForEach(DesignCatalog.categories, id: \.0) { (cat, n) in
                    Chip(label: cat, count: n, on: store.filter == .category(cat)) {
                        store.filter = .category(cat)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .background(Theme.bg)
    }
}

struct Chip: View {
    let label: String
    let count: Int
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(label).font(Theme.mono(10, weight: on ? .bold : .medium)).tracking(1)
                Text("\(count)").font(Theme.mono(9, weight: .medium))
                    .foregroundStyle(on ? Color.black.opacity(0.55) : Theme.text4)
            }
            .foregroundStyle(on ? .black : Theme.text2)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(on ? Theme.hi : Color.clear)
            .overlay(Rectangle().stroke(on ? Theme.hi : Theme.line2))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Design list (scroll-driven preview)

struct DesignList: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if case .all = store.filter {
                        ForEach(DesignCatalog.categories, id: \.0) { (cat, n) in
                            CategoryHeader(name: cat, count: n)
                            ForEach(DesignCatalog.all.filter { $0.category == cat }) { d in
                                DesignRow(design: d).id(d.id)
                            }
                        }
                    } else {
                        ForEach(DesignCatalog.filtered(store.filter)) { d in
                            DesignRow(design: d).id(d.id)
                        }
                    }
                    Color.clear.frame(height: 80)
                }
                .padding(.horizontal, 20)
            }
            .background(Theme.bg)
            // Scroll-driven focus is approximated by tap.
            // In SwiftUI a proper "scroll position observer" requires GeometryReader per row;
            // tapping a row is the canonical iOS interaction anyway.
        }
    }
}

struct CategoryHeader: View {
    let name: String
    let count: Int
    var body: some View {
        HStack(spacing: 10) {
            Text("— \(name)").font(Theme.mono(9.5, weight: .semibold))
                .tracking(2).foregroundStyle(Theme.text4)
            Rectangle().fill(Theme.line).frame(height: 1)
            Text("\(count)").font(Theme.mono(9, weight: .medium)).foregroundStyle(Theme.text3)
        }
        .padding(.top, 16).padding(.bottom, 8)
    }
}

struct DesignRow: View {
    let design: Design
    @EnvironmentObject var store: AppStore

    private var isFocused: Bool { design.id == store.focusedId }
    private var isApplied: Bool { design.id == store.appliedId }

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) {
                store.focusedId = design.id
            }
        } label: {
            HStack(spacing: 14) {
                // Mini island preview
                ZStack {
                    Capsule().fill(.black).frame(height: 30)
                    DesignView(designId: design.id, size: .short, ctx: store.ctx)
                        .scaleEffect(0.65)
                        .frame(maxWidth: 110, maxHeight: 30)
                        .clipped()
                }
                .frame(width: 110, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(design.name)
                            .font(Theme.mono(13, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                        if isApplied {
                            Text("APPLIED")
                                .font(Theme.mono(8.5, weight: .bold)).tracking(1)
                                .foregroundStyle(.black)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Theme.hi)
                        }
                    }
                    Text(design.category)
                        .font(Theme.mono(10, weight: .medium))
                        .foregroundStyle(Theme.text3).tracking(0.5)
                }

                Spacer()

                Text("›").font(Theme.mono(18))
                    .foregroundStyle(isFocused ? Theme.hi : Theme.text3)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 4)
            .overlay(alignment: .leading) {
                if isFocused {
                    Rectangle().fill(Theme.hi).frame(width: 2)
                        .padding(.leading, -4)
                }
            }
            .background(isFocused ? Theme.surface2 : Color.clear)
            .overlay(
                Rectangle().fill(Theme.line).frame(height: 1),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ContentView().environmentObject(AppStore())
}

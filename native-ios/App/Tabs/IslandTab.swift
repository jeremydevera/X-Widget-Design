// IslandTab · design list with chip filter, search, and detail screen
//
// Wire up to LiveActivityManager.applyDesign(...) on Apply for real
// Live Activity rendering on the Dynamic Island.

import SwiftUI

struct IslandTab: View {
    @Environment(\.palette) var p
    @EnvironmentObject var state: AppState
    @EnvironmentObject var metrics: DeviceMetrics
    @State private var openDesign: Design? = nil
    @State private var searchOpen: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            TabHeader(title: "dynamic island studio",
                      subtitle: "\(filteredDesigns.count) designs · tap to edit")
            chipRow
            if searchOpen {
                searchBar.padding(.horizontal, 20).padding(.vertical, 6)
            }
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredDesigns, id: \.id) { d in
                        designRow(d)
                    }
                    Color.clear.frame(height: 24)
                }
            }
        }
        .sheet(item: $openDesign) { d in
            DesignDetailSheet(design: d)
                .environmentObject(state)
                .environmentObject(metrics)
                .environment(\.palette, p)
        }
    }

    private var filteredDesigns: [Design] {
        var pool = DesignCatalog.all
        if state.filter != "ALL" {
            pool = pool.filter { $0.category.rawValue == state.filter }
        }
        let q = state.query.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            pool = pool.filter { $0.name.lowercased().contains(q) || $0.category.rawValue.lowercased().contains(q) }
        }
        return pool
    }

    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Button { searchOpen.toggle() } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .padding(.vertical, 9).padding(.horizontal, 11)
                        .overlay(Rectangle().stroke(searchOpen ? p.hi : p.line2))
                        .foregroundStyle(searchOpen ? p.bg : p.text2)
                        .background(searchOpen ? p.hi : .clear)
                }.buttonStyle(.plain)
                chip("ALL", value: "ALL")
                ForEach(DesignCategory.allCases) { c in chip(c.rawValue, value: c.rawValue) }
            }
            .padding(.horizontal, 20).padding(.vertical, 8)
        }
        .background(p.bg)
        .overlay(alignment: .bottom) { Rectangle().frame(height: 1).foregroundStyle(p.line) }
    }
    private func chip(_ label: String, value: String) -> some View {
        let on = state.filter == value
        let count = value == "ALL"
            ? DesignCatalog.all.count
            : DesignCatalog.all.filter { $0.category.rawValue == value }.count
        return Button { state.filter = value } label: {
            HStack(spacing: 6) {
                Text(label).font(.system(size: 12, weight: on ? .bold : .semibold, design: .monospaced))
                Text("\(count)").font(.system(size: 11, design: .monospaced)).opacity(0.6)
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(on ? p.hi : p.bg)
            .foregroundStyle(on ? p.bg : p.text2)
            .overlay(Rectangle().stroke(on ? p.hi : p.line2, lineWidth: 1))
        }.buttonStyle(.plain)
    }
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(p.text3)
            TextField("search designs…", text: $state.query)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(p.surface)
        .overlay(Rectangle().stroke(p.line2, lineWidth: 1))
    }

    private func designRow(_ d: Design) -> some View {
        let isApplied = state.appliedDesignId == d.id
        let edit = state.edit(for: d.id)
        return Button { openDesign = d } label: {
            HStack(spacing: 14) {
                MiniIslandPreview {
                    DesignView(design: d, context: contextFromMetrics(), size: .short, edit: edit)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(d.name).font(.system(size: 13, weight: .semibold))
                        if isApplied {
                            Text("APPLIED").font(.system(size: 8.5, weight: .bold, design: .monospaced)).tracking(1)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(p.hi).foregroundStyle(p.bg)
                        }
                    }
                    if state.prefs.showCategoryTags {
                        Text(d.category.rawValue).font(.system(size: 10, design: .monospaced)).foregroundStyle(p.text3)
                    }
                }
                Spacer(minLength: 0)
                RowChevron()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())  // makes the whole row tappable, not just visible content
            .overlay(alignment: .bottom) { Rectangle().frame(height: 1).foregroundStyle(p.line) }
            .padding(.horizontal, 20)
        }.buttonStyle(.plain)
    }

    private func contextFromMetrics() -> RenderContext {
        var ctx = RenderContext()
        ctx.cpu = Int(metrics.cpu)
        ctx.fps = metrics.refreshHz
        ctx.memUsedGB = metrics.memUsedGB
        ctx.memTotalGB = metrics.memTotalGB
        ctx.battery = Int(metrics.battery)
        ctx.batteryRemaining = metrics.batteryRemainingLabel
        ctx.thermal = metrics.thermal.friendly
        ctx.diskFreeGB = metrics.diskFreeGB
        return ctx
    }
}

struct MiniIslandPreview<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        HStack(spacing: 6) { content() }
            .frame(width: 140, height: 30)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.2), lineWidth: 1))
    }
}

struct DesignDetailSheet: View {
    @Environment(\.palette) var p
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var state: AppState
    @EnvironmentObject var metrics: DeviceMetrics
    let design: Design
    @State private var toast: String? = nil
    /// Snapshot of (size, color, bold) at the moment we last applied this
    /// design. If the user changes any of those after applying, the apply
    /// button re-enables so they can push the new look.
    @State private var appliedSnapshot: AppliedSnapshot? = nil

    private struct AppliedSnapshot: Equatable {
        let size: IslandSize
        let color: AccentColor
        let bold: Bool
    }

    private var currentSnapshot: AppliedSnapshot {
        let e = state.edit(for: design.id)
        return AppliedSnapshot(size: state.size, color: e.color, bold: e.bold)
    }

    private var isApplied: Bool { state.appliedDesignId == design.id }
    private var hasChangesSinceApply: Bool {
        guard isApplied else { return false }
        return appliedSnapshot != currentSnapshot
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button { dismiss() } label: {
                    Label("BACK", systemImage: "chevron.left")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(1.4)
                        .foregroundStyle(p.text2)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(design.name).font(.system(size: 14, weight: .bold))
                    Text(design.category.rawValue).font(.system(size: 9.5, weight: .semibold, design: .monospaced)).tracking(1.4).foregroundStyle(p.text3)
                }
                Spacer()
            }
            .padding(14)
            .overlay(alignment: .bottom) { Rectangle().frame(height: 1).foregroundStyle(p.line) }

            ScrollView {
                VStack(spacing: 14) {
                    PreviewPill(isLong: state.size == .long) {
                        DesignView(design: design, context: ctxFromMetrics(), size: state.size, edit: state.edit(for: design.id))
                    }
                    .padding(.top, 16)

                    HStack(spacing: 8) {
                        sizeToggle("SHORT", value: .short)
                        sizeToggle("LONG", value: .long)
                    }

                    if let reason = design.pendingReason {
                        Text("⚠ \(reason)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(p.text3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 2)
                    }

                    SectionTitle(text: "— ACCENT COLOR")
                    HStack(spacing: 8) {
                        ForEach(AccentColor.allCases, id: \.self) { c in
                            Button {
                                var e = state.edit(for: design.id); e.color = c; state.setEdit(e, for: design.id)
                            } label: {
                                Circle().fill(c.swiftUIColor).frame(width: 32, height: 32)
                                    .overlay(Circle().stroke(state.edit(for: design.id).color == c ? p.hi : .clear, lineWidth: 2))
                            }.buttonStyle(.plain)
                        }
                        Spacer()
                    }

                    SectionTitle(text: "— EXTRAS")
                    Toggle("Bold values", isOn: Binding(
                        get: { state.edit(for: design.id).bold },
                        set: { var e = state.edit(for: design.id); e.bold = $0; state.setEdit(e, for: design.id) }
                    ))
                    .font(.system(size: 13))

                    GhostButton(title: "RESET") { state.resetEdit(for: design.id) }
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Apply button sits with the rest of the content,
                    // not pinned to the very bottom of the screen.
                    applyButton

                    Color.clear.frame(height: 12)
                }
                .padding(20)
            }
        }
        .background(p.bg)
        .foregroundStyle(p.text)
        .toast(message: $toast, alignment: .topTrailing, accent: .green)
        .onAppear {
            // If this design was already applied before opening, seed the snapshot
            // with the current settings so the button starts in "applied" state.
            if isApplied {
                appliedSnapshot = currentSnapshot
            }
        }
    }

    @ViewBuilder
    private var applyButton: some View {
        // Always enabled · tapping Apply overwrites whatever is currently applied.
        // Pending designs render with placeholder values until their data sources are wired.
        PrimaryButton(title: "Apply") {
            state.appliedDesignId = design.id
            appliedSnapshot = currentSnapshot
            Task {
                await LiveActivityManager.shared.apply(designId: design.id, metrics: metrics, size: state.size)
            }
            toast = "Applied"
        }
    }
    private func sizeToggle(_ label: String, value: IslandSize) -> some View {
        let on = state.size == value
        return Button { state.size = value } label: {
            Text(label).font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(1.2)
                .frame(maxWidth: .infinity).padding(.vertical, 11)
                .background(on ? p.hi : p.surface)
                .foregroundStyle(on ? p.bg : p.text3)
                .overlay(Rectangle().stroke(p.line2, lineWidth: 1))
        }.buttonStyle(.plain)
    }
    private func ctxFromMetrics() -> RenderContext {
        var c = RenderContext()
        c.cpu = Int(metrics.cpu); c.fps = metrics.refreshHz
        c.memUsedGB = metrics.memUsedGB; c.memTotalGB = metrics.memTotalGB
        c.battery = Int(metrics.battery)
        c.batteryRemaining = metrics.batteryRemainingLabel
        c.thermal = metrics.thermal.friendly
        c.diskFreeGB = metrics.diskFreeGB
        return c
    }
}

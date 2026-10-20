//
//  HistoryView.swift
//  操作历史：今天/昨天分组 + 类型筛选 + 状态（对标 Scarab）
//
import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var history: HistoryStore
    @Environment(\.dismiss) private var dismiss

    @State private var filter: Filter = .all

    enum Filter: String, CaseIterable {
        case all, commands, files, install
        var title: String {
            switch self {
            case .all: return L("history.filter.all")
            case .commands: return L("history.filter.commands")
            case .files: return L("history.filter.files")
            case .install: return L("history.filter.install")
            }
        }
    }

    private var filtered: [HistoryItem] {
        switch filter {
        case .all: return history.items
        case .commands: return history.items.filter { $0.type == .shell || $0.type == .logcat || $0.type == .screenshot || $0.type == .screenRecord }
        case .files: return history.items.filter { $0.type == .file }
        case .install: return history.items.filter { $0.type == .install || $0.type == .uninstall }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 筛选
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Filter.allCases, id: \.self) { f in
                            Button {
                                filter = f
                            } label: {
                                Text(f.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(filter == f ? .white : Color.kakaBlueDeep)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(filter == f ? Color.kakaBlueDeep : Color.kakaCard)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .background(Color.kakaBackground)

                if filtered.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.kakaBlue.opacity(0.5))
                        Text(L("history.empty"))
                            .font(.system(size: 14))
                            .foregroundStyle(Color.kakaTextSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.kakaBackground)
                } else {
                    List {
                        ForEach(history.sections().filter { !$0.items.isEmpty }, id: \.title) { section in
                            Section {
                                ForEach(section.items.filter { filterMatches($0) }) { item in
                                    row(item)
                                }
                            } header: {
                                if !section.title.isEmpty {
                                    Text(section.title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.kakaTextSecondary)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(Color.kakaBackground)
                }
            }
            .navigationTitle(L("history.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("common.close")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !history.items.isEmpty {
                        Button {
                            history.clearAll()
                            ToastCenter.shared.show(L("toast.success"))
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(Color.kakaDanger)
                        }
                    }
                }
            }
        }
    }

    private func filterMatches(_ item: HistoryItem) -> Bool {
        switch filter {
        case .all: return true
        case .commands: return item.type == .shell || item.type == .logcat || item.type == .screenshot || item.type == .screenRecord
        case .files: return item.type == .file
        case .install: return item.type == .install || item.type == .uninstall
        }
    }

    private func row(_ item: HistoryItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon(item.type))
                .font(.system(size: 15))
                .foregroundStyle(Color.kakaBlueDeep)
                .frame(width: 32, height: 32)
                .background(Color.kakaBackground)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.kakaTextPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(HistoryFactory.typeLabel(item.type))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.kakaTextSecondary)
                    Text(timeText(item.date))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.kakaTextSecondary)
                }
            }
            Spacer()
            switch item.status {
            case .running:
                ProgressView()
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.kakaSuccess)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.kakaDanger)
            }
        }
        .padding(.vertical, 4)
    }

    private func icon(_ type: HistoryType) -> String {
        switch type {
        case .install: return "square.and.arrow.down.fill"
        case .uninstall: return "trash.fill"
        case .file: return "folder.fill"
        case .screenshot: return "camera.viewfinder"
        case .screenRecord: return "video.fill"
        case .logcat: return "doc.text.fill"
        case .shell: return "terminal.fill"
        case .other: return "circle.fill"
        }
    }

    private func timeText(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: date)
    }
}

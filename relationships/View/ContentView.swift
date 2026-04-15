//
//  ContentView.swift
//  relationships
//
//  Created by QBQ on 2026/4/12.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject var viewModel = ContentViewModel()
    // 筛选类别
    @State private var filterCategory: GraphCategory?
    
    // 跟随系统/白天模式/夜间模式
    @AppStorage("appearanceSelection") private var appearanceSelection = 0
    var selectedScheme: ColorScheme? {
        if appearanceSelection == 1 {
            return .light
        }
        if appearanceSelection == 2 {
            return .dark
        }
        return nil // 跟随系统
    }
    var appearancePicker: some View {
        Menu {
            Button {
                appearanceSelection = 1
            } label: {
                Label("浅色模式", systemImage: "sun.max")
            }
            Button {
                appearanceSelection = 2
            } label: {
                Label("深色模式", systemImage: "moon")
            }
            Button {
                appearanceSelection = 0
            } label: {
                Label("跟随系统", systemImage: "desktopcomputer")
            }
        } label: {
            // 根据当前选择显示图标
            Image(systemName: appearanceSelection == 2 ? "moon.fill" : "sun.max.fill")
        }
    }
    
    // 搜索
    @State var isSearchActive = false // 控制搜索框是否展开
    @FocusState var isSearchFocused: Bool // 用于自动弹出键盘
    
    // 新增
    @State var isShowingAddAlert = false
    @State private var newGraphTitle = ""

    @State var selectedCategory: GraphCategory = .life
    
    // 多选（批量处理）
    @State var selectedIDs = Set<UUID>()
    @State var showingDeleteConfirm = false
    @State var editMode: EditMode = .inactive
    @State var newNameText = ""
    enum BatchEditMode: Identifiable, Equatable {
        case rename
        case category
        case singleEdit(GraphItem)

        var id: String {
            switch self {
            case .rename: return "rename"
            case .category: return "category"
            case .singleEdit(let graph): return graph.id.uuidString
            }
        }
    }
    @State var activeBatchEdit: BatchEditMode?
    
    var body: some View {
        NavigationStack {
            ZStack {
                mainContentView
            }
            .preferredColorScheme(selectedScheme) // 白天/夜间系统
            //            .navigationTitle("关系图列表")
            .focused($isSearchFocused) // 绑定搜索栏
            .toolbar {
                mainToolbar()
            }
            .sheet(item: $activeBatchEdit) { mode in
                batchEditSheet(for: mode)
                     .presentationDetents(mode == .category ? [.medium] : [.height(200)])
                            
            }
            .sheet(isPresented: $isShowingAddAlert) {
                AddGraphSheet(viewModel: viewModel, isShowingAddAlert: $isShowingAddAlert)
            }
            .confirmationDialog(
                "确定要删除这 \(selectedIDs.count) 项吗？",
                isPresented: $showingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("确定删除", role: .destructive) {
                    viewModel.batchDelete(ids: selectedIDs)                    
                    finalizeBatchAction()
                }
                Button("取消", role: .cancel) { }
            }
        }
    }

    private var mainContentView: some View {
        Group {
            if viewModel.graphList.isEmpty {
                // 情况 A：数据库完全为空，显示“欢迎与引导”
                initialGuideView
            } else if viewModel.filteredGraphs.isEmpty {
                // 情况 B：有数据，但当前筛选的分类下没有数据
                noResultView
            } else {
                // 情况 C：正常显示列表
                showAllgraphList
            }
        }
    }
}

struct GraphRowView: View {
    let graph: GraphItem

    var body: some View {
        HStack(spacing: 15) {
            // 左侧分类色块
            RoundedRectangle(cornerRadius: 4)
                .fill(graph.category.accentColor)
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(graph.title)
                        .font(.headline)
                        .padding(.leading, 8)
                    Text(graph.category.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(graph.category.accentColor.opacity(0.1))
                        .foregroundColor(graph.category.accentColor)
                        .clipShape(Capsule())
                    Text("\(graph.nodes.count) 人")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddGraphSheet: View {
    @ObservedObject var viewModel = ContentViewModel()
    @Binding var isShowingAddAlert: Bool
    @State private var newGraphTitle = ""
    @State private var selectedCategory: GraphCategory = .life
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("图表名称", text: $newGraphTitle)
                    Picker("选择分类", selection: $selectedCategory) {
                        ForEach(GraphCategory.allCases) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                }
            }
            .navigationTitle("新建图信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { isShowingAddAlert = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        let newGraph = GraphItem(title: newGraphTitle, category: selectedCategory)
                        viewModel.graphList.append(newGraph)
                        viewModel.saveAllToDisk()
                        isShowingAddAlert = false
                    }
                    .disabled(newGraphTitle.trimmingCharacters(in: .whitespaces).isEmpty) // 防止创建空名字
                }
            }
        }
        .presentationDetents([.height(200)])
    }
}

#Preview {
    ContentView()
}

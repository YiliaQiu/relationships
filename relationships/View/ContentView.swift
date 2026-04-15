//
//  ContentView.swift
//  relationships
//
//  Created by QBQ on 2026/4/12.
//

import SwiftUI
import UIKit

// mainView
// swiftlint:disable:next type_body_length
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
    @State private var isSearchActive = false // 控制搜索框是否展开
    @FocusState private var isSearchFocused: Bool // 用于自动弹出键盘
    
    // 新增
    @State private var isShowingAddAlert = false
    @State private var newGraphTitle = ""

    @State private var selectedCategory: GraphCategory = .life
    
    // 多选（批量处理）
    @State private var selectedIDs = Set<UUID>()
    @State private var showingDeleteConfirm = false
    @State private var editMode: EditMode = .inactive
    @State private var newNameText = ""
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
    @State private var activeBatchEdit: BatchEditMode?
    
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
    
    // 用户引导
    var initialGuideView: some View {
        ContentUnavailableView {
            Label("开启你的社交图谱", systemImage: "network")
        } description: {
            Text("目前还没有任何关系图。您可以点击下方按钮载入示例，或者点击右上角自行创建。")
        } actions: {
            Button("载入示例数据") {
                viewModel.insertSampleData() // 调用之前写的插入函数
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // 筛选按钮
    var filterMenu: some View {
        Menu {
            Button("全部显示", systemImage: "line.3.horizontal") {
                viewModel.selectedFilter = nil
            }
            Divider()
            ForEach(GraphCategory.allCases, id: \.id) { cat in
                Button(cat.rawValue, systemImage: "tag") {
                    viewModel.selectedFilter = cat
                }
            }
        } label: {
            // 动态图标：未筛选时用空心，筛选后用实心并变色
            Label("筛选", systemImage: viewModel.selectedFilter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                .foregroundColor(viewModel.selectedFilter?.accentColor ?? .primary)
        }
    }
    var noResultView: some View {
        ContentUnavailableView {
            // 图标逻辑：搜索时用放大镜，仅筛选时用列表图标
            Label(viewModel.searchText.isEmpty ? "分类下无内容" : "未找到 “\(viewModel.searchText)”",
                  systemImage: viewModel.searchText.isEmpty ? "line.3.horizontal.decrease.circle" : "magnifyingglass")
        } description: {
            // --- 核心修改：根据状态切换描述 ---
            if !viewModel.searchText.isEmpty && viewModel.selectedFilter != nil {
                Text("在“\(viewModel.selectedFilter?.rawValue ?? "")”分类中没找到与“\(viewModel.searchText)”匹配的内容。")
            } else if !viewModel.searchText.isEmpty {
                Text("请检查拼写或尝试其他关键词。")
            } else {
                Text("当前“\(viewModel.selectedFilter?.rawValue ?? "")”分类下还没有关系图。")
            }
        } actions: {
            Button("清除搜索与过滤") {
                withAnimation {
                    viewModel.searchText = ""
                    viewModel.selectedFilter = nil
                }
            }
            .buttonStyle(.bordered)
        }
    }
    var showAllgraphList: some View {
        List(selection: $selectedIDs) {
            ForEach(viewModel.filteredGraphs) { graph in
                NavigationLink {
                    RelationshipGraphView(vm: GraphViewModel(nodes: graph.nodes, edges: graph.edges)) { newNodes, newEdges in
                        if let index = viewModel.graphList.firstIndex(where: { $0.id == graph.id }) {
                            viewModel.graphList[index].nodes = newNodes
                            viewModel.graphList[index].edges = newEdges
                            viewModel.saveAllToDisk()
                        }
                    }
                    .navigationTitle(graph.title)
                    .navigationBarTitleDisplayMode(.inline)
                } label: {
                    GraphRowView(graph: graph)
                }
                .tag(graph.id)
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        viewModel.copyGraph(graph)                        
                    } label: {
                        Label("拷贝", systemImage: "doc.on.doc")
                    }
                    .tint(.blue)
                    Button {
                        activeBatchEdit = .singleEdit(graph) // 触发弹窗
                    } label: {
                        Label("编辑", systemImage: "pencil")
                    }
                    .tint(.orange)
                }
            }
            .onDelete { indexSet in
                viewModel.deleteFromFiltered(at: indexSet)
                UISelectionFeedbackGenerator().selectionChanged()
                viewModel.saveAllToDisk()
            }
        }
        .environment(\.editMode, $editMode)
    }

    var searchView: some View {
        // 搜索栏展开状态：显示输入框和取消按钮
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.footnote)
            TextField("搜索...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .frame(width: 150) // 限制宽度，防止挤掉加号
                .focused($isSearchFocused)
            Button(
                action: {
                    withAnimation {
                        isSearchActive = false
                        viewModel.searchText = ""
                    }
                },
                label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    @ViewBuilder
    func batchEditSheet(for mode: BatchEditMode) -> some View {
        NavigationStack {
            Group {
                switch mode {
                case .rename:
                    batchRenameSection
                case .category:
                    batchCategorySection
                case .singleEdit(let graph):
                    singleEditSection(for: graph)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { activeBatchEdit = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        executeSave(for: mode)
                    }
                    .disabled(newNameText.isEmpty)
                }
            }
        }
    }
    
    private var batchRenameSection: some View {
        VStack(spacing: 20) {
            TextField("输入新名称", text: $newNameText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
            Text("将对选中的 \(selectedIDs.count) 个项目进行重命名")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal)
        .navigationTitle("批量重命名")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var batchCategorySection: some View {
        List(GraphCategory.allCases) { category in
            Button {
                withAnimation {
                    viewModel.updateGraphs(ids: selectedIDs, title: nil, category: category)
                    // 操作完重置状态
                    finalizeBatchAction()
                }
            } label: {
                HStack {
                    // 使用你定义的颜色和文字
                    Circle()
                        .fill(category.accentColor)
                        .frame(width: 10, height: 10)
                    Text(category.rawValue)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
        }
        .listStyle(.plain)
        .navigationTitle("修改分类")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func singleEditSection(for graph: GraphItem) -> some View {
        Form {
            TextField("图名称", text: $newNameText)
            Picker("分类", selection: $selectedCategory) {
                ForEach(GraphCategory.allCases) { cat in
                    Text(cat.rawValue).tag(cat)
                }
            }
        }
        .onAppear {
            newNameText = graph.title
            selectedCategory = graph.category
        }
        .navigationTitle("编辑图信息")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func executeSave(for mode: BatchEditMode) {
        withAnimation {
            switch mode {
            case .rename:
                viewModel.updateGraphs(ids: selectedIDs, title: newNameText, category: nil)
            case .category:
                // 这种模式通常在 List 点击时就保存了，这里可以留空或处理
                break
            case .singleEdit(let graph):
                // 单个修改：包装成 Set 传给 updateGraphs
                viewModel.updateGraphs(ids: [graph.id], title: newNameText, category: selectedCategory)
            }
            finalizeBatchAction() // 统一关闭并清理
        }
    }
    func finalizeBatchAction() {
        withAnimation {
            // 清空选中的 ID
            selectedIDs.removeAll()
            // 退出多选模式
            editMode = .inactive
            // 清空输入框
            newNameText = ""
            activeBatchEdit = nil
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

extension ContentView {
    @ToolbarContentBuilder
    func mainToolbar() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            leadingToolbarItems
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            trailingToolbarItems
        }
    }
    
    @ViewBuilder
    private var leadingToolbarItems: some View {
        if editMode == .active && !selectedIDs.isEmpty {
            HStack(spacing: 20) {
                Button(role: .destructive) {
                    showingDeleteConfirm = true
                } label: {
                    Label("批量删除", systemImage: "trash")
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
                
                Button {
                    withAnimation {
                        viewModel.batchCopy(ids: selectedIDs)
                        selectedIDs.removeAll()
                        editMode = .inactive
                    }
                } label: {
                    Label("批量拷贝", systemImage: "plus.square.on.square")
                }
                
                Button {
                    newNameText = ""
                    activeBatchEdit = .rename
                } label: {
                    Label("批量重命名", systemImage: "pencil.and.outline")
                }
                
                Button {
                    activeBatchEdit = .category
                } label: {
                    Label("批量修改类别", systemImage: "folder.badge.gearshape")
                }
            }
        } else {
            HStack {
                if !isSearchActive {
                    filterMenu
                }
                appearancePicker // 添加切换按钮（白天/夜间/跟随系统）
            }
        }
    }
    
    @ViewBuilder
    private var trailingToolbarItems: some View {
        if isSearchActive {
            searchView
        } else {
            HStack {
                Button {
                    withAnimation {
                        editMode = (editMode == .inactive ? .active : .inactive)
                        if editMode == .inactive {
                            selectedIDs.removeAll()
                        }
                    }
                } label: {
                    Label(
                        editMode == .inactive ? "多选" : "取消",
                        systemImage: editMode == .inactive ? "checklist" : "xmark.circle"
                    )
                    // 根据模式自动切换：非激活时用原样，激活（取消）时强制使用填充风格
                    .symbolVariant(editMode == .inactive ? .none : .fill)
                }
                Button(
                    action: {
                        withAnimation(.spring()) {
                            isSearchActive = true
                            isSearchFocused = true // 自动点亮键盘
                        }
                    },
                    label: {
                        Image(systemName: "magnifyingglass")
                    }
                )
                Menu {
                    Button(
                        action: {
                            isShowingAddAlert = true
                        },
                        label: {
                            Text("新建")
                            Image(systemName: "plus")
                        }
                    )
                    Button(
                        action: {
//                                    TODO: 导入解析
//                                    isShowingImportPicker = true
                        }, label: {
                            Text("导入")
                            Image(systemName: "square.and.arrow.down")
                        }
                    )
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
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

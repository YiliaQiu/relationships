//
//  ContentView_Subviews.swift
//  relationships
//
//  Created by QBQ on 2026/4/15.
//

import SwiftUI

extension ContentView {    
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
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if editMode == .inactive {
                        Button(role: .destructive) {
                            if let index = viewModel.filteredGraphs.firstIndex(where: { $0.id == graph.id }) {
                                viewModel.deleteFromFiltered(at: IndexSet(integer: index))
                                UISelectionFeedbackGenerator().selectionChanged()
                                viewModel.saveAllToDisk()
                            }
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
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
        }
        .environment(\.editMode, $editMode)
    }

}

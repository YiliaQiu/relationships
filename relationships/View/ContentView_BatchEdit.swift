//
//  ContentView_BatchEdit.swift
//  relationships
//
//  Created by QBQ on 2026/4/15.
//

import SwiftUI
import UIKit

extension ContentView {
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
        UINotificationFeedbackGenerator().notificationOccurred(.success)
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

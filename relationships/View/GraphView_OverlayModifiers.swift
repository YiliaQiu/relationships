//
//  GraphView_OverlayModifiers.swift
//  relationships
//
//  Created by QBQ on 2026/4/16.
//

import SwiftUI

// 节点相关弹窗
struct NodeOperationsModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var selectedNodeID: UUID?
    @ObservedObject var vm: GraphViewModel
    
    @State private var showEditName = false
    @State private var editedName = ""
    @State private var showColorPicker = false
    @State private var showDeleteConfirm = false
    
    func body(content: Content) -> some View {
        content
            .confirmationDialog("节点操作", isPresented: $isPresented) {
                Button("✏️ 修改名称") {
                    guard let id = selectedNodeID, let node = vm.nodes.first(where: {$0.id == id}) else { return }
                    editedName = node.title
                    showEditName = true
                }
                Button("🎨 修改颜色") {
                    showColorPicker = true
                }
                Button("👤 修改头像") {
                    // TODO
                }
                Button("⚠️ 删除节点", role: .destructive) {
                    showDeleteConfirm = true
                }
                Button("取消", role: .cancel) {}
            }
            .alert("修改节点名称", isPresented: $showEditName) {
                TextField("输入新名称", text: $editedName)
                Button("确定") {
                    guard let  id = selectedNodeID else { return }
                    vm.updateNodeName(id: id, newName: editedName)
                }
                Button("取消", role: .cancel) { }
            }
            .alert("确认删除？", isPresented: $showDeleteConfirm) {
                Button("确定", role: .destructive) {
                    guard let id = selectedNodeID else {return}
                    vm.deleteNode(id: id)
                }
                Button("取消", role: .cancel) { }
            }
            .sheet(isPresented: $showColorPicker) {
                if let id = selectedNodeID,
                   let index = vm.nodes.firstIndex(where: { $0.id == id }) {
                    SystemColorPicker(selectedColor: $vm.nodes[index].color)
                        .presentationDetents([.medium])
                        .presentationBackground(.white)
                }
            }
    }
}

// 连线相关弹窗
struct EdgeOperationsModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var selectedEdgeID: UUID?
    @ObservedObject var vm: GraphViewModel

    @State private var showEditEdgeLabel = false
    @State private var editedEdgeLabel = ""

    func body(content: Content) -> some View {
        content
            .confirmationDialog("连线操作", isPresented: $isPresented) {
                Button("✏️ 修改标签") {
                    guard let id = selectedEdgeID, let edge = vm.edges.first(where: {$0.id == id}) else { return }
                    editedEdgeLabel = edge.label
                    showEditEdgeLabel = true
                }
                Button("⚠️ 删除连线", role: .destructive) {
                    guard let id = selectedEdgeID else {return}
                            vm.deleteEdge(id: id)
                }
                Button("取消", role: .cancel) {}
            }
            .alert("修改连线标签", isPresented: $showEditEdgeLabel) {
                TextField("输入新标签", text: $editedEdgeLabel)
                Button("确定") {
                    guard let  id = selectedEdgeID else { return }
                    vm.updateEdgeLabel(id: id, newLabel: editedEdgeLabel)
                }
                Button("取消", role: .cancel) { }
            }
    }
}

//
//  RelationshipGraphView.swift
//  relationships
//
//  Created by QBQ on 2026/4/9.
//  只负责UI展示+手势

import SwiftUI
import UIKit

struct CanvasTransform{
     var scale: CGFloat = 1.0
     var offset: CGSize = .zero
     var lastScale: CGFloat = 1.0
     var lastOffset: CGSize = .zero
}


struct RelationshipGraphView: View {
//    @StateObject private var vm = GraphViewModel()
    @ObservedObject var vm: GraphViewModel
    
    @State private var selectedNodeID: UUID?
    @State private var showNodeMenu = false
    @State private var selectedEdgeID: UUID?
    @State private var showEdgeMenu = false

    @State private var showEditName = false
    @State private var editedName = ""
    @State private var showColorPicker = false
    @State private var showDeleteConfirm = false

    @State private var showEditEdgeLabel = false
    @State private var editedEdgeLabel = ""

    @State private var canvas = CanvasTransform()

    @State private var lastDragTime: Date = .distantPast
    private let dragThrottle: TimeInterval = 1 / 60

    var body: some View {
        NavigationStack {
            mainCanvas
        }
        .modifier(GlobalAlerts(
            showEditName: $showEditName, editedName: $editedName,
            selectedNodeID: $selectedNodeID, vm: vm,
            showDeleteConfirm: $showDeleteConfirm,
            showColorPicker: $showColorPicker,
            showEditEdgeLabel: $showEditEdgeLabel, editedEdgeLabel: $editedEdgeLabel,
            selectedEdgeID: $selectedEdgeID
        ))
    }

    private var mainCanvas: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
            // 双指缩放：空白区域生效
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            withTransaction(.init(animation: nil)) {
                                canvas.scale = canvas.lastScale * value
                            }
                        }
                        .onEnded { _ in
                            canvas.lastScale = canvas.scale
                        }
                    // 单指拖拽：空白区域拖动页面
                        .simultaneously(with: DragGesture(minimumDistance: 2)
                            .onChanged { value in
                                withTransaction(.init(animation: nil)) {
                                    canvas.offset = CGSize(
                                        width: canvas.lastOffset.width + value.translation.width,
                                        height: canvas.lastOffset.height + value.translation.height
                                    )
                                }
                            }
                            .onEnded { _ in
                                canvas.lastOffset = canvas.offset
                            }
                        )
                )
            graphCanvas
                .transformEffect(
                    CGAffineTransform(scaleX: canvas.scale, y: canvas.scale)
                        .translatedBy(x: canvas.offset.width, y: canvas.offset.height)
                )
                .drawingGroup()
        }
        .modifier(NodeEdgeDialogs(
            showNodeMenu: $showNodeMenu, showEdgeMenu: $showEdgeMenu,
            selectedNodeID: $selectedNodeID, vm: vm,
            showEditName: $showEditName, editedName: $editedName,
            showColorPicker: $showColorPicker, showDeleteConfirm: $showDeleteConfirm,
            selectedEdgeID: $selectedEdgeID,
            showEditEdgeLabel: $showEditEdgeLabel, editedEdgeLabel: $editedEdgeLabel
        ))
        .toolbar { toolbarContent }
        .background(Color(.systemBackground))
        .ignoresSafeArea()
    }
    
    private var graphCanvas: some View {
        ZStack {
            edgeList
            nodeList
        }
    }
    
    private var edgeList: some View {
        ForEach(vm.edges, id: \.id) { edge in // id是唯一ID 标识视图，用于拖拽页面时不要重建所有节点/连线
            ConnectionView(
                edge: edge, vm: vm,
                nodeVersion: vm.getNodeVersion(for: edge.from) + vm.getNodeVersion(for: edge.to)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                selectedEdgeID = edge.id
                showEdgeMenu = true
            }
        }
    }
    private var nodeList: some View {
        ForEach ($vm.nodes, id: \.id) { $node in
            NodeView(
                node: $node,
                onTapNode: {
                    selectedNodeID = node.id
                    showNodeMenu = true
                    print("qbq点击节点后，显示菜单", showNodeMenu)
                },
                onDrag: { position in
                    guard Date().timeIntervalSince(lastDragTime) >= dragThrottle else { return }
                    vm.updateNodePosition(id: node.id, newPosition: position)
                    lastDragTime = Date()
                },
                onTapForConnect: {
                    if let first = vm.firstSelectedNodeID {
                        vm.connect(from: first, to: node.id)
                        // reset
                        vm.firstSelectedNodeID = nil
                        vm.isConnectingMode = false
                    } else {
                        vm.firstSelectedNodeID = node.id
                    }
                },
                isConnectingMode: vm.isConnectingMode,
                isFirstSelectedNode: vm.firstSelectedNodeID == node.id
            )
        }
    }
    
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: { vm.addNode() }) {
                Image(systemName: "plus")
                    .font(.title)
                    .foregroundColor(.blue)
            }
            Button(action: {
                vm.isConnectingMode.toggle()
                vm.firstSelectedNodeID = nil
            }) {
                Text(vm.isConnectingMode ? "退出连线" : "连线")
                    .foregroundColor(vm.isConnectingMode ? .red : .blue)
            }
            Button(action: fitToScreen) {
                Image(systemName: "viewfinder")
                    .font(.title)
                    .foregroundColor(.blue)
            }
        }
    }
    
    private func fitToScreen() {
        let nodes = vm.nodes
        guard !nodes.isEmpty else { return }

        let screenW = UIScreen.main.bounds.width
        let screenH = UIScreen.main.bounds.height

        let topSafe: CGFloat = 70
        let padding: CGFloat = 20

        let viewW = screenW - padding * 2
        let viewH = screenH - topSafe - padding * 2

        let xs = nodes.map { $0.position.x }
        let ys = nodes.map { $0.position.y }

        guard let minX = xs.min(),
              let maxX = xs.max(),
              let minY = ys.min(),
              let maxY = ys.max() else {
            return
        }

        let contentW = maxX - minX + 1
        let contentH = maxY - minY + 1

        let s = min(viewW / contentW, viewH / contentH, 1.5)

        let cx = (minX + maxX) * 0.5
        let cy = (minY + maxY) * 0.5

        let ox = screenW / 2 - cx * s
        let oy = topSafe + padding + viewH/2 - cy * s

        canvas.scale = s
        canvas.offset = CGSize(width: ox, height: oy)
        canvas.lastOffset = canvas.offset
        canvas.lastScale = canvas.scale
    }
}

struct NodeEdgeDialogs: ViewModifier {
    @Binding var showNodeMenu: Bool
    @Binding var showEdgeMenu: Bool
    @Binding var selectedNodeID: UUID?
    @ObservedObject var vm: GraphViewModel
    @Binding var showEditName: Bool
    @Binding var editedName: String
    @Binding var showColorPicker: Bool
    @Binding var showDeleteConfirm: Bool
    @Binding var selectedEdgeID: UUID?
    @Binding var showEditEdgeLabel: Bool
    @Binding var editedEdgeLabel: String
    
    func body(content: Content) -> some View {
        content
            .confirmationDialog("节点操作", isPresented: $showNodeMenu) {
                Button("✏️ 修改名称") {
                    print("qbq")
                    guard let id = selectedNodeID, let node = vm.nodes.first(where: {$0.id == id}) else { return }
                    editedName = node.title
                    showEditName = true
                }
                Button("🎨 修改颜色") {
                    showColorPicker = true
                    print("qbq, 显示色盘", showColorPicker)
                }
                Button("👤 修改头像") {
                    // TODO
                    print("qbq, 修改头像")
                }
                Button("⚠️ 删除节点", role: .destructive) {
                    showDeleteConfirm = true
                }
                Button("取消", role: .cancel) {}
            }
            .confirmationDialog("连线操作", isPresented: $showEdgeMenu) {
                Button("✏️ 修改标签") {
                    print("qbq")
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
    }
}

struct GlobalAlerts: ViewModifier {
    @Binding var showEditName: Bool
    @Binding var editedName: String
    @Binding var selectedNodeID: UUID?
    
    @ObservedObject var vm: GraphViewModel
    @Binding var showDeleteConfirm: Bool
    @Binding var showColorPicker: Bool
    @Binding var showEditEdgeLabel: Bool
    @Binding var editedEdgeLabel: String
    @Binding var selectedEdgeID: UUID?
        
    func body(content: Content) -> some View {
        content
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
                   let index = vm.nodes.firstIndex(where: { $0.id == id })
                {
                    SystemColorPicker(selectedColor: $vm.nodes[index].color)
                        .presentationDetents([.medium])
                        .presentationBackground(.white)
                }
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

struct NodeView: View {
    @Binding var node: NodeModel
    var onTapNode: () -> Void
    var onDrag: (CGPoint) -> Void
    
    var onTapForConnect: () -> Void
    var isConnectingMode: Bool
    var isFirstSelectedNode: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(node.color.opacity(0.8))
                .frame(width: 60, height: 60)
                .shadow(color: isFirstSelectedNode ? .red : .clear, radius: 10)
            Text(node.title)
                .font(.headline)
                .foregroundColor(.white)
        }
        .position(node.position)
        .onTapGesture {
            print("qbq点击了节点, 是否为连线模式：", isConnectingMode)
            isConnectingMode ? onTapForConnect() : onTapNode()
        }
        .highPriorityGesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    onDrag(value.location)
                }
        )
    }
}

struct ConnectionView: View, Equatable {
    let edge: EdgeModel
    let vm: GraphViewModel
    let nodeVersion: Int // 节点位置版本号
    
    static func == (lhs: ConnectionView, rhs: ConnectionView) -> Bool {
        lhs.edge.id == rhs.edge.id &&
        lhs.edge.from == rhs.edge.from &&
        lhs.edge.to == rhs.edge.to &&
        lhs.edge.label == rhs.edge.label &&
        lhs.nodeVersion == rhs.nodeVersion
    }

    var body: some View {
        if let (from, _) = vm.getConnectionPoints(from: edge.from, to: edge.to),
           let arrow = vm.getArrowPoints(from: edge.from, to: edge.to) {
            ZStack {
                // mainLine
                Path { path in
                    path.move(to: from)
                    path.addLine(to: arrow.tip)
                }
                .stroke(Color.blue, lineWidth: 2)
                
                // Arrow
                Path { path in
                    path.move(to: arrow.tip)
                    path.addLine(to: arrow.left)
                    path.addLine(to: arrow.right)
                    path.closeSubpath()
                }
                .stroke(Color.blue)
                
                // label
                if let midPoint = vm.getMidPoint(from: edge.from, to: edge.to) {
                    Text(edge.label)
                        .font(.caption)
                        .padding(4)
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(4)
                        .position(midPoint)
//                        .onTapGesture {
//                            onTapForEdgeLabel()
//                        }
                }
            }
        }
    }
}

struct SystemColorPicker: UIViewControllerRepresentable {
    @Binding var selectedColor: Color
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIColorPickerViewController {
        let picker = UIColorPickerViewController()
        picker.selectedColor = UIColor(selectedColor)
        picker.delegate = context.coordinator
        
        picker.modalPresentationStyle = .pageSheet
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIColorPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIColorPickerViewControllerDelegate {
        let parent: SystemColorPicker
        
        init(_ parent: SystemColorPicker) {
            self.parent = parent
        }
        
        // 实时滑动预览颜色
        func colorPickerViewController(_ viewController: UIColorPickerViewController, didSelect color: UIColor, continuously: Bool) {
            parent.selectedColor = Color(color)
        }
        
        // 点击完成保存颜色
        func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
            parent.selectedColor = Color(viewController.selectedColor)
            parent.dismiss()
        }
        
        // 取消
        func colorPickerViewControllerDidCancel(_ viewController: UIColorPickerViewController) {
            parent.dismiss()
        }
    }
}


//#Preview {
//    RelationshipGraphView()
//}

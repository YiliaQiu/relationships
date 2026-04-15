//
//  RelationshipGraphView.swift
//  relationships
//
//  Created by QBQ on 2026/4/9.
//  只负责UI展示+手势

import SwiftUI
import UIKit

struct CanvasTransform {
     var scale: CGFloat = 1.0
     var offset: CGSize = .zero
     var lastScale: CGFloat = 1.0
     var lastOffset: CGSize = .zero
}

struct RelationshipGraphView: View {
    @ObservedObject var vm: GraphViewModel
    var onSave: (([NodeModel], [EdgeModel]) -> Void)?

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
    
    @State private var showClearAlert = false
    
    var body: some View {
        GeometryReader { geometry in
            mainCanvas(size: geometry.size, proxy: geometry).onAppear {
                fitToScreen(size: geometry.size, proxy: geometry)
            }
        }
        .modifier(GlobalAlerts(
            showEditName: $showEditName, editedName: $editedName,
            selectedNodeID: $selectedNodeID, vm: vm,
            showDeleteConfirm: $showDeleteConfirm,
            showColorPicker: $showColorPicker,
            showEditEdgeLabel: $showEditEdgeLabel, editedEdgeLabel: $editedEdgeLabel,
            selectedEdgeID: $selectedEdgeID
        ))
        .onAppear {
            vm.saveInitSnapShot()
        }
        .onDisappear {
            print("详情页正在消失，准备回调数据...")
            onSave?(vm.nodes, vm.edges)
        }
        .onChange(of: vm.undoHistory.count) { _, _ in }
        .alert("确认清空画布", isPresented: $showClearAlert) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                vm.clearAll()
            }
        } message: {
            Text("删除后无法恢复，确定要清空吗")
        }
    }

    private func mainCanvas(size: CGSize, proxy: GeometryProxy) -> some View {
        ZStack {
            Color(.systemBackground)
                .contentShape(Rectangle())
            graphCanvas
        }
        // 双指缩放：空白区域生效
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    withTransaction(.init(animation: nil)) {
                        let newScale = canvas.lastScale * value // 当前缩放比例
                        let zoomFactor = newScale / canvas.scale // 获取缩放变化率
                        
                        // "中心补偿": 缩放向中间收拢
                        let centerX = size.width / 2
                        let centerY = size.height / 2
                        
                        canvas.offset.width -= (zoomFactor - 1) * (centerX - canvas.offset.width)
                        canvas.offset.height -= (zoomFactor - 1) * (centerY - canvas.offset.height)
                        
                        canvas.scale = newScale
                    }
                }
                .onEnded { _ in
                    canvas.lastScale = canvas.scale
                    canvas.lastOffset = canvas.offset // 缩放过程offset变了，同步更新
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
        .modifier(NodeEdgeDialogs(
            showNodeMenu: $showNodeMenu, showEdgeMenu: $showEdgeMenu,
            selectedNodeID: $selectedNodeID, vm: vm,
            showEditName: $showEditName, editedName: $editedName,
            showColorPicker: $showColorPicker, showDeleteConfirm: $showDeleteConfirm,
            selectedEdgeID: $selectedEdgeID,
            showEditEdgeLabel: $showEditEdgeLabel, editedEdgeLabel: $editedEdgeLabel
        ))
        .toolbar {
            toolbarContent(size: size, proxy: proxy)
        }
        .ignoresSafeArea()
    }
    
    private var graphCanvas: some View {
        ZStack {
            edgeList
            nodeList
        }
        // 先缩放，并指定从左上角缩放
        .scaleEffect(canvas.scale, anchor: .topLeading)
        .offset(x: canvas.offset.width, y: canvas.offset.height)
        .drawingGroup()
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
        .id(UUID())
    }
    private var nodeList: some View {
        ForEach($vm.nodes, id: \.id) { $node in
            NodeView(
                vm: vm,
                node: $node,
                onTapNode: {
                    selectedNodeID = node.id
                    showNodeMenu = true
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
    
    private func toolbarContent(size: CGSize, proxy: GeometryProxy) -> some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            HStack(spacing: 4) {
                Button {
                    vm.isConnectingMode.toggle()
                    vm.firstSelectedNodeID = nil
                } label: {
                    Text(vm.isConnectingMode ? "退出连线" : "连线")
                        .foregroundColor(vm.isConnectingMode ? .red : .blue)
                }
                Button {
                    vm.addNode()
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(.blue)
                }
                Button {
                    fitToScreen(size: size, proxy: proxy)
                } label: {
                    Image(systemName: "viewfinder")
                        .foregroundColor(.blue)
                }
                Button {
                    vm.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(vm.undoHistory.isEmpty)
                .foregroundColor(vm.undoHistory.isEmpty ? .gray : .blue)
                Button(role: .destructive) {
                    showClearAlert = true // 触发弹窗
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    // 画面居中：计算包围盒->计算比例->计算偏移
    private func fitToScreen(size: CGSize, proxy: GeometryProxy) {
        let nodes = vm.nodes
        guard !nodes.isEmpty else { return }

        // 导航栏安全区
        let topInset = proxy.safeAreaInsets.top
        
        // 获取所有节点的坐标边界
        let xs = nodes.map { $0.position.x }
        let ys = nodes.map { $0.position.y }
        
        // 增加节点半径补偿（假设半径为 30），防止边缘被切
        let padding: CGFloat = 30
        guard let minX = xs.min(),
              let maxX = xs.max(),
              let minY = ys.min(),
              let maxY = ys.max() else {
                return
        }
        let finalMinX = minX - padding
        let finalMaxX = maxX + padding
        let finalMinY = minY - padding
        let finalMaxY = maxY + padding

        // 2. 计算内容的总宽高
        let contentW = finalMaxX - finalMinX
        let contentH = finalMaxY - finalMinY

        // 3. 计算缩放比例
        // 预留一些屏幕边距 (比如屏幕宽度的 90%)
        let scaleX = (size.width * 0.9) / contentW
        let scaleY = (size.height * 0.9) / contentH
        let s = min(scaleX, scaleY, 1.5)

        // 4. 计算偏移量
        // -minX * s 是把内容的最左边拉到屏幕边缘 0
        // (size.width - contentW * s) / 2：计算剩余空间并平分，实现水平居中
        let ox = (size.width - contentW * s) / 2 - finalMinX * s
        let oy = (size.height - contentH * s) / 2 - finalMinY * s + topInset

        withAnimation(.easeInOut) {
            canvas.scale = s
            canvas.offset = CGSize(width: ox, height: oy)
            canvas.lastScale = s
            canvas.lastOffset = canvas.offset
        }
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
            .confirmationDialog("连线操作", isPresented: $showEdgeMenu) {
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
                   let index = vm.nodes.firstIndex(where: { $0.id == id }) {
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
    @ObservedObject var vm: GraphViewModel
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
            if isConnectingMode {
                onTapForConnect()
            } else {
                onTapNode()
            }
        }
        .highPriorityGesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    vm.isDraggingNode = true
                    onDrag(value.location)
                }
                .onEnded { _ in
                    vm.isDraggingNode = false
                    vm.finishedDragAndSaveSnapshot()
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

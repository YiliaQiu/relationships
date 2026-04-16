//
//  GraphView.swift
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

struct GraphView: View {
    @ObservedObject var vm: GraphViewModel
    var onSave: (([NodeModel], [EdgeModel]) -> Void)?

    @State private var selectedNodeID: UUID?
    @State private var showNodeMenu = false
    @State private var selectedEdgeID: UUID?
    @State private var showEdgeMenu = false
    
    @State private var canvas = CanvasTransform()
    
    @State private var lastDragTime: Date = .distantPast
    private let dragThrottle: TimeInterval = 1 / 60
    
    @State private var showClearAlert = false
    
    let haptic = UIImpactFeedbackGenerator(style: .medium)
    
    private let minScale: CGFloat = 0.3
    private let maxScale: CGFloat = 3.0
    private let bounceRange: CGFloat = 0.2
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                mainCanvas(size: geometry.size, proxy: geometry)
                    .clipped() // mainCanvas 的实际尺寸（不含安全区的部分）为边界进行裁剪
            }.onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { // 延迟0.1s确保动画趋于稳定后再居中计算
                    fitToScreen(size: geometry.size, proxy: geometry)
                }
                
            }
        }
        .ignoresSafeArea(.all, edges: .bottom) // 仅针对底部（小白条区域）忽略，让背景自然延伸，但顶部保持避让
        .modifier(NodeOperationsModifier(
            isPresented: $showNodeMenu, selectedNodeID: $selectedNodeID, vm: vm
        ))
        .modifier(EdgeOperationsModifier(
            isPresented: $showEdgeMenu, selectedEdgeID: $selectedEdgeID, vm: vm
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
            makeCanvasGestures(size: size, proxy: proxy)
        )
        .toolbar {
            toolbarContent(size: size, proxy: proxy)
        }
    }
    
    private var graphCanvas: some View {
        ZStack {
            edgeList
                .zIndex(0) // 层级设为0
            nodeList
                .zIndex(1) // 确保层次永远在连线上
        }
        .offset(x: canvas.offset.width, y: canvas.offset.height)
        .scaleEffect(canvas.scale) // 默认中心缩放
        .drawingGroup()
    }
    
    private var edgeList: some View {
        ForEach(vm.edges, id: \.id) { edge in // id是唯一ID 标识视图，用于拖拽页面时不要重建所有节点/连线
            ConnectionView(
                edge: edge, vm: vm,
                nodeVersion: vm.getNodeVersion(for: edge.from) + vm.getNodeVersion(for: edge.to)
            )
            .contentShape(Rectangle()) // 让点击区域变成一个完整的矩形，而不是只有那根细线
            .onTapGesture {
                selectedEdgeID = edge.id
                showEdgeMenu = true
            }
        }
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
    
    // "中心补偿": 缩放向中间收拢
    private func applyCenterCompensation(zoomFactor: CGFloat, size: CGSize, proxy: GeometryProxy) {
        let centerX = size.width / 2
        let centerY = (size.height - proxy.safeAreaInsets.bottom) / 2
        
        canvas.offset.width -= (zoomFactor - 1) * (centerX - canvas.offset.width)
        canvas.offset.height -= (zoomFactor - 1) * (centerY - canvas.offset.height)
    }
    
    private func makeCanvasGestures(size: CGSize, proxy: GeometryProxy) -> some Gesture {
        let manification = MagnificationGesture()
            .onChanged { value in
                handleMagnificationChange(value, size: size, proxy: proxy)
            }
            .onEnded { _ in
                handleMagnificationEnd(size: size, proxy: proxy)
            }
        let drag = DragGesture(minimumDistance: 2)
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
        return manification.simultaneously(with: drag)
    }
    
    private func handleMagnificationChange(_ value: CGFloat, size: CGSize, proxy: GeometryProxy) {
        withTransaction(.init(animation: nil)) {
            let newScale = canvas.lastScale * value // 当前缩放比例
            var finalScale = newScale
            
            // 超过最大缩放限度允许一定空间回弹
            if newScale > maxScale {
                let delta = newScale - maxScale
                finalScale = maxScale + delta * 0.3
            } else if newScale < minScale {
                let delta = minScale - newScale
                finalScale = minScale - delta * 0.3
            }

            let zoomFactor = finalScale / canvas.scale // 获取缩放变化率
            
            applyCenterCompensation(zoomFactor: zoomFactor, size: size, proxy: proxy)
            
            canvas.scale = finalScale
        }
    }
    
    private func handleMagnificationEnd(size: CGSize, proxy: GeometryProxy) {
        if canvas.scale > maxScale || canvas.scale < minScale {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if canvas.scale > maxScale {
                    let zoomFactor = maxScale / canvas.scale
                    applyCenterCompensation(zoomFactor: zoomFactor, size: size, proxy: proxy)
                    canvas.scale = maxScale
                } else if canvas.scale < minScale {
                    let zoomFactor = minScale / canvas.scale
                    applyCenterCompensation(zoomFactor: zoomFactor, size: size, proxy: proxy)
                    canvas.scale = minScale
                }
            }
        }
        
        canvas.lastScale = canvas.scale
        canvas.lastOffset = canvas.offset // 缩放过程offset变了，同步更新
    }
    
    private func toolbarContent(size: CGSize, proxy: GeometryProxy) -> some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            HStack(spacing: 4) {
                Button {
                    haptic.impactOccurred() // 震动反馈
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

        // 获取所有节点的坐标边界
        let xs = nodes.map { $0.position.x }
        let ys = nodes.map { $0.position.y }
        
        let padding: CGFloat = 60 // 增加节点半径补偿，防止边缘被切
        guard let minX = xs.min(),
              let maxX = xs.max(),
              let minY = ys.min(),
              let maxY = ys.max() else {
                return
        }

        // 2. 计算内容的总宽高
        let contentW = (maxX - minX) + padding * 2
        let contentH = (maxY - minY) + padding * 2

        // 3. 计算缩放比例， 预留一些屏幕边距 (屏幕宽度的 90%)
        let bottomInset = proxy.safeAreaInsets.bottom
        let visibleHeight = size.height - bottomInset
        let s = min((size.width * 0.9) / contentW, (visibleHeight * 0.9) / contentH, 1.5)

        // 4. 计算偏移量
        let ox = size.width / 2 - (minX + maxX) / 2 * s
        let oy = visibleHeight / 2 - (minY + maxY) / 2 * s

        withAnimation(.easeInOut) {
            canvas.scale = s
            canvas.offset = CGSize(width: ox, height: oy)
            canvas.lastScale = s
            canvas.lastOffset = canvas.offset
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

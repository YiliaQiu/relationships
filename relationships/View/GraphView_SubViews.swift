//
//  GraphView_SubViews.swift
//  relationships
//
//  Created by QBQ on 2026/4/16.
//

import SwiftUI

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
                        .allowsHitTesting(false) // 允许触摸穿透
                }
            }
        }
    }
}

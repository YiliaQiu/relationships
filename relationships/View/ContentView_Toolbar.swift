//
//  ContentView_Toolbar.swift
//  relationships
//
//  Created by QBQ on 2026/4/15.
//

import SwiftUI
import UIKit

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
}

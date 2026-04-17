//
//  ContentView_Search.swift
//  relationships
//
//  Created by QBQ on 2026/4/15.
//

import SwiftUI

extension ContentView {
    var searchView: some View {
        // 搜索栏展开状态：显示输入框和取消按钮
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.footnote)
            TextField("搜索...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .frame(width: 150)
                .focused($isSearchFocused)
                .submitLabel(.search) // 键盘回车键文字改成“搜索”
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
    
    func dismissSearch() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isSearchActive = false
            isSearchFocused = false
            viewModel.searchText = ""
        }
    }
}

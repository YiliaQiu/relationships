//
//  relationshipsTests.swift
//  relationshipsTests
//
//  Created by QBQ on 2026/4/9.
//

import Testing
import Foundation
import CoreGraphics
@testable import relationships

struct ZoomCalculator {
    static func calculateNewOffset(
        currentScale: CGFloat,
        currentOffset: CGSize,
        newScale: CGFloat,
        containerSize: CGSize
    ) -> CGSize {
        let zoomFactor = newScale / currentScale
        let centerX = containerSize.width / 2
        let centerY = containerSize.height / 2
 
        let newWidth = currentOffset.width - (zoomFactor - 1) * (centerX - currentOffset.width)
        let newHeight = currentOffset.height - (zoomFactor - 1) * (centerY - currentOffset.height)

        return CGSize(width: newWidth, height: newHeight)
    }
}

struct DragCalculator {
    static func calculateNewOffset(lastOffset: CGSize, translation: CGSize) -> CGSize {
        return CGSize(
            width: lastOffset.width + translation.width,
            height: lastOffset.height + translation.height
        )
    }
}

struct RelationshipsTests {

    @Test("验证缩放中心补偿逻辑")
    func testZoomCompensation() {
        let initialOffset = CGSize.zero
        let containerSize = CGSize(width: 400, height: 800)
        
        let result = ZoomCalculator.calculateNewOffset(currentScale: 1.0, currentOffset: initialOffset, newScale: 2.0, containerSize: containerSize)
        
        #expect(result.width == -200.0) // (2-1) * (200-0) = 200, 0 - 200 = -200
        #expect(result.height == -400.0) // (2-1) * (400-0) = 400, 0 - 400 = -400
    }
    
    @Test("验证连续拖拽的位移叠加逻辑")
    func testDragDisplacementAccumulation() {
        let startOffset = CGSize(width: 50, height: 50)
        
        let firstTranslation = CGSize(width: 100, height: 200)
        let firstResult = DragCalculator.calculateNewOffset(lastOffset: startOffset, translation: firstTranslation)
        
        #expect(firstResult.width == 150.0)
        #expect(firstResult.height == 250.0)
        
        let secondTranslation = CGSize(width: -50, height: 50)
        let secondResult = DragCalculator.calculateNewOffset(lastOffset: firstResult, translation: secondTranslation)
        
        #expect(secondResult.width == 100.0)
        #expect(secondResult.height == 300.0)
    }
    
    @Test("验证缩放倍率下的平移补偿")
    func testDragWithScale() {
        let scale: CGFloat = 0.5
        let translation = CGSize(width: 100, height: 50)
        let adjustedWidth = translation.width / scale
        let adjustedHeight = translation.height / scale
        #expect(adjustedWidth == 200.0)
        #expect(adjustedHeight == 100.0)
    }
}

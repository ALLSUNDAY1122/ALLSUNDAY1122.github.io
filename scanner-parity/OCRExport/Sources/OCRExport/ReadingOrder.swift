import Foundation

public enum OCRReadingOrder {
    public static func ordered(_ blocks: [OCRBlock], layout: OCRLayout) -> [OCRBlock] {
        switch layout {
        case .vertical:
            return blocks.sorted(by: verticalBefore)
        case .horizontal, .unknown:
            return blocks.sorted(by: horizontalBefore)
        case .mixed:
            return mixedOrder(blocks)
        }
    }

    private static func horizontalBefore(_ left: OCRBlock, _ right: OCRBlock) -> Bool {
        let lineTolerance = max(left.boundingBox.height, right.boundingBox.height) * 0.65
        let yDifference = abs(left.boundingBox.y - right.boundingBox.y)
        if yDifference > lineTolerance {
            return left.boundingBox.y > right.boundingBox.y
        }
        return left.boundingBox.x < right.boundingBox.x
    }

    private static func verticalBefore(_ left: OCRBlock, _ right: OCRBlock) -> Bool {
        let columnTolerance = max(left.boundingBox.width, right.boundingBox.width) * 0.75
        let xDifference = abs(left.boundingBox.x - right.boundingBox.x)
        if xDifference > columnTolerance {
            return left.boundingBox.x > right.boundingBox.x
        }
        return left.boundingBox.y > right.boundingBox.y
    }

    private static func mixedOrder(_ blocks: [OCRBlock]) -> [OCRBlock] {
        let vertical = blocks.filter { $0.boundingBox.height >= $0.boundingBox.width * 1.6 }
        let remaining = blocks.filter { $0.boundingBox.height < $0.boundingBox.width * 1.6 }
        if vertical.count >= remaining.count {
            return vertical.sorted(by: verticalBefore) + remaining.sorted(by: horizontalBefore)
        }
        return remaining.sorted(by: horizontalBefore) + vertical.sorted(by: verticalBefore)
    }
}

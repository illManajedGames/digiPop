import CoreGraphics

enum BoardShape: String, CaseIterable {
    case grid4x4
    case grid4x5
    case grid5x4
    case grid4x6
    case grid5x5
    case grid5x6
    case grid5x7
    case grid4x7
 //   case grid6x9
    case hexagon
    case key
    case cross
    case droid

    var displayName: String {
        switch self {
        case .grid4x4: return "Classic 4x4"
        case .grid4x5: return "Classic 4x5"
        case .grid5x4: return "Classic 5x4"
        case .grid4x6: return "Classic 4x6"
        case .grid5x5: return "Classic 5x5"
        case .grid5x6: return "Classic 5x6"
        case .grid5x7: return "Classic 5x7"
        case .grid4x7: return "Classic 4x7"
  //      case .grid6x9: return "Classic 6x9"
        case .hexagon: return "Hexagonal"
        case .key:     return "Key"
        case .cross:   return "Cross"
        case .droid:   return "Droid"
        }
    }

    var unlockPops: Int {
        switch self {
        case .grid4x4: return 0
        case .grid4x5: return 175
        case .grid5x4: return 325
        case .hexagon: return 550
        case .grid4x6: return 825
        case .cross:   return 1125
        case .grid5x5: return 1525
        case .key:     return 1950
        case .grid5x6: return 2500
        case .grid5x7: return 3200
        case .grid4x7: return 4100
        case .droid:   return 5000
        }
    }

    // Returns bubble center positions (relative to board center) for a given bubble diameter.
    func bubblePositions(bubbleSize: CGFloat) -> [CGPoint] {
        let s = bubbleSize * 1.2  // center-to-center spacing
        switch self {
        case .grid4x4: return grid(cols: 4, rows: 4, s: s)
        case .grid4x5: return grid(cols: 4, rows: 5, s: s)
        case .grid5x4: return grid(cols: 5, rows: 4, s: s)
        case .grid4x6: return grid(cols: 4, rows: 6, s: s)
        case .grid5x5: return grid(cols: 5, rows: 5, s: s)
        case .grid5x6: return grid(cols: 5, rows: 6, s: s)
        case .grid5x7: return grid(cols: 5, rows: 7, s: s)
        case .grid4x7: return grid(cols: 4, rows: 7, s: s)
 //       case .grid6x9: return grid(cols: 6, rows: 9, s: s)
        case .hexagon: return hexGrid(s: s)
        case .key:     return keyGrid(s: s)
        case .cross:   return crossGrid(s: s)
        case .droid:   return droidGrid(s: s)
        }
    }

    // MARK: - Shape generators

    private func grid(cols: Int, rows: Int, s: CGFloat) -> [CGPoint] {
        var pts: [CGPoint] = []
        let ox = CGFloat(cols - 1) * s / 2
        let oy = CGFloat(rows - 1) * s / 2
        for row in 0..<rows {
            for col in 0..<cols {
                pts.append(CGPoint(x: CGFloat(col) * s - ox, y: CGFloat(row) * s - oy))
            }
        }
        return pts
    }

    private func hexGrid(s: CGFloat) -> [CGPoint] {
        // Row widths: 3-4-5-4-3 = 19 bubbles; rows are offset for hex packing
        let rowCounts = [3, 4, 5, 4, 3]
        let rowH = s * 0.866  // sin(60°)
        let totalH = CGFloat(rowCounts.count - 1) * rowH
        var pts: [CGPoint] = []
        for (r, count) in rowCounts.enumerated() {
            let y = CGFloat(r) * rowH - totalH / 2
            let rowW = CGFloat(count - 1) * s / 2
            for c in 0..<count {
                pts.append(CGPoint(x: CGFloat(c) * s - rowW, y: y))
            }
        }
        return pts
    }

    private func droidGrid(s: CGFloat) -> [CGPoint] {
        // R2D2 silhouette: 5 cols (0-4), 7 rows (0-6), cx=2, cy=3
        // Dome: 3 wide (cols 1-3) row 6, full width row 5
        // Body: full width rows 2-4
        // Legs: 2-wide pairs (cols 0-1 and cols 3-4), rows 0-1
        let cells: [(Int, Int)] = [
            (1,6),(2,6),(3,6),
            (0,5),(1,5),(2,5),(3,5),(4,5),
            (0,4),(1,4),(2,4),(3,4),(4,4),
            (0,3),(1,3),(2,3),(3,3),(4,3),
            (0,2),(1,2),(2,2),(3,2),(4,2),
            (1,1),(3,1),
            (1,0),(3,0)
        ]
        return cells.map { CGPoint(x: (CGFloat($0.0) - 1.5) * s, y: (CGFloat($0.1) - 3.5) * s) }
    }

    private func crossGrid(s: CGFloat) -> [CGPoint] {
        // Symmetric +: bar at rows 3-4 (y=±0.5s), 3 narrow rows above and below
        let cells: [(Int, Int)] = [
            (1,1),(2,1),
            (1,2),(2,2),
            (1,3),(2,3),
            (0,4),(1,4),(2,4),(3,4),
            (0,5),(1,5),(2,5),(3,5),
            (1,6),(2,6)
        ]
        return cells.map { CGPoint(x: (CGFloat($0.0) - 1.5) * s, y: (CGFloat($0.1) - 3.5) * s) }
    }

    private func keyGrid(s: CGFloat) -> [CGPoint] {
        // Asymmetric key: shaft + single-sided teeth (cols 2-3), wide handle at bottom
        let cells: [(Int, Int)] = [
            (2,6),
            (2,5),(3,5),
            (2,4),(2,5),
            (2,3),
            (1,2),(2,2),(3,2),
            (1,1),(3,1),
            (1,0),(2,0),(3,0)
        ]
        return cells.map { CGPoint(x: (CGFloat($0.0) - 2) * s, y: (CGFloat($0.1) - 3.5) * s) }
    }
}

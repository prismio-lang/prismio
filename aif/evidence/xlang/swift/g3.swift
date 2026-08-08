// G3 scene graph -- Swift, idiomatic.
//
// `[Node]` with parent/child links as indices, matching the corpus program. Node
// holds Transform and Bounds as stored struct properties, so a node is one
// inline record and the array is one allocation.

let FRAMES = 10000
let BREADTH = 4
let DEPTH = 5

struct Transform {
    var px: Double
    var py: Double
    var pz: Double
    var sx: Double
    var sy: Double
    var sz: Double
}

struct Bounds {
    var minX: Double
    var minY: Double
    var minZ: Double
    var maxX: Double
    var maxY: Double
    var maxZ: Double
}

struct Node {
    var local: Transform
    var world: Transform
    var bounds: Bounds
    var parent: Int
    var firstChild: Int
    var nextSibling: Int
    var dirty: Bool
}

func identityTransform() -> Transform {
    return Transform(px: 0.0, py: 0.0, pz: 0.0, sx: 1.0, sy: 1.0, sz: 1.0)
}

func unitBounds() -> Bounds {
    return Bounds(minX: 0.0, minY: 0.0, minZ: 0.0,
                  maxX: 1.0, maxY: 1.0, maxZ: 1.0)
}

func makeNode(_ parent: Int, _ ox: Double) -> Node {
    var t = identityTransform()
    t.px = ox
    return Node(local: t, world: identityTransform(), bounds: unitBounds(),
                parent: parent, firstChild: -1, nextSibling: -1, dirty: true)
}

func linkChild(_ nodes: inout [Node], _ parentIdx: Int, _ childIdx: Int) {
    if nodes[parentIdx].firstChild < 0 {
        nodes[parentIdx].firstChild = childIdx
    } else {
        var sib = nodes[parentIdx].firstChild
        while true {
            if nodes[sib].nextSibling < 0 {
                nodes[sib].nextSibling = childIdx
                break
            }
            sib = nodes[sib].nextSibling
        }
    }
}

func buildHierarchy(_ breadth: Int, _ depth: Int) -> [Node] {
    var nodes: [Node] = []
    nodes.append(makeNode(-1, 0.0))

    var level = 0
    var levelStart = 0
    var levelCount = 1

    while level < depth {
        let nextStart = nodes.count
        var parentOff = 0
        while parentOff < levelCount {
            let parentIdx = levelStart + parentOff
            var b = 0
            var ox = 0.0
            while b < breadth {
                let childIdx = nodes.count
                nodes.append(makeNode(parentIdx, ox))
                linkChild(&nodes, parentIdx, childIdx)
                ox += 1.0
                b += 1
            }
            parentOff += 1
        }
        levelStart = nextStart
        levelCount = nodes.count - nextStart
        level += 1
    }
    return nodes
}

func propagate(_ nodes: inout [Node], _ idx: Int,
               _ ox: Double, _ oy: Double, _ oz: Double) -> Int {
    nodes[idx].world.px = nodes[idx].local.px + ox
    nodes[idx].world.py = nodes[idx].local.py + oy
    nodes[idx].world.pz = nodes[idx].local.pz + oz
    nodes[idx].dirty = false

    let wx = nodes[idx].world.px
    let wy = nodes[idx].world.py
    let wz = nodes[idx].world.pz

    var visited = 1
    var c = nodes[idx].firstChild
    while c >= 0 {
        visited += propagate(&nodes, c, wx, wy, wz)
        c = nodes[c].nextSibling
    }
    return visited
}

func countVisible(_ nodes: [Node], _ limit: Double) -> Int {
    var visible = 0
    for n in nodes where n.world.px < limit && n.world.py < limit && n.world.pz < limit {
        visible += 1
    }
    return visible
}

@main
struct G3 {
    static func main() {
        var nodes = buildHierarchy(BREADTH, DEPTH)
        var frames = Frames(FRAMES)
        var visited = 0
        var visible = 0

        for frame in 0..<FRAMES {
            let t0 = nowNs()
            visited = propagate(&nodes, 0, 0.0, 0.0, 0.0)
            visible = countVisible(nodes, 1000.0)
            let t1 = nowNs()
            frames.set(frame, t1 - t0)
        }

        report([("nodes", nodes.count),
                ("visited", visited),
                ("visible", visible)], frames)
    }
}

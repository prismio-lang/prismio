// G2 frame loop -- Swift, idiomatic.
//
// `cull` returns a fresh `[DrawCmd]` each frame, which is released at the end of
// the frame. Elements are structs, so the array is one contiguous allocation and
// there is no ARC traffic per command -- the per-frame allocation count is the
// array's growth sequence, not one per DrawCmd.

let FRAMES = 20000
let COUNT = 1000

struct DrawCmd {
    var meshId: Int
    var materialId: Int
    var depth: Double
    var visible: Bool
}

struct Renderable {
    var meshId: Int
    var materialId: Int
    var x: Double
    var y: Double
    var z: Double
    var radius: Double
}

func buildScene(_ count: Int) -> [Renderable] {
    var scene: [Renderable] = []
    var f = 0.0
    for i in 0..<count {
        scene.append(Renderable(meshId: i, materialId: i,
                                x: f, y: f, z: f, radius: 1.0))
        f += 1.0
    }
    return scene
}

func cull(_ scene: [Renderable], _ near: Double, _ far: Double) -> [DrawCmd] {
    var cmds: [DrawCmd] = []
    for r in scene where r.z >= near && r.z <= far {
        cmds.append(DrawCmd(meshId: r.meshId, materialId: r.materialId,
                            depth: r.z, visible: true))
    }
    return cmds
}

func submit(_ cmds: [DrawCmd]) -> Int {
    var drawn = 0
    for c in cmds where c.visible { drawn += 1 }
    return drawn
}

@main
struct G2 {
    static func main() {
        let scene = buildScene(COUNT)
        var frames = Frames(FRAMES)
        var submitted = 0
        var culled = 0

        for frame in 0..<FRAMES {
            let t0 = nowNs()
            let cmds = cull(scene, 0.0, 500.0)
            let drawn = submit(cmds)
            let t1 = nowNs()
            submitted += drawn
            culled += COUNT - drawn
            frames.set(frame, t1 - t0)
        }

        report([("submitted", submitted), ("culled", culled)], frames)
    }
}

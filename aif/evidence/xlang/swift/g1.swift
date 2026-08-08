// G1 particles -- Swift, idiomatic.
//
// A `struct` in an `Array`. That is the Swift idiom for bulk numeric data and it
// stores elements inline and contiguously, so it is the direct analogue of
// Rust's `Vec<Particle>` rather than of Prismio's vector of pointers.
//
// A `final class Particle` would be the other reading of "idiomatic", and it
// would put every particle behind a pointer *and* under ARC. It is not what a
// competent Swift programmer writes for a particle system, and choosing it here
// would be measuring ARC rather than the language.

let FRAMES = 6000
let COUNT = 2000

struct Particle {
    var px: Double
    var py: Double
    var pz: Double
    var vx: Double
    var vy: Double
    var vz: Double
    var r: Double
    var g: Double
    var b: Double
    var a: Double
    var life: Double
    var size: Double
}

func spawnParticle(_ f: Double) -> Particle {
    return Particle(px: f, py: f, pz: 0.0,
                    vx: 1.0, vy: 2.0, vz: 0.0,
                    r: 1.0, g: 1.0, b: 1.0, a: 1.0,
                    life: 100.0, size: 1.0)
}

func buildSystem(_ count: Int) -> [Particle] {
    var ps: [Particle] = []
    var f = 0.0
    for _ in 0..<count {
        ps.append(spawnParticle(f))
        f += 1.0
    }
    return ps
}

func integrate(_ ps: inout [Particle], _ dt: Double) {
    for i in 0..<ps.count {
        ps[i].px += ps[i].vx * dt
        ps[i].py += ps[i].vy * dt
        ps[i].pz += ps[i].vz * dt
    }
}

func fade(_ ps: inout [Particle], _ dt: Double) {
    for i in 0..<ps.count {
        ps[i].life -= dt
        ps[i].a = ps[i].life * 0.01
    }
}

func countAlive(_ ps: [Particle]) -> Int {
    var alive = 0
    for p in ps where p.life > 0.0 { alive += 1 }
    return alive
}

func countBeyond(_ ps: [Particle], _ limit: Double) -> Int {
    var beyond = 0
    for p in ps where p.px > limit { beyond += 1 }
    return beyond
}

@main
struct G1 {
    static func main() {
        var ps = buildSystem(COUNT)
        let dt = 0.016
        var frames = Frames(FRAMES)

        for frame in 0..<FRAMES {
            let t0 = nowNs()
            integrate(&ps, dt)
            fade(&ps, dt)
            let t1 = nowNs()
            frames.set(frame, t1 - t0)
        }

        report([("alive", countAlive(ps)),
                ("beyond", countBeyond(ps, 1000.5))], frames)
    }
}

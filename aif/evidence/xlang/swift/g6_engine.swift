// G6 engine module -- Swift. The API surface gameplay code sees.
//
// A direct port of aif/corpus/g6_engine.psm. The World is a `final class` -- it
// is the owned, mutated aggregate -- and every component record is a struct
// stored inline in an Array. The API is handle-based, so gameplay holds Ints and
// never a reference into engine storage.

struct EngTransform {
    var x: Double
    var y: Double
    var z: Double
    var yaw: Double
}

struct EngVelocity {
    var dx: Double
    var dy: Double
    var dz: Double
}

struct Actor {
    var transform: Int
    var velocity: Int
    var health: Int
    var maxHealth: Int
    var team: Int
    var alive: Bool
}

final class World {
    var actors: [Actor] = []
    var transforms: [EngTransform] = []
    var velocities: [EngVelocity] = []
    var tick = 0
    var spawned = 0
    var killed = 0
}

func worldCreate() -> World {
    return World()
}

func worldSpawn(_ w: World, _ x: Double, _ y: Double, _ team: Int) -> Int {
    let handle = w.actors.count
    w.transforms.append(EngTransform(x: x, y: y, z: 0.0, yaw: 0.0))
    w.velocities.append(EngVelocity(dx: 0.0, dy: 0.0, dz: 0.0))
    w.actors.append(Actor(transform: handle, velocity: handle,
                          health: 100, maxHealth: 100,
                          team: team, alive: true))
    w.spawned += 1
    return handle
}

func worldTransform(_ w: World, _ h: Int) -> EngTransform {
    return w.transforms[h]
}

func worldActor(_ w: World, _ h: Int) -> Actor {
    return w.actors[h]
}

func worldSetVelocity(_ w: World, _ h: Int, _ dx: Double, _ dy: Double) {
    w.velocities[h].dx = dx
    w.velocities[h].dy = dy
}

func worldDamage(_ w: World, _ h: Int, _ amount: Int) -> Bool {
    if !w.actors[h].alive { return false }
    w.actors[h].health -= amount
    if w.actors[h].health <= 0 {
        w.actors[h].health = 0
        w.actors[h].alive = false
        w.killed += 1
        return true
    }
    return false
}

func worldStep(_ w: World, _ dt: Double) {
    for i in 0..<w.actors.count where w.actors[i].alive {
        let ti = w.actors[i].transform
        let vi = w.actors[i].velocity
        let v = w.velocities[vi]
        w.transforms[ti].x += v.dx * dt
        w.transforms[ti].y += v.dy * dt
        w.transforms[ti].z += v.dz * dt
    }
    w.tick += 1
}

func worldCountAlive(_ w: World) -> Int {
    var alive = 0
    for a in w.actors where a.alive { alive += 1 }
    return alive
}

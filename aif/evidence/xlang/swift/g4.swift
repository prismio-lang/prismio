// G4 ECS world -- Swift, idiomatic.
//
// Components are structs in Arrays; the World that owns those arrays and is
// mutated by every system is a `final class`. That split is the Swift idiom: an
// entity manager has reference semantics, its component records have value
// semantics. Making World a struct would mean passing it `inout` everywhere and
// retaining five array buffers on every by-value read.

let FRAMES = 10000
let ENTITIES = 1500

struct Position { var x: Double; var y: Double; var z: Double }
struct Velocity { var dx: Double; var dy: Double; var dz: Double }
struct Physics { var mass: Double; var drag: Double; var restitution: Double }

struct Sprite {
    var textureId: Int
    var layer: Int
    var tintR: Double
    var tintG: Double
    var tintB: Double
    var alpha: Double
}

struct Health { var current: Int; var maximum: Int; var regen: Double }

final class World {
    var positions: [Position] = []
    var velocities: [Velocity] = []
    var physics: [Physics] = []
    var sprites: [Sprite] = []
    var health: [Health] = []
    var entityCount = 0
}

func spawn(_ w: World, _ seed: Double) {
    w.positions.append(Position(x: seed, y: seed, z: 0.0))
    w.velocities.append(Velocity(dx: 1.0, dy: 0.5, dz: 0.0))
    w.physics.append(Physics(mass: 1.0, drag: 0.01, restitution: 0.5))
    w.sprites.append(Sprite(textureId: 1, layer: 0,
                            tintR: 1.0, tintG: 1.0, tintB: 1.0, alpha: 1.0))
    w.health.append(Health(current: 100, maximum: 100, regen: 0.1))
    w.entityCount += 1
}

// System 1: writes Position, reads Velocity.
func systemMovement(_ w: World, _ dt: Double) {
    for i in 0..<w.entityCount {
        let v = w.velocities[i]
        w.positions[i].x += v.dx * dt
        w.positions[i].y += v.dy * dt
        w.positions[i].z += v.dz * dt
    }
}

// System 2: writes Velocity, reads Physics.
func systemPhysics(_ w: World, _ dt: Double) {
    for i in 0..<w.entityCount {
        let k = 1.0 - w.physics[i].drag * dt
        w.velocities[i].dx *= k
        w.velocities[i].dy = w.velocities[i].dy * k - 9.81 * dt
        w.velocities[i].dz *= k
    }
}

// System 3: reads Position and Sprite.
func systemRender(_ w: World) -> Int {
    var drawn = 0
    for i in 0..<w.entityCount {
        if w.sprites[i].alpha > 0.0 && w.positions[i].y > -100.0 {
            drawn += 1
        }
    }
    return drawn
}

// System 4: writes Health only.
func systemRegen(_ w: World) {
    for i in 0..<w.entityCount {
        if w.health[i].current < w.health[i].maximum {
            w.health[i].current += 1
        }
    }
}

@main
struct G4 {
    static func main() {
        let w = World()
        var seed = 0.0
        for _ in 0..<ENTITIES {
            spawn(w, seed)
            seed += 1.0
        }

        let dt = 0.016
        var frames = Frames(FRAMES)
        var totalDrawn = 0

        for frame in 0..<FRAMES {
            let t0 = nowNs()
            systemPhysics(w, dt)
            systemMovement(w, dt)
            systemRegen(w)
            let drawn = systemRender(w)
            let t1 = nowNs()
            totalDrawn += drawn
            frames.set(frame, t1 - t0)
        }

        report([("entities", w.entityCount), ("draws", totalDrawn)], frames)
    }
}

// G6 gameplay module -- Swift, idiomatic.
//
// Ported from aif/corpus/g6_game.psm, importing the engine module unchanged, so
// the module boundary the corpus program exists to test survives the port.
//
// `planOrders` builds a fresh `[Order]` per squad per tick and releases it at
// the end of the tick. Order is a struct, so that is one array allocation per
// squad per tick, not one per order.

let SCENARIOS = 300
let TICKS = 100
let SQUAD = 400

struct Member {
    var actor: Int
    var role: Int
    var kills: Int
}

final class Squad {
    var members: [Member] = []
    var team: Int
    var morale = 100
    var rallyX: Double
    var rallyY: Double

    init(team: Int, rallyX: Double, rallyY: Double) {
        self.team = team
        self.rallyX = rallyX
        self.rallyY = rallyY
    }
}

struct Order {
    var target: Int
    var dx: Double
    var dy: Double
    var priority: Int
}

func makeSquad(_ team: Int, _ rx: Double, _ ry: Double) -> Squad {
    return Squad(team: team, rallyX: rx, rallyY: ry)
}

func recruit(_ w: World, _ s: Squad, _ count: Int) {
    var f = 0.0
    for _ in 0..<count {
        let h = worldSpawn(w, s.rallyX + f, s.rallyY + f, s.team)
        s.members.append(Member(actor: h, role: 0, kills: 0))
        f += 2.0
    }
}

func planOrders(_ w: World, _ s: Squad) -> [Order] {
    var orders: [Order] = []
    for mem in s.members {
        let h = mem.actor
        let a = worldActor(w, h)
        if a.alive {
            let t = worldTransform(w, h)
            let dx = s.rallyX - t.x
            let dy = s.rallyY - t.y
            let pri = a.health < 50 ? 3 : 1
            orders.append(Order(target: h, dx: dx, dy: dy, priority: pri))
        }
    }
    return orders
}

func applyOrders(_ w: World, _ orders: [Order], _ speed: Double) -> Int {
    var applied = 0
    for o in orders {
        worldSetVelocity(w, o.target, o.dx * speed, o.dy * speed)
        applied += 1
    }
    return applied
}

func resolveCombat(_ w: World, _ a: Squad, _ b: Squad) -> Int {
    let na = a.members.count
    let nb = b.members.count
    var kills = 0
    var i = 0
    while i < na && i < nb {
        if worldActor(w, a.members[i].actor).alive {
            if worldDamage(w, b.members[i].actor, 7) {
                a.members[i].kills += 1
                kills += 1
            }
        }
        i += 1
    }
    if kills > 0 { b.morale -= kills }
    return kills
}

@main
struct G6 {
    static func main() {
        let frameCount = SCENARIOS * TICKS
        var frames = Frames(frameCount)
        let dt = 0.016

        var totalAlive = 0
        var totalOrders = 0
        var totalKills = 0
        var slot = 0

        for _ in 0..<SCENARIOS {
            let w = worldCreate()
            let red = makeSquad(0, 0.0, 0.0)
            let blue = makeSquad(1, 100.0, 100.0)
            recruit(w, red, SQUAD)
            recruit(w, blue, SQUAD)

            for _ in 0..<TICKS {
                let t0 = nowNs()
                let redOrders = planOrders(w, red)
                let blueOrders = planOrders(w, blue)
                let appliedR = applyOrders(w, redOrders, 1.0)
                let appliedB = applyOrders(w, blueOrders, 1.0)
                worldStep(w, dt)
                let kills = resolveCombat(w, red, blue)
                let t1 = nowNs()

                totalOrders += appliedR + appliedB
                totalKills += kills
                frames.set(slot, t1 - t0)
                slot += 1
            }
            totalAlive += worldCountAlive(w)
        }

        report([("alive", totalAlive),
                ("orders", totalOrders),
                ("kills", totalKills)], frames)
    }
}

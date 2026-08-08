// G6 engine + gameplay -- Rust, hand-tuned.
//
// Two changes, both of which remove allocation rather than making it cheaper:
//
//  1. The two order buffers are allocated once, outside every loop, and cleared
//     per tick. In steady state a tick allocates nothing.
//  2. The world and the two squads are reused across scenarios: their vectors
//     are cleared instead of dropped, so the 2400 engine records and 800 squad
//     members are allocated once for the whole run rather than once per
//     scenario. `world_reset` is the engine-side half of that.
//
// The second change is the interesting one for this comparison. It is not a
// memory-model transformation at all -- no arena and no inference can turn "a
// fresh World per scenario" into "one World, cleared", because that is a
// statement about what the program means, not about where its objects live.

#[path = "harness.rs"]
mod harness;

const SCENARIOS: usize = 300;
const TICKS: usize = 100;
const SQUAD: usize = 400;

mod engine {
    pub struct Transform {
        pub x: f64,
        pub y: f64,
        pub z: f64,
        pub yaw: f64,
    }

    pub struct Velocity {
        pub dx: f64,
        pub dy: f64,
        pub dz: f64,
    }

    pub struct Actor {
        pub transform: i64,
        pub velocity: i64,
        pub health: i64,
        pub max_health: i64,
        pub team: i64,
        pub alive: bool,
    }

    pub struct World {
        pub actors: Vec<Actor>,
        pub transforms: Vec<Transform>,
        pub velocities: Vec<Velocity>,
        pub tick: i64,
        pub spawned: i64,
        pub killed: i64,
    }

    pub fn world_create() -> World {
        World {
            actors: Vec::new(),
            transforms: Vec::new(),
            velocities: Vec::new(),
            tick: 0,
            spawned: 0,
            killed: 0,
        }
    }

    /// Empties the world without releasing its storage, so the next scenario
    /// refills the same allocations.
    pub fn world_reset(w: &mut World) {
        w.actors.clear();
        w.transforms.clear();
        w.velocities.clear();
        w.tick = 0;
        w.spawned = 0;
        w.killed = 0;
    }

    #[inline]
    pub fn world_spawn(w: &mut World, x: f64, y: f64, team: i64) -> i64 {
        let handle = w.actors.len() as i64;
        w.transforms.push(Transform { x, y, z: 0.0, yaw: 0.0 });
        w.velocities.push(Velocity { dx: 0.0, dy: 0.0, dz: 0.0 });
        w.actors.push(Actor {
            transform: handle,
            velocity: handle,
            health: 100,
            max_health: 100,
            team,
            alive: true,
        });
        w.spawned += 1;
        handle
    }

    #[inline]
    pub fn world_set_velocity(w: &mut World, h: i64, dx: f64, dy: f64) {
        let v = &mut w.velocities[h as usize];
        v.dx = dx;
        v.dy = dy;
    }

    #[inline]
    pub fn world_damage(w: &mut World, h: i64, amount: i64) -> bool {
        let a = &mut w.actors[h as usize];
        if !a.alive {
            return false;
        }
        a.health -= amount;
        if a.health <= 0 {
            a.health = 0;
            a.alive = false;
            w.killed += 1;
            return true;
        }
        false
    }

    #[inline]
    pub fn world_step(w: &mut World, dt: f64) {
        let n = w.actors.len();
        let actors = &w.actors[..n];
        let vel = &w.velocities[..n];
        let tr = &mut w.transforms[..n];
        for i in 0..n {
            let a = &actors[i];
            if a.alive {
                let v = &vel[a.velocity as usize];
                let t = &mut tr[a.transform as usize];
                t.x += v.dx * dt;
                t.y += v.dy * dt;
                t.z += v.dz * dt;
            }
        }
        w.tick += 1;
    }

    pub fn world_count_alive(w: &World) -> i64 {
        let mut alive = 0;
        for a in &w.actors {
            if a.alive {
                alive += 1;
            }
        }
        alive
    }
}

use engine::*;

struct Member {
    actor: i64,
    role: i64,
    kills: i64,
}

struct Squad {
    members: Vec<Member>,
    team: i64,
    morale: i64,
    rally_x: f64,
    rally_y: f64,
}

struct Order {
    target: i64,
    dx: f64,
    dy: f64,
    priority: i64,
}

fn make_squad(team: i64, rx: f64, ry: f64) -> Squad {
    Squad {
        members: Vec::new(),
        team,
        morale: 100,
        rally_x: rx,
        rally_y: ry,
    }
}

fn squad_reset(s: &mut Squad, team: i64, rx: f64, ry: f64) {
    s.members.clear();
    s.team = team;
    s.morale = 100;
    s.rally_x = rx;
    s.rally_y = ry;
}

fn recruit(w: &mut World, s: &mut Squad, count: usize) {
    let mut f = 0.0;
    for _ in 0..count {
        let h = world_spawn(w, s.rally_x + f, s.rally_y + f, s.team);
        s.members.push(Member { actor: h, role: 0, kills: 0 });
        f += 2.0;
    }
}

#[inline]
fn plan_orders_into(orders: &mut Vec<Order>, w: &World, s: &Squad) {
    orders.clear();
    for mem in &s.members {
        let h = mem.actor;
        let a = &w.actors[h as usize];
        if a.alive {
            let t = &w.transforms[h as usize];
            let dx = s.rally_x - t.x;
            let dy = s.rally_y - t.y;
            let pri = if a.health < 50 { 3 } else { 1 };
            orders.push(Order { target: h, dx, dy, priority: pri });
        }
    }
}

#[inline]
fn apply_orders(w: &mut World, orders: &[Order], speed: f64) -> i64 {
    let mut applied = 0;
    for o in orders {
        world_set_velocity(w, o.target, o.dx * speed, o.dy * speed);
        applied += 1;
    }
    applied
}

fn resolve_combat(w: &mut World, a: &mut Squad, b: &mut Squad) -> i64 {
    let na = a.members.len();
    let nb = b.members.len();
    let mut kills = 0;
    let mut i = 0;
    while i < na && i < nb {
        if w.actors[a.members[i].actor as usize].alive {
            let target = b.members[i].actor;
            if world_damage(w, target, 7) {
                a.members[i].kills += 1;
                kills += 1;
            }
        }
        i += 1;
    }
    if kills > 0 {
        b.morale -= kills;
    }
    kills
}

fn main() {
    let frames = SCENARIOS * TICKS;
    let mut frame_log = harness::Frames::new(frames);
    let dt = 0.016;

    let mut total_alive: i64 = 0;
    let mut total_orders: i64 = 0;
    let mut total_kills: i64 = 0;
    let mut slot = 0usize;

    let mut w = world_create();
    let mut red = make_squad(0, 0.0, 0.0);
    let mut blue = make_squad(1, 100.0, 100.0);
    let mut red_orders: Vec<Order> = Vec::with_capacity(SQUAD);
    let mut blue_orders: Vec<Order> = Vec::with_capacity(SQUAD);

    for _ in 0..SCENARIOS {
        world_reset(&mut w);
        squad_reset(&mut red, 0, 0.0, 0.0);
        squad_reset(&mut blue, 1, 100.0, 100.0);
        recruit(&mut w, &mut red, SQUAD);
        recruit(&mut w, &mut blue, SQUAD);

        for _ in 0..TICKS {
            let t0 = harness::now_ns();
            plan_orders_into(&mut red_orders, &w, &red);
            plan_orders_into(&mut blue_orders, &w, &blue);
            let applied_r = apply_orders(&mut w, &red_orders, 1.0);
            let applied_b = apply_orders(&mut w, &blue_orders, 1.0);
            world_step(&mut w, dt);
            let kills = resolve_combat(&mut w, &mut red, &mut blue);
            let t1 = harness::now_ns();

            total_orders += applied_r + applied_b;
            total_kills += kills;
            frame_log.set(slot, t1 - t0);
            slot += 1;
        }
        total_alive += world_count_alive(&w);
    }

    harness::report(
        &[
            ("alive", total_alive),
            ("orders", total_orders),
            ("kills", total_kills),
        ],
        &frame_log,
    );
}

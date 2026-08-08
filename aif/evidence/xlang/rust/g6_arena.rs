// G6 engine + gameplay -- Rust, arena-tuned (bumpalo).
//
// Identical to g6_idiomatic.rs except that the two per-tick order lists come out
// of a `Bump` that is reset at the top of each tick. The engine module is the
// same file, unchanged, which is the point: the arena is a gameplay-side change,
// and the engine's retained storage is untouched by it.
//
// This is the shape AIF's automatic arena placement is supposed to find on its
// own -- a scope whose allocations all die at the scope's end.

#[path = "harness.rs"]
mod harness;

#[path = "g6_engine.rs"]
mod engine;

use bumpalo::Bump;
use bumpalo::collections::Vec as BVec;
use engine::*;

const SCENARIOS: usize = 300;
const TICKS: usize = 100;
const SQUAD: usize = 400;

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

fn recruit(w: &mut World, s: &mut Squad, count: usize) {
    let mut f = 0.0;
    for _ in 0..count {
        let h = world_spawn(w, s.rally_x + f, s.rally_y + f, s.team);
        s.members.push(Member { actor: h, role: 0, kills: 0 });
        f += 2.0;
    }
}

fn plan_orders<'a>(bump: &'a Bump, w: &World, s: &Squad) -> BVec<'a, Order> {
    let mut orders = BVec::new_in(bump);
    for mem in &s.members {
        let h = mem.actor;
        let a = world_actor(w, h);
        if a.alive {
            let t = world_transform(w, h);
            let dx = s.rally_x - t.x;
            let dy = s.rally_y - t.y;
            let pri = if a.health < 50 { 3 } else { 1 };
            orders.push(Order { target: h, dx, dy, priority: pri });
        }
    }
    orders
}

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
        let attacker_alive = world_actor(w, a.members[i].actor).alive;
        if attacker_alive {
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
    let mut bump = Bump::new();

    for _ in 0..SCENARIOS {
        let mut w = world_create();
        let mut red = make_squad(0, 0.0, 0.0);
        let mut blue = make_squad(1, 100.0, 100.0);
        recruit(&mut w, &mut red, SQUAD);
        recruit(&mut w, &mut blue, SQUAD);

        for _ in 0..TICKS {
            let t0 = harness::now_ns();
            bump.reset();
            let (applied_r, applied_b) = {
                let red_orders = plan_orders(&bump, &w, &red);
                let blue_orders = plan_orders(&bump, &w, &blue);
                let r = apply_orders(&mut w, &red_orders, 1.0);
                let b = apply_orders(&mut w, &blue_orders, 1.0);
                (r, b)
            };
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

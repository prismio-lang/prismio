// G6 engine module -- Rust. The API surface gameplay code sees.
//
// A direct port of aif/corpus/g6_engine.psm. It owns all the arrays; gameplay
// owns none of them. The API is handle-based: `world_spawn` returns an i64 and
// every later call takes it back, so gameplay never holds a reference into
// engine storage.
//
// Shared by g6_idiomatic.rs and g6_arena.rs via `#[path]`, so those two differ
// only in how gameplay allocates its per-tick orders -- which is the one thing
// the arena variant is meant to change.

#![allow(dead_code)]

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

pub fn world_transform(w: &World, h: i64) -> &Transform {
    &w.transforms[h as usize]
}

pub fn world_actor(w: &World, h: i64) -> &Actor {
    &w.actors[h as usize]
}

pub fn world_set_velocity(w: &mut World, h: i64, dx: f64, dy: f64) {
    let v = &mut w.velocities[h as usize];
    v.dx = dx;
    v.dy = dy;
}

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

pub fn world_step(w: &mut World, dt: f64) {
    let n = w.actors.len();
    for i in 0..n {
        let a = &w.actors[i];
        if a.alive {
            let (ti, vi) = (a.transform as usize, a.velocity as usize);
            let (dx, dy, dz) = {
                let v = &w.velocities[vi];
                (v.dx, v.dy, v.dz)
            };
            let t = &mut w.transforms[ti];
            t.x += dx * dt;
            t.y += dy * dt;
            t.z += dz * dt;
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

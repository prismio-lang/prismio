// G5 asset cache -- Rust, idiomatic.
//
// Entities hold handles (indices) into the cache's vectors, exactly as the
// corpus program does. RESULTS-L0 3a's observation carries over unchanged: a
// handle is not a reference, so nothing here needs `Rc` and nothing here is
// shared ownership in Rust's sense either. The program written to force T3
// forces no `Rc` in Rust for the same reason it forces no T3 in Prismio.
//
// Nothing is allocated per frame; `render_batched` is a 12 x 2000 nested scan.

#[path = "harness.rs"]
mod harness;

const FRAMES: usize = 4000;
const ENTITIES: usize = 2000;

struct Mesh {
    vertex_count: i64,
    index_count: i64,
    bounds_radius: f64,
    lod_levels: i64,
    ref_count: i64,
    resident: bool,
}

struct Material {
    shader_id: i64,
    base_r: f64,
    base_g: f64,
    base_b: f64,
    roughness: f64,
    metallic: f64,
    texture: i64,
    ref_count: i64,
}

struct Texture {
    width: i64,
    height: i64,
    format: i64,
    mip_levels: i64,
    bytes: i64,
    ref_count: i64,
    resident: bool,
}

struct AssetCache {
    meshes: Vec<Mesh>,
    materials: Vec<Material>,
    textures: Vec<Texture>,
    resident_bytes: i64,
    budget_bytes: i64,
}

struct Entity {
    mesh: i64,
    material: i64,
    x: f64,
    y: f64,
    z: f64,
    visible: bool,
}

struct Scene {
    entities: Vec<Entity>,
    cache: AssetCache,
    draw_calls: i64,
    batches: i64,
}

fn make_cache(budget: i64) -> AssetCache {
    AssetCache {
        meshes: Vec::new(),
        materials: Vec::new(),
        textures: Vec::new(),
        resident_bytes: 0,
        budget_bytes: budget,
    }
}

fn load_texture(cache: &mut AssetCache, w: i64, h: i64) -> i64 {
    let handle = cache.textures.len() as i64;
    let bytes = w * h * 4;
    cache.textures.push(Texture {
        width: w,
        height: h,
        format: 1,
        mip_levels: 8,
        bytes,
        ref_count: 0,
        resident: true,
    });
    cache.resident_bytes += bytes;
    handle
}

fn load_material(cache: &mut AssetCache, shader: i64, tex: i64, rough: f64) -> i64 {
    let handle = cache.materials.len() as i64;
    cache.materials.push(Material {
        shader_id: shader,
        base_r: 1.0,
        base_g: 1.0,
        base_b: 1.0,
        roughness: rough,
        metallic: 0.0,
        texture: tex,
        ref_count: 0,
    });
    handle
}

fn load_mesh(cache: &mut AssetCache, verts: i64) -> i64 {
    let handle = cache.meshes.len() as i64;
    let bytes = verts * 32;
    cache.meshes.push(Mesh {
        vertex_count: verts,
        index_count: verts * 3,
        bounds_radius: 1.0,
        lod_levels: 4,
        ref_count: 0,
        resident: true,
    });
    cache.resident_bytes += bytes;
    handle
}

fn acquire(cache: &mut AssetCache, mesh_h: i64, mat_h: i64) {
    cache.meshes[mesh_h as usize].ref_count += 1;
    cache.materials[mat_h as usize].ref_count += 1;
    let tex = cache.materials[mat_h as usize].texture;
    cache.textures[tex as usize].ref_count += 1;
}

fn release(cache: &mut AssetCache, mesh_h: i64, mat_h: i64) {
    let m = &mut cache.meshes[mesh_h as usize];
    m.ref_count -= 1;
    if m.ref_count <= 0 {
        m.resident = false;
    }
    let mt = &mut cache.materials[mat_h as usize];
    mt.ref_count -= 1;
    let tex = mt.texture;
    let t = &mut cache.textures[tex as usize];
    t.ref_count -= 1;
    if t.ref_count <= 0 {
        t.resident = false;
    }
}

fn build_assets(cache: &mut AssetCache) {
    for _ in 0..8 {
        load_texture(cache, 512, 512);
    }
    for j in 0..12i64 {
        load_material(cache, j, j - (j / 8) * 8, 0.5);
    }
    for k in 0..20i64 {
        load_mesh(cache, 1000 + k * 100);
    }
}

fn populate(scene: &mut Scene, count: usize) {
    let mut f = 0.0;
    for i in 0..count as i64 {
        let mesh_h = i - (i / 20) * 20;
        let mat_h = i - (i / 12) * 12;
        scene.entities.push(Entity {
            mesh: mesh_h,
            material: mat_h,
            x: f,
            y: f,
            z: f,
            visible: true,
        });
        acquire(&mut scene.cache, mesh_h, mat_h);
        f += 1.0;
    }
}

fn render_batched(scene: &mut Scene) -> i64 {
    let mat_count = scene.cache.materials.len() as i64;
    let mut submitted = 0i64;
    let mut batches = 0i64;

    for m in 0..mat_count {
        let mut batch_size = 0i64;
        for e in &scene.entities {
            if e.visible && e.material == m {
                if scene.cache.meshes[e.mesh as usize].resident {
                    submitted += 1;
                    batch_size += 1;
                }
            }
        }
        if batch_size > 0 {
            batches += 1;
        }
    }

    scene.draw_calls = submitted;
    scene.batches = batches;
    submitted
}

fn evict_unused(cache: &mut AssetCache) -> i64 {
    let mut evicted = 0;
    for t in cache.textures.iter_mut() {
        if t.ref_count <= 0 && t.resident {
            t.resident = false;
            cache.resident_bytes -= t.bytes;
            evicted += 1;
        }
    }
    evicted
}

fn main() {
    let mut cache = make_cache(64 * 1024 * 1024);
    build_assets(&mut cache);

    let mut scene = Scene {
        entities: Vec::new(),
        cache,
        draw_calls: 0,
        batches: 0,
    };
    populate(&mut scene, ENTITIES);

    let mut frames = harness::Frames::new(FRAMES);
    let mut total: i64 = 0;

    for frame in 0..FRAMES {
        let t0 = harness::now_ns();
        let submitted = render_batched(&mut scene);
        let t1 = harness::now_ns();
        total += submitted;
        frames.set(frame, t1 - t0);
    }

    for i in 0..500 {
        let (mesh, material) = (scene.entities[i].mesh, scene.entities[i].material);
        release(&mut scene.cache, mesh, material);
        scene.entities[i].visible = false;
    }
    let evicted = evict_unused(&mut scene.cache);

    harness::report(
        &[
            ("entities", scene.entities.len() as i64),
            ("submitted", total),
            ("batches", scene.batches),
            ("evicted", evicted),
        ],
        &frames,
    );
}

// G5 asset cache -- Swift, idiomatic.
//
// Entities hold handles into the cache's arrays. The cache and the scene are
// `final class` (they are owned, mutated aggregates); assets and entities are
// structs stored inline.
//
// Worth stating because G5 was written to force shared ownership: it does not
// force any in Swift either. A handle is an index, so nothing here needs a
// second strong reference and ARC has nothing to count -- the same reason the
// program produces zero T3 sites in Prismio.

let FRAMES = 4000
let ENTITIES = 2000

struct Mesh {
    var vertexCount: Int
    var indexCount: Int
    var boundsRadius: Double
    var lodLevels: Int
    var refCount: Int
    var resident: Bool
}

struct Material {
    var shaderId: Int
    var baseR: Double
    var baseG: Double
    var baseB: Double
    var roughness: Double
    var metallic: Double
    var texture: Int
    var refCount: Int
}

struct Texture {
    var width: Int
    var height: Int
    var format: Int
    var mipLevels: Int
    var bytes: Int
    var refCount: Int
    var resident: Bool
}

struct Entity {
    var mesh: Int
    var material: Int
    var x: Double
    var y: Double
    var z: Double
    var visible: Bool
}

final class AssetCache {
    var meshes: [Mesh] = []
    var materials: [Material] = []
    var textures: [Texture] = []
    var residentBytes = 0
    var budgetBytes: Int

    init(budget: Int) { budgetBytes = budget }
}

final class Scene {
    var entities: [Entity] = []
    var cache: AssetCache
    var drawCalls = 0
    var batches = 0

    init(cache: AssetCache) { self.cache = cache }
}

@discardableResult
func loadTexture(_ cache: AssetCache, _ w: Int, _ h: Int) -> Int {
    let handle = cache.textures.count
    let bytes = w * h * 4
    cache.textures.append(Texture(width: w, height: h, format: 1,
                                  mipLevels: 8, bytes: bytes,
                                  refCount: 0, resident: true))
    cache.residentBytes += bytes
    return handle
}

@discardableResult
func loadMaterial(_ cache: AssetCache, _ shader: Int, _ tex: Int, _ rough: Double) -> Int {
    let handle = cache.materials.count
    cache.materials.append(Material(shaderId: shader,
                                    baseR: 1.0, baseG: 1.0, baseB: 1.0,
                                    roughness: rough, metallic: 0.0,
                                    texture: tex, refCount: 0))
    return handle
}

@discardableResult
func loadMesh(_ cache: AssetCache, _ verts: Int) -> Int {
    let handle = cache.meshes.count
    let bytes = verts * 32
    cache.meshes.append(Mesh(vertexCount: verts, indexCount: verts * 3,
                             boundsRadius: 1.0, lodLevels: 4,
                             refCount: 0, resident: true))
    cache.residentBytes += bytes
    return handle
}

func acquire(_ cache: AssetCache, _ meshH: Int, _ matH: Int) {
    cache.meshes[meshH].refCount += 1
    cache.materials[matH].refCount += 1
    let tex = cache.materials[matH].texture
    cache.textures[tex].refCount += 1
}

func release(_ cache: AssetCache, _ meshH: Int, _ matH: Int) {
    cache.meshes[meshH].refCount -= 1
    if cache.meshes[meshH].refCount <= 0 {
        cache.meshes[meshH].resident = false
    }
    cache.materials[matH].refCount -= 1
    let tex = cache.materials[matH].texture
    cache.textures[tex].refCount -= 1
    if cache.textures[tex].refCount <= 0 {
        cache.textures[tex].resident = false
    }
}

func buildAssets(_ cache: AssetCache) {
    for _ in 0..<8 { loadTexture(cache, 512, 512) }
    for j in 0..<12 { loadMaterial(cache, j, j - (j / 8) * 8, 0.5) }
    for k in 0..<20 { loadMesh(cache, 1000 + k * 100) }
}

func populate(_ scene: Scene, _ count: Int) {
    var f = 0.0
    for i in 0..<count {
        let meshH = i - (i / 20) * 20
        let matH = i - (i / 12) * 12
        scene.entities.append(Entity(mesh: meshH, material: matH,
                                     x: f, y: f, z: f, visible: true))
        acquire(scene.cache, meshH, matH)
        f += 1.0
    }
}

func renderBatched(_ scene: Scene) -> Int {
    let matCount = scene.cache.materials.count
    var submitted = 0
    var batches = 0

    for m in 0..<matCount {
        var batchSize = 0
        for e in scene.entities where e.visible && e.material == m {
            if scene.cache.meshes[e.mesh].resident {
                submitted += 1
                batchSize += 1
            }
        }
        if batchSize > 0 { batches += 1 }
    }

    scene.drawCalls = submitted
    scene.batches = batches
    return submitted
}

func evictUnused(_ cache: AssetCache) -> Int {
    var evicted = 0
    for i in 0..<cache.textures.count {
        if cache.textures[i].refCount <= 0 && cache.textures[i].resident {
            cache.textures[i].resident = false
            cache.residentBytes -= cache.textures[i].bytes
            evicted += 1
        }
    }
    return evicted
}

@main
struct G5 {
    static func main() {
        let cache = AssetCache(budget: 64 * 1024 * 1024)
        buildAssets(cache)

        let scene = Scene(cache: cache)
        populate(scene, ENTITIES)

        var frames = Frames(FRAMES)
        var total = 0

        for frame in 0..<FRAMES {
            let t0 = nowNs()
            let submitted = renderBatched(scene)
            let t1 = nowNs()
            total += submitted
            frames.set(frame, t1 - t0)
        }

        for i in 0..<500 {
            release(scene.cache, scene.entities[i].mesh, scene.entities[i].material)
            scene.entities[i].visible = false
        }
        let evicted = evictUnused(scene.cache)

        report([("entities", scene.entities.count),
                ("submitted", total),
                ("batches", scene.batches),
                ("evicted", evicted)], frames)
    }
}

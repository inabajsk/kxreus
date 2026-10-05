// RobotScene.swift : RobotModel から SceneKit のノードの木を作り, 関節角を当てはめる
//   リンクの変換 = rest (親から見た関節角 0 の位置姿勢) · R(axis, 角度)  (直動関節は · T(axis · mm/1000))
import SceneKit
import simd

final class RobotScene {
  let model: RobotModel
  let scene = SCNScene()
  let base = SCNNode()          // EusLisp の座標 (z が上) → SceneKit (y が上)
  var nodes = [SCNNode]()
  private(set) var angles: [Float]

  init(model: RobotModel) {
    self.model = model
    angles = [Float](repeating: 0, count: model.joints.count)
    base.eulerAngles.x = -.pi / 2
    scene.rootNode.addChildNode(base)
    for l in model.links {
      let n = SCNNode()
      n.name = l.name
      n.simdTransform = l.rest
      for m in l.meshes { n.addChildNode(SCNNode(geometry: RobotScene.geometry(m))) }
      nodes.append(n)
      (l.parent >= 0 ? nodes[l.parent] : base).addChildNode(n)
    }
    addFloorAndLights()
  }

  /// 三角形ごとに頂点を分けて, 面ごとの法線で陰影をつける (CAD のような角ばった見た目)
  static func geometry(_ m: RobotMesh) -> SCNGeometry {
    let v = m.vertices
    var pos = [SCNVector3](), nor = [SCNVector3]()
    pos.reserveCapacity(m.indices.count); nor.reserveCapacity(m.indices.count)
    var i = 0
    while i + 2 < m.indices.count {
      let p = (0..<3).map { k -> SIMD3<Float> in let j = Int(m.indices[i + k]) * 3; return SIMD3(v[j], v[j + 1], v[j + 2]) }
      let n = simd_normalize(simd_cross(p[1] - p[0], p[2] - p[0]))
      let nn = n.x.isFinite ? n : SIMD3<Float>(0, 0, 1)
      for q in p { pos.append(SCNVector3(q)); nor.append(SCNVector3(nn)) }
      i += 3
    }
    let idx = (0..<Int32(pos.count)).map { $0 }
    let g = SCNGeometry(sources: [SCNGeometrySource(vertices: pos), SCNGeometrySource(normals: nor)],
                        elements: [SCNGeometryElement(indices: idx, primitiveType: .triangles)])
    let mat = SCNMaterial()
    let c = m.color + [1, 1, 1, 1].dropFirst(m.color.count)
    mat.diffuse.contents = UIColor(red: CGFloat(c[0]), green: CGFloat(c[1]), blue: CGFloat(c[2]), alpha: CGFloat(c[3]))
    mat.lightingModel = .physicallyBased
    mat.metalness.contents = 0.1
    mat.roughness.contents = 0.6
    mat.isDoubleSided = true
    g.materials = [mat]
    return g
  }

  func addFloorAndLights() {
    let floor = SCNFloor()
    floor.reflectivity = 0.05
    let fm = SCNMaterial()
    fm.diffuse.contents = UIColor(white: 0.92, alpha: 1)
    floor.materials = [fm]
    let fn = SCNNode(geometry: floor)
    scene.rootNode.addChildNode(fn)
    let sun = SCNNode()
    sun.light = SCNLight()
    sun.light!.type = .directional
    sun.light!.castsShadow = true
    sun.light!.intensity = 900
    sun.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 4, 0)
    scene.rootNode.addChildNode(sun)
    let amb = SCNNode()
    amb.light = SCNLight()
    amb.light!.type = .ambient
    amb.light!.intensity = 350
    scene.rootNode.addChildNode(amb)
  }

  func setAngles(_ a: [Float]) {
    for (k, j) in model.joints.enumerated() where k < a.count {
      angles[k] = a[k]
      let rest = model.links[j.link].rest
      let ax = simd_normalize(SIMD3(j.axis[0], j.axis[1], j.axis[2]))
      let m: simd_float4x4
      if j.type == "linear" {
        var t = matrix_identity_float4x4
        t.columns.3 = SIMD4(ax * a[k] / 1000, 1)
        m = t
      } else {
        m = simd_float4x4(simd_quatf(angle: a[k] * .pi / 180, axis: ax))
      }
      nodes[j.link].simdTransform = rest * m
    }
  }

  /// 動作の 1 コマ: 関節角と, あればルートの位置姿勢 [x y z r00..r22]
  func setFrame(_ motion: RobotMotion, _ i: Int) {
    setAngles(motion.frames[i])
    if let r = motion.root, i < r.count, r[i].count >= 12, let root = model.links.firstIndex(where: { $0.parent < 0 }) {
      let v = r[i]
      nodes[root].simdTransform = simd_float4x4(columns: (SIMD4(v[3], v[6], v[9], 0), SIMD4(v[4], v[7], v[10], 0), SIMD4(v[5], v[8], v[11], 0), SIMD4(v[0], v[1], v[2], 1)))
    }
  }

  /// 物理モード: リンクのワールドの位置姿勢 (z が上) をノードの木に当てはめる
  func setWorldPoses(_ w: [simd_float4x4]) {
    for (i, l) in model.links.enumerated() where i < w.count {
      nodes[i].simdTransform = l.parent >= 0 ? simd_inverse(w[l.parent]) * w[i] : w[i]
    }
  }

  /// ロボット全体が収まる大きさと中心 (カメラの位置決め用)
  func bounds() -> (center: SCNVector3, radius: Float) {
    let (mn, mx) = base.boundingBox
    let c = SCNVector3((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, (mn.z + mx.z) / 2)
    let w = base.convertPosition(c, to: scene.rootNode)
    let d = simd_distance(SIMD3<Float>(Float(mn.x), Float(mn.y), Float(mn.z)), SIMD3<Float>(Float(mx.x), Float(mx.y), Float(mx.z)))
    return (w, max(d / 2, 0.05))
  }
}

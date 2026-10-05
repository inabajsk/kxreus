// rendericon.swift : ロボットの JSON を Mac の SceneKit で描いて PNG にする (アプリのアイコン用)
//   swiftc -O rendericon.swift -o rendericon && ./rendericon ../../robots/kxrl2l2a6h2m.json icon.png reset-pose 1024
import AppKit
import SceneKit
import simd

struct Mesh: Codable { var color: [Float]; var vertices: [Float]; var indices: [Int32] }
struct Link: Codable { var name: String; var parent: Int; var pos: [Float]; var rot: [Float]; var meshes: [Mesh] }
struct Joint: Codable { var name: String; var link: Int; var type: String; var axis: [Float] }
struct Model: Codable { var links: [Link]; var joints: [Joint]; var poses: [String: [Float]]? }

func rest(_ l: Link) -> simd_float4x4 {
  let r = l.rot
  return simd_float4x4(columns: (SIMD4(r[0], r[3], r[6], 0), SIMD4(r[1], r[4], r[7], 0), SIMD4(r[2], r[5], r[8], 0), SIMD4(l.pos[0], l.pos[1], l.pos[2], 1)))
}

let a = CommandLine.arguments
let m = try! JSONDecoder().decode(Model.self, from: Data(contentsOf: URL(fileURLWithPath: a[1])))
let out = a[2], pose = a.count > 3 ? a[3] : "reset-pose", size = a.count > 4 ? Int(a[4])! : 1024

let scene = SCNScene()
let base = SCNNode(); base.eulerAngles.x = -.pi / 2
scene.rootNode.addChildNode(base)
var nodes = [SCNNode]()
for l in m.links {
  let n = SCNNode(); n.simdTransform = rest(l)
  for me in l.meshes {
    var pos = [SCNVector3](), nor = [SCNVector3](); var i = 0
    while i + 2 < me.indices.count {
      let p = (0..<3).map { k -> SIMD3<Float> in let j = Int(me.indices[i + k]) * 3; return SIMD3(me.vertices[j], me.vertices[j + 1], me.vertices[j + 2]) }
      var nn = simd_normalize(simd_cross(p[1] - p[0], p[2] - p[0])); if !nn.x.isFinite { nn = SIMD3(0, 0, 1) }
      for q in p { pos.append(SCNVector3(q)); nor.append(SCNVector3(nn)) }
      i += 3
    }
    let g = SCNGeometry(sources: [SCNGeometrySource(vertices: pos), SCNGeometrySource(normals: nor)],
                        elements: [SCNGeometryElement(indices: (0..<Int32(pos.count)).map { $0 }, primitiveType: .triangles)])
    let mat = SCNMaterial(); let c = me.color
    mat.diffuse.contents = NSColor(red: CGFloat(c[0]), green: CGFloat(c[1]), blue: CGFloat(c[2]), alpha: 1)
    mat.lightingModel = .physicallyBased; mat.metalness.contents = 0.15; mat.roughness.contents = 0.5; mat.isDoubleSided = true
    g.materials = [mat]
    n.addChildNode(SCNNode(geometry: g))
  }
  nodes.append(n); (l.parent >= 0 ? nodes[l.parent] : base).addChildNode(n)
}
if let ang = m.poses?[pose] {
  for (k, j) in m.joints.enumerated() where k < ang.count {
    let ax = simd_normalize(SIMD3(j.axis[0], j.axis[1], j.axis[2]))
    var t = matrix_identity_float4x4
    if j.type == "linear" { t.columns.3 = SIMD4(ax * ang[k] / 1000, 1) } else { t = simd_float4x4(simd_quatf(angle: ang[k] * .pi / 180, axis: ax)) }
    nodes[j.link].simdTransform = rest(m.links[j.link]) * t
  }
}
// 大きさと中心 (ワールド座標)
let (mn, mx) = base.boundingBox
let c0 = SCNVector3((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, (mn.z + mx.z) / 2)
let c = base.convertPosition(c0, to: nil)
let h = Float(max(mx.x - mn.x, mx.y - mn.y, mx.z - mn.z))
// 光
let key = SCNNode(); key.light = SCNLight(); key.light!.type = .directional; key.light!.intensity = 1100
key.eulerAngles = SCNVector3(-0.7, 0.6, 0); scene.rootNode.addChildNode(key)
let fill = SCNNode(); fill.light = SCNLight(); fill.light!.type = .directional; fill.light!.intensity = 400
fill.eulerAngles = SCNVector3(-0.2, -2.2, 0); scene.rootNode.addChildNode(fill)
let amb = SCNNode(); amb.light = SCNLight(); amb.light!.type = .ambient; amb.light!.intensity = 450; scene.rootNode.addChildNode(amb)
// カメラ: 斜め前から少し見上げる
let cam = SCNNode(); cam.camera = SCNCamera(); cam.camera!.fieldOfView = 30; cam.camera!.zNear = 0.001
let d = CGFloat(h) * 2.55
cam.position = SCNVector3(c.x + d * 0.55, c.y + d * 0.12, c.z + d * 0.83)
cam.look(at: c)
scene.rootNode.addChildNode(cam)
// 背景: 紺から青のグラデーション (アイコンは透明にできない)
let bg = NSImage(size: NSSize(width: 512, height: 512)); bg.lockFocus()
NSGradient(starting: NSColor(red: 0.20, green: 0.42, blue: 0.70, alpha: 1), ending: NSColor(red: 0.07, green: 0.13, blue: 0.27, alpha: 1))!.draw(in: NSRect(x: 0, y: 0, width: 512, height: 512), angle: -90)
bg.unlockFocus()
scene.background.contents = bg

let r = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
r.scene = scene; r.pointOfView = cam
let img = r.snapshot(atTime: 0, with: CGSize(width: size, height: size), antialiasingMode: .multisampling4X)
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote", out, "size", h)

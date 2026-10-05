// BVHData.swift : BVH（モーションキャプチャ）を eusview/bvh/convert_bvh.py で変換した .ebvh を読み, 関節のワールドの位置姿勢を求める
//   アプリの bvh/ (= eusview/bvh/cache/ をビルドのときにコピー) の index.json と <種類>/<名前>.ebvh
//   .ebvh = "EBVH" + uint32 ヘッダの長さ + ヘッダ (JSON) + コマのデータ (位置 int32 0.1 mm, 回転 int16 0.01 度)
//   関節のローカルの変換 = T(位置のチャンネル か OFFSET) · R(ch1) · R(ch2) · R(ch3) (BVH のチャンネルの順)
//   ワールド (EusLisp の座標, z が上, m) = base · (BVH の座標の変換, m)
//   Foundation と simd だけを使う (Mac のコマンドラインで照合のテストに使えるように)
import Foundation
import simd

struct BVHIndexFile: Codable, Hashable {
  var name: String
  var file: String
  var frames: Int
  var fps: Double
  var duration: Double
  var joints: Int
  var bytes: Int
}

struct BVHIndexKind: Codable, Hashable {
  var name: String
  var title: String
  var unit: String
  var height: Double
  var files: [BVHIndexFile]
  var bytes: Int
  var duration: Double
}

struct BVHIndex: Codable {
  var kinds: [BVHIndexKind]
  var bytes: Int
}

/// 再生する 1 本 (種類とファイル)
struct BVHEntry: Hashable {
  var kind: String
  var file: BVHIndexFile
}

/// アプリに入っている BVH (bvh/index.json). なければ nil
func bvhRoot() -> URL? { Bundle.main.url(forResource: "bvh", withExtension: nil) }

func loadBVHIndex(root: URL? = bvhRoot()) -> BVHIndex? {
  guard let root, let d = try? Data(contentsOf: root.appendingPathComponent("index.json")) else { return nil }
  return try? JSONDecoder().decode(BVHIndex.self, from: d)
}

struct BVHJoint: Codable {
  var name: String
  var parent: Int
  var offset: [Float]
  var channels: [String]
}

struct BVHEnd: Codable {
  var parent: Int
  var offset: [Float]
}

struct BVHCheck: Codable {
  var frame: Int
  var joints: [[Float]]
}

struct BVHHeader: Codable {
  var kind: String
  var name: String
  var source: String
  var fps: Double
  var frames: Int
  var sourceFps: Double
  var step: Int
  var unitMM: Double
  var up: String
  var posScale: Float
  var rotScale: Float
  var joints: [BVHJoint]
  var ends: [BVHEnd]
  var base: [Float]
  var bounds: [Float]
  var check: BVHCheck?
}

enum BVHError: Error, CustomStringConvertible {
  case format(String)
  var description: String { switch self { case .format(let s): return s } }
}

/// 1 本のモーション. frame(i) で関節ごとのワールドの変換 (z が上, m) を返す
final class BVHMotion {
  let header: BVHHeader
  private let data: Data
  private let dataStart: Int
  private let frameBytes: Int
  /// チャンネルごと: (関節, 種類 0..2 = X/Y/Z 位置, 3..5 = X/Y/Z 回転, データの中の位置)
  private let chans: [(joint: Int, kind: Int, offset: Int)]
  private let base: simd_float4x4
  var frames: Int { header.frames }
  var fps: Double { header.fps }
  var joints: [BVHJoint] { header.joints }

  init(url: URL) throws {
    let d = try Data(contentsOf: url)
    guard d.count >= 8, String(data: d.prefix(4), encoding: .ascii) == "EBVH" else { throw BVHError.format("EBVH の形式ではありません") }
    let n = Int(d.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 4, as: UInt32.self).littleEndian })
    guard d.count >= 8 + n else { throw BVHError.format("ヘッダが途中で切れています") }
    header = try JSONDecoder().decode(BVHHeader.self, from: d.subdata(in: 8..<(8 + n)))
    data = d
    dataStart = 8 + n
    var cs = [(joint: Int, kind: Int, offset: Int)]()
    var off = 0
    for (j, jt) in header.joints.enumerated() {
      for c in jt.channels {
        let axis = ["X": 0, "Y": 1, "Z": 2][String(c.prefix(1)).uppercased()] ?? 0
        let pos = c.hasSuffix("position")
        cs.append((j, (pos ? 0 : 3) + axis, off))
        off += pos ? 4 : 2
      }
    }
    chans = cs
    frameBytes = off
    guard d.count >= dataStart + frameBytes * header.frames else { throw BVHError.format("コマのデータが足りません") }
    let b = header.base   // [x y z r00..r22] (行優先)
    base = simd_float4x4(columns: (SIMD4(b[3], b[6], b[9], 0), SIMD4(b[4], b[7], b[10], 0), SIMD4(b[5], b[8], b[11], 0), SIMD4(b[0], b[1], b[2], 1)))
  }

  static func rot(_ axis: Int, _ deg: Float) -> simd_float3x3 {
    let r = deg * .pi / 180, c = cos(r), s = sin(r)
    switch axis {
    case 0: return simd_float3x3(rows: [SIMD3(1, 0, 0), SIMD3(0, c, -s), SIMD3(0, s, c)])
    case 1: return simd_float3x3(rows: [SIMD3(c, 0, s), SIMD3(0, 1, 0), SIMD3(-s, 0, c)])
    default: return simd_float3x3(rows: [SIMD3(c, -s, 0), SIMD3(s, c, 0), SIMD3(0, 0, 1)])
    }
  }

  /// i コマ目の関節のワールドの変換 (EusLisp の座標, z が上, m)
  func frame(_ i: Int) -> [simd_float4x4] { pose(i).world }

  /// i コマ目の関節のワールドの変換と, 関節ごとのローカルの回転 (BVH の軸, R(ch1) · R(ch2) · R(ch3))
  func pose(_ i: Int) -> (world: [simd_float4x4], local: [simd_float3x3]) {
    let i = max(0, min(frames - 1, i))
    let js = header.joints
    var pos = js.map { SIMD3<Float>($0.offset[0], $0.offset[1], $0.offset[2]) / 1000 }
    var rot = [simd_float3x3](repeating: matrix_identity_float3x3, count: js.count)
    let start = dataStart + frameBytes * i
    let ps = header.posScale / 1000, rs = header.rotScale
    data.withUnsafeBytes { raw in
      for c in chans {
        if c.kind < 3 {
          let v = Int32(littleEndian: raw.loadUnaligned(fromByteOffset: start + c.offset, as: Int32.self))
          pos[c.joint][c.kind] = Float(v) * ps
        } else {
          let v = Int16(littleEndian: raw.loadUnaligned(fromByteOffset: start + c.offset, as: Int16.self))
          rot[c.joint] = rot[c.joint] * BVHMotion.rot(c.kind - 3, Float(v) * rs)
        }
      }
    }
    return (world(pos, rot), rot)
  }

  /// 初期姿勢 (回転 0, 位置 = OFFSET) の関節のワールドの変換
  func restPose() -> [simd_float4x4] {
    world(header.joints.map { SIMD3<Float>($0.offset[0], $0.offset[1], $0.offset[2]) / 1000 },
          [simd_float3x3](repeating: matrix_identity_float3x3, count: header.joints.count))
  }

  /// BVH の軸 → 世界 (EusLisp の座標) の回転 (base の回転の部分)
  var baseRotation: simd_float3x3 { simd_float3x3(base.columns.0.xyz, base.columns.1.xyz, base.columns.2.xyz) }

  /// End Site のワールドの位置 (ends の順)
  func endPositions(_ w: [simd_float4x4]) -> [SIMD3<Float>] {
    header.ends.map { e in (w[e.parent] * SIMD4(e.offset[0] / 1000, e.offset[1] / 1000, e.offset[2] / 1000, 1)).xyz }
  }

  private func world(_ pos: [SIMD3<Float>], _ rot: [simd_float3x3]) -> [simd_float4x4] {
    var w = [simd_float4x4]()
    w.reserveCapacity(pos.count)
    for (j, jt) in header.joints.enumerated() {
      let r = rot[j]
      let m = simd_float4x4(columns: (SIMD4(r.columns.0, 0), SIMD4(r.columns.1, 0), SIMD4(r.columns.2, 0), SIMD4(pos[j], 1)))
      w.append(jt.parent >= 0 ? w[jt.parent] * m : base * m)
    }
    return w
  }

  /// 変換したときの値 (check) とのずれの最大 (mm). check がなければ nil
  func checkError() -> Float? {
    guard let c = header.check else { return nil }
    let w = frame(c.frame)
    var e: Float = 0
    for (j, p) in c.joints.enumerated() where j < w.count {
      let q = SIMD3(w[j].columns.3.x, w[j].columns.3.y, w[j].columns.3.z)
      e = max(e, simd_distance(q, SIMD3(p[0], p[1], p[2])) * 1000)
    }
    return e
  }
}

extension SIMD4 where Scalar == Float {
  var xyz: SIMD3<Float> { SIMD3(x, y, z) }
}

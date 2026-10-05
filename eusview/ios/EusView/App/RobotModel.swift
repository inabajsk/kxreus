// RobotModel.swift : eus2json.l が書き出すロボットの JSON (単位 m・度, EusLisp の座標: z が上)
import Foundation
import simd

struct RobotMesh: Codable {
  var color: [Float]
  var vertices: [Float]
  var indices: [Int32]
}

struct RobotLink: Codable {
  var name: String
  var parent: Int
  var pos: [Float]
  var rot: [Float]
  var meshes: [RobotMesh]
}

struct RobotJoint: Codable {
  var name: String
  var link: Int
  var type: String
  var axis: [Float]
  var min: Float?
  var max: Float?
}

struct RobotMotion: Codable {
  var name: String
  var fps: Float
  var frames: [[Float]]
  var root: [[Float]]?
}

struct RobotModel: Codable {
  var name: String
  var source: String?
  var links: [RobotLink]
  var joints: [RobotJoint]
  var poses: [String: [Float]]?
  var motions: [RobotMotion]?
  var physics: Physics?
}

extension RobotLink {
  /// 親リンクから見た関節角 0 のときの変換
  var rest: simd_float4x4 {
    let r = rot
    return simd_float4x4(columns: (SIMD4(r[0], r[3], r[6], 0), SIMD4(r[1], r[4], r[7], 0), SIMD4(r[2], r[5], r[8], 0), SIMD4(pos[0], pos[1], pos[2], 1)))
  }
}

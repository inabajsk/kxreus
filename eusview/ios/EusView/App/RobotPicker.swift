// RobotPicker.swift : ロボットを画像と名前で選ぶ (Android・デスクトップ版の RobotPicker.kt と同じ)
//   グループ (KXR / KHR / JSK) → 身体の形の分類 (robots/catalog.json, make_catalog.py) → 画像 (robots/<グループ>/<名前>.png) の並び
//   分類のボタンで絞る (「すべて」は分類ごとに見出しをつけて並べる). 名前で探すと分類をまたいで探す
import SwiftUI
import UIKit

struct RobotCategory: Decodable, Hashable { var id: String; var title: String; var note: String; var robots: [String] }

/// robots/catalog.json: グループ → 分類の並び, 名前 → 関節の数
struct RobotCatalog: Decodable {
  var groups: [String: [RobotCategory]]
  var joints: [String: Int]

  static let shared: RobotCatalog = {
    guard let u = Bundle.main.url(forResource: "catalog", withExtension: "json", subdirectory: "robots"),
          let d = try? Data(contentsOf: u), let c = try? JSONDecoder().decode(RobotCatalog.self, from: d)
    else { return RobotCatalog(groups: [:], joints: [:]) }
    return c
  }()

  /// グループのロボットを分類ごとに. 分類にないもの (受け取って保存した JSON など) は「その他」
  func sections(_ group: String, _ files: [RobotFile]) -> [(RobotCategory, [RobotFile])] {
    let byName = Dictionary(files.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
    var used = Set<URL>()
    var out = [(RobotCategory, [RobotFile])]()
    for c in groups[group] ?? [] {
      let rs = c.robots.compactMap { byName[$0] }.filter { used.insert($0.url).inserted }
      if !rs.isEmpty { out.append((c, rs)) }
    }
    let rest = files.filter { !used.contains($0.url) }
    if !rest.isEmpty { out.append((RobotCategory(id: "rest", title: out.isEmpty ? group.uppercased() : "その他", note: "", robots: rest.map(\.name)), rest)) }
    return out
  }
}

/// 一覧の画像 (JSON の隣の <名前>.png, desktop の make thumbs で作る). 読んだものは覚えておく
final class Thumbnails {
  static let cache = NSCache<NSURL, UIImage>()
  static func image(for json: URL) -> UIImage? {
    let u = json.deletingPathExtension().appendingPathExtension("png") as NSURL
    if let i = cache.object(forKey: u) { return i }
    guard let i = UIImage(contentsOfFile: (u as URL).path) else { return nil }
    cache.setObject(i, forKey: u)
    return i
  }
}

/// グループ・分類・名前で探す・画像の並び. 選んだら RobotLoaderView へ
struct RobotPickerView: View {
  let files: [RobotFile]
  @Binding var group: String
  let search: String
  @AppStorage("robotCategory.kxr") var catKXR = "all"
  @AppStorage("robotCategory.khr") var catKHR = "all"
  @AppStorage("robotCategory.jsk") var catJSK = "all"
  let catalog = RobotCatalog.shared

  var cat: Binding<String> { group == "khr" ? $catKHR : group == "jsk" ? $catJSK : $catKXR }

  var body: some View {
    let inGroup = files.filter { $0.group == group }
    let sections = catalog.sections(group, inGroup)
    let q = search.trimmingCharacters(in: .whitespaces)
    let current = sections.contains { $0.0.id == cat.wrappedValue } ? cat.wrappedValue : "all"
    let shown: [(RobotCategory, [RobotFile])] =
      !q.isEmpty ? sections.map { ($0.0, $0.1.filter { $0.name.localizedCaseInsensitiveContains(q) }) }.filter { !$0.1.isEmpty }
      : current == "all" ? sections : sections.filter { $0.0.id == current }
    VStack(spacing: 0) {
      if sections.count > 1 {
        // 選んだ分類のボタンが見えるように横に送る
        ScrollViewReader { proxy in
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
              chip("すべて（\(inGroup.count)）", on: current == "all" && q.isEmpty) { cat.wrappedValue = "all" }.id("all")
              ForEach(sections, id: \.0.id) { s in
                chip("\(s.0.title)（\(s.1.count)）", on: current == s.0.id && q.isEmpty) { cat.wrappedValue = s.0.id }.id(s.0.id)
              }
            }.padding(.horizontal).padding(.bottom, 6)
          }
          .onAppear { proxy.scrollTo(current, anchor: .center) }
          .onChange(of: group) { proxy.scrollTo(cat.wrappedValue, anchor: .center) }
        }
      }
      ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104, maximum: 160), spacing: 8)], alignment: .leading, spacing: 8, pinnedViews: []) {
          ForEach(shown, id: \.0.id) { s in
            Section {
              ForEach(s.1, id: \.self) { f in
                NavigationLink { RobotLoaderView(url: f.url) } label: { RobotCell(file: f, joints: catalog.joints[f.name]) }
                  .buttonStyle(.plain)
              }
            } header: {
              if shown.count > 1 || !s.0.note.isEmpty {
                VStack(alignment: .leading, spacing: 1) {
                  Text(shown.count > 1 ? "\(s.0.title)（\(s.1.count)）" : s.0.title).font(.subheadline.bold())
                  if !s.0.note.isEmpty { Text(s.0.note).font(.caption2).foregroundStyle(.secondary) }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
              }
            }
          }
        }.padding(.horizontal)
      }
      .overlay {
        if shown.isEmpty { Text(q.isEmpty ? "このグループのロボットはありません" : "「\(q)」に合うロボットはありません").foregroundStyle(.secondary) }
      }
    }
  }

  func chip(_ t: String, on: Bool, _ f: @escaping () -> Void) -> some View {
    Button(action: f) {
      Text(t).font(.caption).padding(.horizontal, 10).padding(.vertical, 6)
        .background(on ? Color.accentColor.opacity(0.18) : Color.clear, in: Capsule())
        .overlay(Capsule().stroke(on ? Color.accentColor : Color.secondary.opacity(0.4)))
        .foregroundStyle(on ? Color.accentColor : Color.primary)
    }.buttonStyle(.plain)
  }
}

struct RobotCell: View {
  let file: RobotFile
  let joints: Int?
  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      ZStack {
        Color(uiColor: .systemBackground)
        if let i = Thumbnails.image(for: file.url) { Image(uiImage: i).resizable().scaledToFill() }
        else { Text(file.name.prefix(3).uppercased()).font(.title3).foregroundStyle(.secondary) }
      }
      .aspectRatio(1, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 7))
      Text(file.name).font(.caption).lineLimit(1).truncationMode(.tail).padding(.horizontal, 2)
      if let j = joints { Text("関節 \(j)").font(.caption2).foregroundStyle(.secondary).padding(.horizontal, 2) }
    }
    .padding(4)
    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    .contentShape(RoundedRectangle(cornerRadius: 10))
  }
}

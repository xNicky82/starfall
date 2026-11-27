import SwiftUI
import UIKit
import Observation

struct BondRecord: Codable, Identifiable, Hashable {
    enum Choice: String, Codable { case bonded, released }
    var id = UUID()
    var soulID: UUID
    var choice: Choice
    var meeting: Meeting
    var score: Double
    var date = Date()
}

@Observable
final class Store {
    var me: Soul? { didSet { save() } }
    var bonds: [BondRecord] = [] { didSet { save() } }
    let others: [Soul] = SoulFactory.field()
    /// Your profile photo after crop and edits.
    var photo: UIImage?
    var photoEdit = PhotoEdit() { didSet { save() } }

    private struct Saved: Codable { var me: Soul?; var bonds: [BondRecord]; var photoEdit: PhotoEdit? }
    private static let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private let url = Store.dir.appendingPathComponent("starfall.json")
    private static func file(_ name: String) -> URL { dir.appendingPathComponent(name) }

    init() {
        if let data = try? Data(contentsOf: url), let s = try? JSONDecoder().decode(Saved.self, from: data) {
            me = s.me; bonds = s.bonds
            if let e = s.photoEdit { photoEdit = e }
        }
        photo = Store.image("photo.jpg")
    }

    private func save() {
        let s = Saved(me: me, bonds: bonds, photoEdit: photoEdit)
        if let data = try? JSONEncoder().encode(s) { try? data.write(to: url, options: .atomic) }
    }

    // MARK: Photo: original → square crop → edits. Each step is kept so you can redo the next one.

    private static func image(_ name: String) -> UIImage? {
        guard let d = try? Data(contentsOf: file(name)) else { return nil }
        return UIImage(data: d)
    }
    private static func write(_ img: UIImage?, _ name: String) {
        if let img, let d = img.jpegData(compressionQuality: 0.9) { try? d.write(to: file(name), options: .atomic) }
        else { try? FileManager.default.removeItem(at: file(name)) }
    }
    var photoOriginal: UIImage? { Store.image("photo-original.jpg") }
    var photoCrop: UIImage? { Store.image("photo-crop.jpg") }

    func setPhoto(original: UIImage?, crop: UIImage, edit: PhotoEdit) {
        if let original { Store.write(original, "photo-original.jpg") }
        Store.write(crop, "photo-crop.jpg")
        let final = PhotoLab.apply(edit, to: crop)
        Store.write(final, "photo.jpg")
        photoEdit = edit
        photo = final
    }
    func removePhoto() {
        ["photo-original.jpg", "photo-crop.jpg", "photo.jpg"].forEach { Store.write(nil, $0) }
        photoEdit = PhotoEdit()
        photo = nil
    }

    func soul(_ id: UUID) -> Soul? { others.first { $0.id == id } }

    func record(_ soul: Soul, choice: BondRecord.Choice, resonance: Resonance) {
        bonds.removeAll { $0.soulID == soul.id }
        bonds.append(BondRecord(soulID: soul.id, choice: choice, meeting: resonance.meeting, score: resonance.score))
    }
    var bonded: [BondRecord] { bonds.filter { $0.choice == .bonded }.sorted { $0.date > $1.date } }

    func reset() { me = nil; bonds = []; removePhoto() }
}

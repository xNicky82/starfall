import SwiftUI
import PhotosUI

/// Name, photo, age, sex, location, education.
struct DetailsSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var pick: PhotosPickerItem?
    @State private var cropping: CropJob?
    @State private var editing: EditJob?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 14) {
                        avatar
                        HStack(spacing: 8) {
                            PhotosPicker(selection: $pick, matching: .images) {
                                pill(store.photo == nil ? "Choose photo" : "Replace")
                            }
                            if let original = store.photoOriginal {
                                Button { cropping = CropJob(image: original, isNew: false) } label: { pill("Crop") }
                            }
                            if let crop = store.photoCrop {
                                Button { editing = EditJob(base: crop) } label: { pill("Edit") }
                            }
                        }
                        .buttonStyle(.plain)
                        if store.photo != nil {
                            Button("Remove photo", role: .destructive) { store.removePhoto() }
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section("You") {
                    TextField("Name", text: bind(\.name, ""))
                    Picker("Age", selection: basics(\.age, nil as Int?)) {
                        Text("Not set").tag(nil as Int?)
                        ForEach(18...99, id: \.self) { Text("\($0)").tag(Optional($0)) }
                    }
                    Picker("Sex", selection: basics(\.sex, nil as String?)) {
                        Text("Not set").tag(nil as String?)
                        ForEach(Basics.sexes, id: \.self) { Text($0).tag(Optional($0)) }
                    }
                    TextField("Location", text: Binding(
                        get: { store.me?.basics?.location ?? "" },
                        set: { v in update { $0.location = v.isEmpty ? nil : v } }))
                        .textContentType(.addressCity)
                    Picker("Education", selection: basics(\.education, nil as String?)) {
                        Text("Not set").tag(nil as String?)
                        ForEach(Basics.educations, id: \.self) { Text($0).tag(Optional($0)) }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(OrbPalette.ground)
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onChange(of: pick) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                        cropping = CropJob(image: img, isNew: true)
                    }
                    pick = nil
                }
            }
            .fullScreenCover(item: $cropping) { job in
                PhotoCropView(image: job.image) { cropped in
                    // A new photo starts with fresh edits; re-cropping keeps the ones you made.
                    let edit = job.isNew ? PhotoEdit() : store.photoEdit
                    store.setPhoto(original: job.isNew ? job.image : nil, crop: cropped, edit: edit)
                    cropping = nil
                    if job.isNew { DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { editing = EditJob(base: cropped) } }
                } onCancel: { cropping = nil }
            }
            .fullScreenCover(item: $editing) { job in
                PhotoEditView(base: job.base, start: store.photoEdit) { edit in
                    store.setPhoto(original: nil, crop: job.base, edit: edit)
                    editing = nil
                } onCancel: { editing = nil }
            }
        }
        .tint(OrbPalette.ink)
    }

    private var avatar: some View {
        ZStack {
            Circle().fill(OrbPalette.ink)
            if let img = store.photo {
                Image(uiImage: img).resizable().scaledToFill().clipShape(Circle()).padding(4)
            } else {
                Image(systemName: "camera").font(.system(size: 26, weight: .medium)).foregroundStyle(OrbPalette.paper.opacity(0.7))
            }
        }
        .frame(width: 120, height: 120)
    }

    private func pill(_ t: String) -> some View {
        Text(t).font(.system(size: 14, weight: .semibold)).foregroundStyle(OrbPalette.ink)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(Color.white.opacity(0.7), in: Capsule())
    }

    private func update(_ f: (inout Basics) -> Void) {
        guard var me = store.me else { return }
        var b = me.basics ?? Basics()
        f(&b)
        me.basics = b
        store.me = me
    }
    private func bind(_ kp: WritableKeyPath<Soul, String>, _ fallback: String) -> Binding<String> {
        Binding(get: { store.me?[keyPath: kp] ?? fallback },
                set: { v in if var me = store.me { me[keyPath: kp] = v; store.me = me } })
    }
    private func basics<T>(_ kp: WritableKeyPath<Basics, T>, _ fallback: T) -> Binding<T> {
        Binding(get: { store.me?.basics?[keyPath: kp] ?? fallback },
                set: { v in update { $0[keyPath: kp] = v } })
    }
}

struct CropJob: Identifiable { let id = UUID(); let image: UIImage; let isNew: Bool }
struct EditJob: Identifiable { let id = UUID(); let base: UIImage }

// MARK: - Crop: drag and pinch inside a circle

struct PhotoCropView: View {
    let image: UIImage
    let onDone: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var zoom: CGFloat = 1
    @State private var lastZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { g in
            let side = min(g.size.width - 40, 380)
            let w = max(1, image.size.width), h = max(1, image.size.height)
            let base = max(side / w, side / h)
            let dw = w * base * zoom, dh = h * base * zoom
            VStack(spacing: 0) {
                HStack {
                    Button("Cancel", action: onCancel)
                    Spacer()
                    Text("Move and scale").font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Button("Done") { onDone(PhotoLab.crop(image, side: side, zoom: zoom, offset: offset)) }
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20).padding(.top, 12)
                Spacer()
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: dw, height: dh)
                        .offset(offset)
                    Rectangle()
                        .fill(Color.black.opacity(0.55))
                        .mask(ZStack { Rectangle(); Circle().blendMode(.destinationOut) }.compositingGroup())
                        .allowsHitTesting(false)
                    Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1).allowsHitTesting(false)
                }
                .frame(width: side, height: side)
                .clipped()
                .contentShape(Rectangle())
                .gesture(
                    SimultaneousGesture(
                        DragGesture()
                            .onChanged { v in
                                offset = clamp(CGSize(width: lastOffset.width + v.translation.width,
                                                      height: lastOffset.height + v.translation.height), dw: dw, dh: dh, side: side)
                            }
                            .onEnded { _ in lastOffset = offset },
                        MagnifyGesture()
                            .onChanged { v in
                                zoom = min(5, max(1, lastZoom * v.magnification))
                                offset = clamp(offset, dw: w * base * zoom, dh: h * base * zoom, side: side)
                            }
                            .onEnded { _ in lastZoom = zoom; lastOffset = offset }
                    )
                )
                Spacer()
                Text("Pinch to zoom, drag to frame your face.").font(.system(size: 14)).foregroundStyle(.white.opacity(0.6))
                    .padding(.bottom, 30)
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .background(Color.black.ignoresSafeArea())
    }

    private func clamp(_ o: CGSize, dw: CGFloat, dh: CGFloat, side: CGFloat) -> CGSize {
        let mx = max(0, (dw - side) / 2), my = max(0, (dh - side) / 2)
        return CGSize(width: min(mx, max(-mx, o.width)), height: min(my, max(-my, o.height)))
    }
}

// MARK: - Edit: looks and adjustments

struct PhotoEditView: View {
    let base: UIImage
    let onDone: (PhotoEdit) -> Void
    let onCancel: () -> Void

    @State private var edit: PhotoEdit
    @State private var preview: UIImage?
    @State private var small: UIImage
    @State private var thumbs: [PhotoEdit.Look: UIImage] = [:]

    init(base: UIImage, start: PhotoEdit, onDone: @escaping (PhotoEdit) -> Void, onCancel: @escaping () -> Void) {
        self.base = base; self.onDone = onDone; self.onCancel = onCancel
        _edit = State(initialValue: start)
        _small = State(initialValue: PhotoLab.downscaled(base, to: 640))
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Button("Cancel", action: onCancel)
                Spacer()
                Text("Edit").font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("Done") { onDone(edit) }.font(.system(size: 16, weight: .semibold))
            }
            .padding(.horizontal, 20).padding(.top, 12)

            Image(uiImage: preview ?? small)
                .resizable().scaledToFill()
                .frame(width: 240, height: 240)
                .clipShape(Circle())
                .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(PhotoEdit.Look.allCases) { look in
                        Button { edit.look = look } label: {
                            VStack(spacing: 6) {
                                Image(uiImage: thumbs[look] ?? small)
                                    .resizable().scaledToFill()
                                    .frame(width: 62, height: 62)
                                    .clipShape(Circle())
                                    .overlay(Circle().strokeBorder(OrbPalette.ink, lineWidth: edit.look == look ? 2.5 : 0).padding(-4))
                                Text(look.title).font(.system(size: 12, weight: edit.look == look ? .semibold : .regular))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 4)
            }

            VStack(spacing: 14) {
                adjust("Brightness", $edit.brightness, -0.3...0.3)
                adjust("Contrast", $edit.contrast, 0.6...1.6)
                adjust("Saturation", $edit.saturation, 0...2)
                adjust("Warmth", $edit.warmth, -1...1)
            }
            .padding(.horizontal, 24)

            Button("Reset") { edit = PhotoEdit() }.font(.system(size: 14, weight: .semibold))
            Spacer(minLength: 0)
        }
        .foregroundStyle(OrbPalette.ink)
        .tint(OrbPalette.ink)
        .background(OrbPalette.ground.ignoresSafeArea())
        .onAppear {
            render()
            let t = PhotoLab.downscaled(base, to: 160)
            var out: [PhotoEdit.Look: UIImage] = [:]
            for l in PhotoEdit.Look.allCases { var e = PhotoEdit(); e.look = l; out[l] = PhotoLab.apply(e, to: t) }
            thumbs = out
        }
        .onChange(of: edit) { _, _ in render() }
    }

    private func render() { preview = PhotoLab.apply(edit, to: small) }

    private func adjust(_ title: String, _ v: Binding<Double>, _ range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 14, weight: .medium))
            Slider(value: v, in: range)
        }
    }
}

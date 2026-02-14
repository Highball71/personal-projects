import SwiftUI
import SwiftData
import PhotosUI

struct NoteEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let patient: Patient
    let entryType: EntryType
    
    @State private var noteText = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoImages: [UIImage] = []
    @State private var showCamera = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(entryType == .woundCare ? "Wound Care Notes" :
                        entryType == .therapy ? "Therapy Notes" : "Notes") {
                    TextField(placeholder, text: $noteText, axis: .vertical)
                        .lineLimit(5...15)
                }
                
                if entryType == .woundCare {
                    Section("Quick Descriptions") {
                        let descriptions = ["Clean and dry", "Redness noted", "Swelling present", "Drainage observed", "Healing well", "Dressing changed", "No signs of infection", "Wound measured", "Skin tear", "Bruising noted"]
                        FlowLayout(spacing: 8) {
                            ForEach(descriptions, id: \.self) { desc in
                                Button(desc) {
                                    if noteText.isEmpty {
                                        noteText = desc
                                    } else {
                                        noteText += ". \(desc)"
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
                
                Section("Photos") {
                    // Display attached photos
                    if !photoImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(photoImages.indices, id: \.self) { index in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: photoImages[index])
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        
                                        Button {
                                            photoImages.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.white)
                                                .background(Circle().fill(.black.opacity(0.5)))
                                        }
                                        .offset(x: 4, y: -4)
                                    }
                                }
                            }
                        }
                    }
                    
                    HStack(spacing: 16) {
                        PhotosPicker(selection: $selectedPhotos,
                                    maxSelectionCount: 5,
                                    matching: .images) {
                            Label("Photo Library", systemImage: "photo.on.rectangle")
                        }
                        
                        Button {
                            showCamera = true
                        } label: {
                            Label("Camera", systemImage: "camera")
                        }
                    }
                }
            }
            .navigationTitle(entryType.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .bold()
                        .disabled(noteText.isEmpty && photoImages.isEmpty)
                }
            }
            .onChange(of: selectedPhotos) { _, newItems in
                Task {
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            photoImages.append(image)
                        }
                    }
                    selectedPhotos = []
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(image: Binding(
                    get: { nil },
                    set: { if let img = $0 { photoImages.append(img) } }
                ))
            }
        }
    }
    
    private var placeholder: String {
        switch entryType {
        case .woundCare: return "Describe wound location, size, appearance, treatment applied..."
        case .therapy: return "Describe therapy session, exercises performed, patient tolerance, progress..."
        default: return "Enter your care notes..."
        }
    }
    
    private func save() {
        let entry = CareEntry(patient: patient, entryType: entryType, noteText: noteText)
        
        // Convert photos to JPEG data
        entry.photoData = photoImages.compactMap { image in
            image.jpegData(compressionQuality: 0.7)
        }
        
        modelContext.insert(entry)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Camera View
struct CameraView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    @Binding var image: UIImage?
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

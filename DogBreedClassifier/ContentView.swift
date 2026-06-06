import SwiftUI
import Photos

struct ContentView: View {
    @StateObject private var viewModel = ImageClassifierViewModel()

    @State private var selectedPhotos: [UIImage] = []
    @State private var pickedFromLibrary: [UIImage] = []
    @State private var cameraImage: UIImage?

    @State private var showingPhotoLibraryDialog: Bool = false
    @State private var showingLimitedPicker: Bool = false
    @State private var showingFullLibraryPicker: Bool = false
    @State private var showingCamera: Bool = false
    @State private var showingDeniedAlert: Bool = false
    @State private var showingResults: Bool = false
    @State private var showingSelectedPhotos: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "pawprint.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    Text("Identify a Dog Breed")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Take a photo, or curate a private set of photos to classify.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button(action: {
                        showingCamera = true
                    }) {
                        Label("Camera", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }

                    Button(action: {
                        showingPhotoLibraryDialog = true
                    }) {
                        Label("Photo Library", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }

                    if !selectedPhotos.isEmpty {
                        Button(action: {
                            showingSelectedPhotos = true
                        }) {
                            Label("My Selected Photos (\(selectedPhotos.count))",
                                  systemImage: "square.stack.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.indigo)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Dog Breed Classifier")
            .alert(
                "Choose Photo Library Access",
                isPresented: $showingPhotoLibraryDialog
            ) {
                Button("Select Specific Photos") {
                    showingLimitedPicker = true
                }
                Button("Allow Full Library Access") {
                    requestFullLibraryAccess()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Pick a private set of photos to keep inside the app, or grant full library access to browse your entire library.")
            }
            .sheet(isPresented: $showingLimitedPicker) {
                PhotoLibraryPicker(images: $pickedFromLibrary)
            }
            .sheet(isPresented: $showingFullLibraryPicker) {
                CameraPicker(image: $cameraImage, sourceType: .photoLibrary)
            }
            .sheet(isPresented: $showingCamera) {
                CameraPicker(image: $cameraImage, sourceType: .camera)
            }
            .alert("Photo Library Access Denied", isPresented: $showingDeniedAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enable photo library access in Settings to browse your full library.")
            }
            .onChange(of: pickedFromLibrary) { _, newImages in
                guard !newImages.isEmpty else { return }
                selectedPhotos.append(contentsOf: newImages)
                pickedFromLibrary = []
                showingSelectedPhotos = true
            }
            .onChange(of: cameraImage) { _, newImage in
                guard let image = newImage else { return }
                viewModel.classify(images: [image])
                cameraImage = nil
                showingResults = true
            }
            .navigationDestination(isPresented: $showingResults) {
                ResultsView()
                    .environmentObject(viewModel)
            }
            .navigationDestination(isPresented: $showingSelectedPhotos) {
                SelectedPhotosView(
                    photos: $selectedPhotos,
                    onPick: { image in
                        viewModel.classify(images: [image])
                        showingResults = true
                    },
                    onAddMore: {
                        showingLimitedPicker = true
                    }
                )
            }
        }
    }

    private func requestFullLibraryAccess() {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch current {
        case .authorized:
            showingFullLibraryPicker = true
        case .limited:
            showingLimitedPicker = true
        case .denied, .restricted:
            showingDeniedAlert = true
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                Task { @MainActor in
                    switch status {
                    case .authorized:
                        showingFullLibraryPicker = true
                    case .limited:
                        showingLimitedPicker = true
                    default:
                        showingDeniedAlert = true
                    }
                }
            }
        @unknown default:
            showingDeniedAlert = true
        }
    }
}

struct SelectedPhotosView: View {
    @Binding var photos: [UIImage]
    let onPick: (UIImage) -> Void
    let onAddMore: () -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 110), spacing: 8)
    ]

    var body: some View {
        Group {
            if photos.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No photos yet")
                        .font(.headline)
                    Text("Add photos from your library to build a private set you can classify.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button(action: onAddMore) {
                        Label("Add Photos", systemImage: "plus")
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.indigo)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    Text("Tap a photo to classify it.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(Array(photos.enumerated()), id: \.offset) { index, image in
                            Button {
                                onPick(image)
                            } label: {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 110, height: 110)
                                    .clipped()
                                    .cornerRadius(8)
                                    .overlay(alignment: .topTrailing) {
                                        Button {
                                            photos.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.white, .black.opacity(0.6))
                                                .font(.title3)
                                                .padding(4)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
        }
        .navigationTitle("Selected Photos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onAddMore) {
                    Image(systemName: "plus")
                }
            }
            if !photos.isEmpty {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear", role: .destructive) {
                        photos.removeAll()
                    }
                }
            }
        }
    }
}

struct ResultsView: View {
    @EnvironmentObject private var viewModel: ImageClassifierViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.results) { result in
                    ResultCard(result: result)
                }
            }
            .padding()
        }
        .navigationTitle(viewModel.results.count == 1 ? "Result" : "Results")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ResultCard: View {
    let result: ClassifiedImage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(uiImage: result.image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 320)
                .cornerRadius(10)

            if result.isClassifying {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Identifying breed…")
                        .foregroundColor(.secondary)
                }
            } else if !result.errorMessage.isEmpty {
                Text(result.errorMessage)
                    .foregroundColor(.red)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This is a")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(result.breedName)
                        .font(.title3)
                        .fontWeight(.semibold)
                    if !result.confidence.isEmpty {
                        Text(result.confidence)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.08))
        .cornerRadius(12)
    }
}

#Preview {
    ContentView()
}

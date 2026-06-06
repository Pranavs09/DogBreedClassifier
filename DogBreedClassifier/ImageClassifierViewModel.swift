import SwiftUI
import Combine
import Vision
import CoreML

struct ClassifiedImage: Identifiable {
    let id = UUID()
    let image: UIImage
    var breedName: String = ""
    var confidence: String = ""
    var errorMessage: String = ""
    var isClassifying: Bool = true
}

@MainActor
class ImageClassifierViewModel: ObservableObject {
    @Published var results: [ClassifiedImage] = []

    private let classificationRequest: VNCoreMLRequest

    init() {
        do {
            let config = MLModelConfiguration()
            #if targetEnvironment(simulator)
            config.computeUnits = .cpuOnly
            #else
            config.computeUnits = .all
            #endif
            let model = try VNCoreMLModel(for: DogBreedClassifier(configuration: config).model)
            let request = VNCoreMLRequest(model: model)
            request.imageCropAndScaleOption = .centerCrop
            self.classificationRequest = request
        } catch {
            fatalError("Failed to load Core ML model: \(error)")
        }
    }

    func classify(images: [UIImage]) {
        results = images.map { ClassifiedImage(image: $0) }
        for index in results.indices {
            runClassification(at: index)
        }
    }

    func clear() {
        results = []
    }

    private func runClassification(at index: Int) {
        let id = results[index].id
        let image = results[index].image

        guard let ciImage = CIImage(image: image) else {
            updateResult(id: id) { result in
                result.isClassifying = false
                result.errorMessage = "Unable to process image."
            }
            return
        }

        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let request = classificationRequest

        Task.detached(priority: .userInitiated) { [weak self] in
            let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
            var observations: [VNClassificationObservation] = []
            var caughtError: Error?
            do {
                try handler.perform([request])
                observations = (request.results as? [VNClassificationObservation]) ?? []
            } catch {
                caughtError = error
            }

            await self?.finishClassification(id: id, observations: observations, error: caughtError)
        }
    }

    private func finishClassification(id: UUID, observations: [VNClassificationObservation], error: Error?) {
        updateResult(id: id) { result in
            result.isClassifying = false
            if let top = observations.first {
                result.breedName = Self.formatBreedName(top.identifier)
                result.confidence = "\(Int(top.confidence * 100))% confident"
            } else if let error {
                result.errorMessage = "Could not classify this image. \(error.localizedDescription)"
            } else {
                result.errorMessage = "No matching breed found."
            }
        }
    }

    private func updateResult(id: UUID, _ mutate: (inout ClassifiedImage) -> Void) {
        guard let index = results.firstIndex(where: { $0.id == id }) else { return }
        mutate(&results[index])
    }

    private static func formatBreedName(_ raw: String) -> String {
        let normalized = raw
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        let tokens = normalized
            .split(whereSeparator: { $0.isWhitespace })
            .filter { !isWordNetID($0) }
        return tokens
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    private static func isWordNetID(_ token: Substring) -> Bool {
        guard let first = token.first, first == "n" || first == "N" else { return false }
        let rest = token.dropFirst()
        return !rest.isEmpty && rest.allSatisfy { $0.isNumber }
    }
}

private extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

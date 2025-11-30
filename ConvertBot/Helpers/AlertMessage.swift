import Foundation

struct AlertMessage: Identifiable {
    let id = UUID()
    let text: String
    let logURL: URL?

    init(text: String, logURL: URL? = nil) {
        self.text = text
        self.logURL = logURL
    }
}

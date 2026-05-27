import Foundation

func normalizedSessionName(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty ? "(Untitled)" : trimmed
}

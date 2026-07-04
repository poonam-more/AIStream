import Foundation

enum HistoryServiceError: LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(Int)
    case decodingFailed
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:       return "Invalid URL."
        case .unauthorized:     return "Unauthorized. Please log in again."
        case .serverError(let code): return "Server error (\(code))."
        case .decodingFailed:   return "Failed to decode response."
        case .unknown(let e):   return e.localizedDescription
        }
    }
}

final class HistoryService {

    func fetchHistory() async throws -> [HistoryItem] {
        do {
            let decoded: HistoryResponse = try await APIClient.request(
                path: "/history",
                method: "GET",
                requiresAuth: true,
                responseType: HistoryResponse.self
            )
            return decoded.history
        } catch let urlError as URLError where urlError.code == .userAuthenticationRequired {
            throw HistoryServiceError.unauthorized
        } catch {
            throw HistoryServiceError.unknown(error)
        }
    }
}

import Foundation

/// Outcome of a backend call: the data, or a message the screen can show as is.
enum NetworkResult<T> {
    case success(T)
    case error(String, code: Int? = nil)

    var value: T? {
        if case .success(let data) = self { return data }
        return nil
    }

    var errorMessage: String? {
        if case .error(let message, _) = self { return message }
        return nil
    }

    func map<R>(_ transform: (T) -> R) -> NetworkResult<R> {
        switch self {
        case .success(let data): return .success(transform(data))
        case .error(let message, let code): return .error(message, code: code)
        }
    }
}

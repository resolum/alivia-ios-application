import Foundation

/// Turns backend failures into messages in Spanish, as the Android app shows them.
enum BaseRepository {
    static func safeCall<T>(_ call: () async throws -> T) async -> NetworkResult<T> {
        do {
            return .success(try await call())
        } catch APIError.http(let status, let detail) {
            return .error(message(status: status, detail: detail), code: status)
        } catch APIError.invalidResponse {
            return .error("La respuesta del servidor no es válida.")
        } catch {
            return .error("No pudimos conectar con Alivia. Revisa tu conexión e inténtalo otra vez.")
        }
    }

    static func message(status: Int, detail: String?) -> String {
        switch status {
        case 401: return "Tu sesión terminó. Vuelve a ingresar."
        case 403: return detail ?? "No tienes permiso para esta acción."
        case 404: return "No encontramos la orden."
        case 500...599: return "El servicio no está disponible. Inténtalo en unos minutos."
        default: return detail ?? "No se pudo completar la acción."
        }
    }
}

import Foundation

/// Debug-only logging. Compiles to nothing in Release builds.
@inlinable
func debugLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print(message())
    #endif
}

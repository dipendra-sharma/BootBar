import Foundation

public enum AvdParser {
    public static func parseAvdNames(_ output: String) -> [String] {
        output.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.contains(" | ") }
    }

    public struct EmulatorDevice: Sendable, Equatable {
        public let serial: String
        public let online: Bool
    }

    public static func parseEmulatorDevices(_ output: String) -> [EmulatorDevice] {
        output.split(whereSeparator: \.isNewline)
            .map { $0.split(separator: "\t").map { $0.trimmingCharacters(in: .whitespaces) } }
            .filter { $0.count == 2 && $0[0].hasPrefix("emulator-") }
            .map { EmulatorDevice(serial: $0[0], online: $0[1] == "device") }
    }

    public static func parseEmulatorSerials(_ output: String) -> [String] {
        parseEmulatorDevices(output).filter(\.online).map(\.serial)
    }

    public static func parseConsoleAvdName(_ output: String) -> String? {
        let line = output.split(whereSeparator: \.isNewline).first
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let line, !line.isEmpty, line != "OK", line != "KO" else { return nil }
        return line
    }

    public static func parseApiLevel(configIni: String) -> String? {
        guard let range = configIni.range(of: #"android-(\d+)"#, options: .regularExpression) else {
            return nil
        }
        return String(configIni[range].dropFirst("android-".count))
    }
}

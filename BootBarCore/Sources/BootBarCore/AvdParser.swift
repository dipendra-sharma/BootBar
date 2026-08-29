import Foundation

public enum AvdParser {
    public static func parseAvdNames(_ output: String) -> [String] {
        output.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil }
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

    public static func parseConsoleAvdName(_ output: String) -> String? {
        let line = output.split(whereSeparator: \.isNewline).first
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let line, !line.isEmpty, line != "OK", line != "KO" else { return nil }
        return line
    }

    public static func parseApiLevel(configIni: String) -> String? {
        configIni.split(whereSeparator: \.isNewline)
            .compactMap(apiLevel(inSystemImageLine:))
            .first
    }

    private static func apiLevel(inSystemImageLine line: Substring) -> String? {
        let parts = line.split(separator: "=", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        let key = parts[0].trimmingCharacters(in: .whitespaces)
        guard key == "target" || key.hasPrefix("image.sysdir.") else { return nil }
        guard let range = parts[1].range(of: #"android-\d+"#, options: .regularExpression) else { return nil }
        return String(parts[1][range].dropFirst("android-".count))
    }
}

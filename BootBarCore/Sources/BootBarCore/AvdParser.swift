import Foundation

public enum AvdParser {
    public static func parseAvdNames(_ output: String) -> [String] {
        output.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.contains(" | ") }
    }

    public static func parseEmulatorSerials(_ output: String) -> [String] {
        output.split(whereSeparator: \.isNewline)
            .map { $0.split(separator: "\t").map { $0.trimmingCharacters(in: .whitespaces) } }
            .filter { $0.count == 2 && $0[0].hasPrefix("emulator-") && $0[1] == "device" }
            .map { $0[0] }
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

import Testing
@testable import BootBarCore

@Test func parsesAvdNames() {
    let output = """
    INFO | Storing crashdata in: /tmp/x
    Pixel_9_Pro
    Pixel_8

    """
    #expect(AvdParser.parseAvdNames(output) == ["Pixel_9_Pro", "Pixel_8"])
}

@Test func parsesOnlineAdbSerials() {
    let output = """
    List of devices attached
    emulator-5554\tdevice
    emulator-5556\toffline
    R5CT123ABC\tdevice

    """
    #expect(AvdParser.parseEmulatorSerials(output) == ["emulator-5554"])
}

@Test func parsesEmulatorDevicesWithOnlineState() {
    let output = """
    List of devices attached
    emulator-5554\tdevice
    emulator-5556\toffline
    R5CT123ABC\tdevice

    """
    #expect(AvdParser.parseEmulatorDevices(output) == [
        .init(serial: "emulator-5554", online: true),
        .init(serial: "emulator-5556", online: false)
    ])
}

@Test func parsesApiLevelFromConfigIni() {
    let ini = """
    avd.ini.encoding=UTF-8
    image.sysdir.1=system-images/android-35/google_apis/arm64-v8a/
    """
    #expect(AvdParser.parseApiLevel(configIni: ini) == "35")
}

@Test func apiLevelNilWhenMissing() {
    #expect(AvdParser.parseApiLevel(configIni: "foo=bar") == nil)
}

@Test func parsesConsoleAvdNameWithCRLF() {
    #expect(AvdParser.parseConsoleAvdName("Pixel_9_Pro\r\nOK\r\n") == "Pixel_9_Pro")
}

@Test func consoleAvdNameNilForEmptyOrStatusOnly() {
    #expect(AvdParser.parseConsoleAvdName("") == nil)
    #expect(AvdParser.parseConsoleAvdName("OK\r\n") == nil)
}

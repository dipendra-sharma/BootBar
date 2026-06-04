import Testing
@testable import BootBarCore

@Test func runReturnsStdout() async throws {
    let runner = ProcessShellRunner()
    let output = try await runner.run("/bin/echo", ["hello"])
    #expect(output == "hello\n")
}

@Test func runThrowsOnNonZeroExit() async {
    let runner = ProcessShellRunner()
    await #expect(throws: ShellError.self) {
        try await runner.run("/bin/sh", ["-c", "echo bad >&2; exit 3"])
    }
}

@Test func shellErrorCarriesStderrAndExitCode() async {
    let runner = ProcessShellRunner()
    do {
        try await runner.run("/bin/sh", ["-c", "echo bad >&2; exit 3"])
        Issue.record("expected throw")
    } catch let error as ShellError {
        #expect(error.exitCode == 3)
        #expect(error.stderr.contains("bad"))
    } catch {
        Issue.record("wrong error type")
    }
}

import ArgumentParser
import Foundation
import Darwin.C
import System

@main
struct BepInExLauncher: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "Swift-BepInEx-Launcher",
        abstract: "A Swift reimplementation of the BepInEx launcher script for macOS.",
        // This allows all un-parsed arguments to be collected.
        subcommands: [],
        defaultSubcommand: nil,
        helpNames: .long
    )

    // MARK: - Arguments & Options

	// I don't think this is actually relevant for now. The original macos_proxy started a different shell script when launching a server, but for all intents and purposed, you should be able to run this one, just specifying a different target.

	//	@Flag(name: [.long, .customLong("startServer")], help: "When set to true, launches a server instead of a game.")
	//	var runServer: Bool = false

    @Flag(name: .long, inversion: .prefixedEnableDisable, exclusivity: .exclusive, help: "Doorstop injection.")
    var doorstop: Bool = true

	@Flag(name: [.long, .customLong("ignoreDisable")], help: "If true, the DOORSTOP_DISABLE environment variable is ignored.")
    var doorstopIgnoreDisabled: Bool = false

	@Flag(name: .long, inversion: .prefixedEnableDisable, exclusivity: .exclusive, help: "Enable the Mono debugger server.")
	var monoDebug: Bool = false

	@Flag(name: [.long, .customLong("debugSuspend")], inversion: .prefixedEnableDisable, exclusivity: .exclusive, help: "Suspend game on start until a Mono debugger is attached.")
	var monoDebugSuspend: Bool = false

	@Option(name: [.customLong("baseDir"), .customLong("base"), .long], help: "Base folder used for resolving other relative paths.")
	var inBaseDir: String = FileManager.default.currentDirectoryPath

	@Option(name: .long, help: "Folder in which to look for libdoorstop.")
	var doorstopDir: String = "doorstop_libs"

	@Option(name: .long, help: "Doorstop library name")
	var doorstopName: String?

	@Option(name: .long, help: "Override architecture detection for target executable. Useful when target is a shell script.")
	var targetArch: Architecture?

	@Option(name: [.long, .customLong("dllSearch"), .customLong("searchpathOverride")], parsing: .singleValue, help: "Override path for Mono DLLs.")
    var dllPaths: [String] = []

    @Option(name: [.long, .customLong("debugAddress")], help: "Address for the Mono debugger server.")
    var monoDebugAddress: String = "127.0.0.1:10000"

	@Option(name: [.long, .customLong("executable")], help: "Path to the game's .app bundle or executable.")
	var executableName: String

	@Option(name: .long, help: "Override path to boot.config")
	var bootConfig: String?

	@Option(name: [.long, .customLong("doorstopAssembly")], help: "Path to the .NET assembly to preload.")
	var targetAssembly: String = "BepInEx/core/BepInEx.Preloader.dll"

	@Option(name: [.long, .customLong("r2Profile")], help: "Path to the .NET assembly to preload.")
	var profile: String = "Default"

	@Argument(parsing: .allUnrecognized, help: "Arguments to pass through to the game executable.")
    var gameArguments: [String] = []

    // MARK: - Main Logic

    mutating func run() throws {
		let baseDir = try inBaseDir.asAbsoluteCanonicalPath(relativeTo: FileManager.default.currentDirectoryPath)
		let profileDir = try URL(string: "profiles/\(profile)/", relativeTo: URL(fileURLWithPath: baseDir))?.path.asAbsoluteCanonicalPath(relativeTo: baseDir)
		let execToRun = try getExecutableToRun(from: executableName, relativeTo: baseDir)

		let currentArch = Architecture(rawValue: MachineInfo.systemInfo(for: "hw.machine"))
		guard (currentArch != nil) else { throw BepInExError.unsupportedArch }
		if (targetArch == nil) {
			if (!execToRun.archs.contains(currentArch!)) {
				throw BepInExError.incorrectArchitecture(path: execToRun.path)
			}
			else {
				targetArch = currentArch!
			}
		}
		targetAssembly = try targetAssembly.asAbsoluteCanonicalPath(relativeTo: profileDir!)
		try setEnv("DOORSTOP_ENABLED", doorstop ? "1" : "0")
		try setEnv("DOORSTOP_TARGET_ASSEMBLY", targetAssembly)
		try setEnv("DOORSTOP_IGNORE_DISABLED_ENV", doorstopIgnoreDisabled ? "1" : "0")
		try setEnv("DOORSTOP_MONO_DEBUG_ENABLED", monoDebug ? "1" : "0")
		try setEnv("DOORSTOP_MONO_DEBUG_ADDRESS", monoDebugAddress)
		try setEnv("DOORSTOP_MONO_DEBUG_SUSPEND", monoDebugSuspend ? "1" : "0")
		try setEnv("DOORSTOP_CLR_CORLIB_DIR","")
		if let bootIni = try bootConfig?.asAbsoluteCanonicalPath(relativeTo: profileDir!) {
			try setEnv("DOORSTOP_BOOT_CONFIG_OVERRIDE", bootIni)
		}
		if (!dllPaths.isEmpty) {
			try setEnv("DOORSTOP_MONO_DLL_SEARCH_PATH_OVERRIDE", dllPaths.joined(separator: ":"))
		}
		print("Profile directory located at: \(profileDir!)")
		let doorstopPath = try doorstopDir.asAbsoluteCanonicalPath(relativeTo: profileDir!)
		try envPrepend(doorstopPath, to: "DYLD_LIBRARY_PATH", withSep: ":")
		try envPrepend(doorstopPath, to: "LD_LIBRARY_PATH", withSep: ":")
		let doorStopLib: String
		if let doorStop = doorstopName {
			doorStopLib = doorStop
		}
		else {
			doorStopLib = "libdoorstop_\(targetArch!).dylib"
		}
		try envPrepend(doorStopLib, to: "DYLD_INSERT_LIBRARIES", withSep: ":")
		try envPrepend(doorStopLib, to: "LD_PRELOAD", withSep: ":")
		print("DEBUG -- Dumping environment:")
		for (key, value) in ProcessInfo.processInfo.environment.sorted(by: { $0.key < $1.key }) {
			print("\(key): \(value)")
		}
		if (execToRun.isApplication) {
			gameArguments.insert(executableName, at: 0)
		}
		withCStrings(gameArguments) { args in
			print("Command to be run: \(execToRun.path) \(args)")
				let status = execve(
					execToRun.path,
					args,
					environ
					)
				guard (status != -1) else {
					fatalError("execv failed: \(String(cString: strerror(errno)))")
				}
		}
    }
}


// MARK: - Helper Functions

/// Determines which executable to actually run, as well as
func getExecutableToRun(from inputPath: String, relativeTo baseDir: String = FileManager.default.currentDirectoryPath) throws -> ExecutableToRun {
	let fileManager = FileManager.default
	var executablePath = try inputPath.asAbsoluteCanonicalPath(relativeTo: baseDir)

	guard fileManager.fileExists(atPath: executablePath) else {
		throw BepInExError.pathDoesNotExist(path: executablePath)
	}
	guard fileManager.isReadableFile(atPath: executablePath) else {
		throw BepInExError.permissionDenied(path: executablePath)
	}

	let fileKeys = try? URL(fileURLWithPath: executablePath).resourceValues(forKeys: [.isApplicationKey, .isExecutableKey, .isReadableKey, .isRegularFileKey, .isDirectoryKey ])
	guard (fileKeys != nil) else {
		throw BepInExError.URLResourceValuesFailed(path: executablePath)
	}
	let isApplication = fileKeys!.isApplication ?? false
	let isExecutable = fileKeys!.isExecutable ?? false
	let isReadable = fileKeys!.isReadable ?? false
	let isFile = fileKeys!.isRegularFile ?? false
	let isDirectory = fileKeys!.isDirectory ?? false

	if (!isExecutable || !isReadable) {
		throw BepInExError.permissionDenied(path: executablePath)
	}
	var archs: [Architecture] = []
	if (isApplication) {
		let bundle = Bundle(path: executablePath)
		guard (bundle != nil) else {
			throw BepInExError.couldNotFindExecutableInBundle(bundlePath: executablePath)
		}
		for _arch in bundle!.executableArchitectures! {
			let arch = Architecture(arch: _arch.intValue)
			guard arch != nil else {
				continue
			}
			archs.append(arch!)
		}
		guard (!archs.isEmpty) else {
			throw BepInExError.incorrectArchitecture(path: executablePath)
		}
		let bundleExec = bundle!.executablePath
		guard (bundleExec != nil) else {
			throw BepInExError.couldNotFindExecutableInBundle(bundlePath: executablePath)
		}
		executablePath = bundleExec!
	}
	else if (isDirectory) {
		throw BepInExError.invalidFolder(path: executablePath)
	}
	else if (isFile) {
		archs = try detectArchitecture(at: executablePath)
	}
	return ExecutableToRun(
		path: executablePath,
		isApplication: isApplication,
		isDirectory: isDirectory,
		isFile: isFile,
		isReadable: isReadable,
		isExecutable: isExecutable,
		archs: archs
	)
}

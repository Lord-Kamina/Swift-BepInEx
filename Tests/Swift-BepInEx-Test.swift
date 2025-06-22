import XCTest
import Foundation
import MachO.loader
@testable import Swift_BepInEx_Launcher // Gives access to internal types/functions

// MARK: - Main Test Class Setup
final class BepInExLauncherTests: XCTestCase {

	var testDirectoryURL: URL!

	// Create a unique temporary directory for each test run to isolate file system operations.
	override func setUpWithError() throws {
		try super.setUpWithError()
		// Create a unique temporary directory
		let tempDir = FileManager.default.temporaryDirectory
			.appendingPathComponent("BepInExTests")
			.appendingPathComponent(UUID().uuidString)

		try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
		self.testDirectoryURL = tempDir
	}

	// Clean up the temporary directory after each test.
	override func tearDownWithError() throws {
		if let testDirectoryURL = testDirectoryURL {
			try FileManager.default.removeItem(at: testDirectoryURL)
		}
		// Restore environment to avoid side effects
		unsetenv("TEST_VAR")
		try super.tearDownWithError()
	}

	// =================================================================
	// MARK: - Path Resolution & Core Logic Tests
	// =================================================================

	// --- Tests for CanonicalPath.swift ---

	func test_asAbsoluteCanonicalPath_withAbsolutePath() throws {
		// A standard, existing absolute path should remain unchanged.
		let path = "/Applications" // A path that is guaranteed to exist on macOS.
		let result = try path.asAbsoluteCanonicalPath()
		XCTAssertEqual(result, path)
	}

	func test_asAbsoluteCanonicalPath_withRelativePath() throws {
		// A relative path should be resolved correctly against the provided base directory.
		let fileURL = testDirectoryURL.appendingPathComponent("file.txt")
		FileManager.default.createFile(atPath: fileURL.path, contents: nil)

		let result = try "file.txt".asAbsoluteCanonicalPath(relativeTo: testDirectoryURL.path)
		XCTAssertEqual(result, fileURL.path)
	}

	func test_asAbsoluteCanonicalPath_withTildeExpansion() throws {
		// The "~" character should be correctly expanded to the user's home directory.
		let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
		let tildePath = "~/Documents" // A subdirectory that typically exists.

		let result = try tildePath.asAbsoluteCanonicalPath()
		// Standardizing to resolve any symlinks in the path to Documents
		let expected = (homeDir as NSString).appendingPathComponent("Documents")
		XCTAssertEqual(result, (expected as NSString).resolvingSymlinksInPath)
	}

	func test_asAbsoluteCanonicalPath_resolvingSymlink() throws {
		// A symlink path should be resolved to the path of the actual item.
		let realDir = testDirectoryURL.appendingPathComponent("real_dir")
		try FileManager.default.createDirectory(at: realDir, withIntermediateDirectories: false)
		let symlink = testDirectoryURL.appendingPathComponent("link_dir")
		try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: realDir)

		let result = try symlink.path.asAbsoluteCanonicalPath()
		XCTAssertEqual(result, realDir.path)
	}

	func test_asAbsoluteCanonicalPath_throwsForInvalidBase() throws {
		// The function must throw if the base path for a relative resolution is invalid.
		let invalidBase = "/non_existent_directory_for_testing"
		XCTAssertThrowsError(try "file.txt".asAbsoluteCanonicalPath(relativeTo: invalidBase)) { error in
			XCTAssertEqual(error as? BepInExError, .basePathInvalid(path: invalidBase))
		}
	}

	// --- Tests for getExecutableToRun ---

	func test_getExecutableToRun_withValidAppBundle() throws {
		let architectures: [Architecture] = [.x86_64, .arm64]
		let bundleURL = try createFakeAppBundle(
			named: "TestGame.app",
			execName: "TestGame",
			execArchitectures: architectures // Use the corrected argument label
		)

		let result = try getExecutableToRun(from: bundleURL.path, relativeTo: self.testDirectoryURL.path)

		XCTAssertTrue(result.isApplication)
		XCTAssertEqual(result.path, bundleURL.appendingPathComponent("Contents/MacOS/TestGame").path)
		XCTAssertEqual(Set(result.archs), Set(architectures), "Architectures from the real executable in the bundle should be correctly identified.")
	}

	func test_getExecutableToRun_withStandaloneExecutable() throws {
		// Should correctly identify a standalone executable file.
		let execURL = try createFakeBinary(named: "my_cli_game", type: .x86_64, at: self.testDirectoryURL)

		let result : Swift_BepInEx_Launcher.ExecutableToRun = try getExecutableToRun(from: execURL.path, relativeTo: self.testDirectoryURL.path)

		XCTAssertFalse(result.isApplication)
		XCTAssertTrue(result.isFile)
		XCTAssertEqual(result.path, execURL.path)
		XCTAssertEqual(result.archs, [.x86_64])
	}

	func test_getExecutableToRun_throwsForNonExistentPath() {
		// Should fail gracefully if the path does not exist.
		let badPath = testDirectoryURL.appendingPathComponent("FakeGame.app").path
		XCTAssertThrowsError(try getExecutableToRun(from: badPath, relativeTo: self.testDirectoryURL.path)) { error in
			XCTAssertEqual(error as? BepInExError, .pathDoesNotExist(path: badPath))
		}
	}

	func test_getExecutableToRun_throwsForInvalidFolder() throws {
		// Should fail if the path is a regular directory that is not an .app bundle.
		let dirURL = testDirectoryURL.appendingPathComponent("NotAnApp")
		try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: false)

		XCTAssertThrowsError(try getExecutableToRun(from: dirURL.path, relativeTo: self.testDirectoryURL.path)) { error in
			XCTAssertEqual(error as? BepInExError, .invalidFolder(path: dirURL.path))
		}
	}

	func test_getExecutableToRun_throwsForPermissionDenied() throws {
		// Should fail if the file exists but is not readable/executable.
		let execURL = try createFakeBinary(named: "no_access", type: .x86_64, at: self.testDirectoryURL)
		// Set permissions to 000 (no read/write/execute)
		try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: execURL.path)

		XCTAssertThrowsError(try getExecutableToRun(from: execURL.path, relativeTo: self.testDirectoryURL.path)) { error in
			XCTAssertEqual(error as? BepInExError, .permissionDenied(path: execURL.path))
		}
	}

	// MARK: - Test for UtilityFunctions.swift

	func test_envPrepend_createsNewVariableCorrectly() throws {
		let varName = "TEST_VAR"
		let value = "only/path"

		// Ensure variable is not set before the test
		unsetenv(varName)

		try envPrepend(value, to: varName, withSep: ":")

		let actual = ProcessInfo.processInfo.environment[varName]
		XCTAssertEqual(actual, value, "envPrepend should create a new variable if it doesn't exist.")
	}

	func test_envPrepend_correctlyPrependsWithSeparator() throws {
		let varName = "TEST_VAR"
		let initialValue = "initial/path"
		let prependValue = "new/path"

		try setEnv(varName, initialValue)
		try envPrepend(prependValue, to: varName, withSep: ":")

		let expected = "\(prependValue):\(initialValue)"
		let actual = ProcessInfo.processInfo.environment[varName]
		XCTAssertEqual(actual, expected, "envPrepend failed to insert the separator correctly.")
	}

	func test_detectArchitecture_forUniversalBinary() throws {
		let universalPath = try createFakeUniversalBinary(
			named: "my_universal_exec",
			at: self.testDirectoryURL,
			slices: [
				(type: CPU_TYPE_X86_64, subType: CPU_SUBTYPE_X86_64_ALL),
				(type: CPU_TYPE_ARM64, subType: CPU_SUBTYPE_ARM64_ALL)
			]
		).path
		XCTAssertEqual(Set(try detectArchitecture(at: universalPath)), Set([.x86_64, .arm64]))
	}

	func test_detectArchitecture_throwsFor32BitBinary() throws {
		let binaryPath = try createFake32BitBinary(named: "old_game").path
		XCTAssertThrowsError(try detectArchitecture(at: binaryPath)) { error in
			XCTAssertEqual(error as? BepInExError, .incorrectArchitecture32Bits(path: binaryPath))
		}
	}

	func test_detectArchitecture_throwsFor64BitUnsupportedArch() throws {
		let binaryPath = try createFakeBinary(
			named: "ppc_exec",
			type: .noarch, // Use .noarch to signal custom cputype
			at: self.testDirectoryURL,
			customCpuType: CPU_TYPE_POWERPC64
		).path

		XCTAssertThrowsError(try detectArchitecture(at: binaryPath)) { error in
			XCTAssertEqual(error as? BepInExError, .incorrectArchitecture(path: binaryPath))
		}
	}

	func test_detectArchitecture_throwsForUniversalBinaryWithOnlyUnsupportedArchs() throws {
		let universalPath = try createFakeUniversalBinary(
			named: "very_old_game",
			at: self.testDirectoryURL,
			slices: [(type: CPU_TYPE_I386, subType: CPU_SUBTYPE_X86_ALL)]
		).path
		XCTAssertThrowsError(try detectArchitecture(at: universalPath))
	}

	func test_detectArchitecture_returnsEmptyForNonMachOFile() throws {
		let textFilePath = testDirectoryURL.appendingPathComponent("not_an_exec.txt").path
		FileManager.default.createFile(atPath: textFilePath, contents: "Hello".data(using: .utf8))

		let result = try detectArchitecture(at: textFilePath)
		XCTAssertTrue(result.isEmpty, "A non-binary file should result in an empty architecture array.")
	}
}


	// =================================================================
	// MARK: - Argument Parsing Tests (Corrected and Comprehensive)
	// =================================================================

	func test_argumentParsing_defaults() throws {
		// Only the required "--executable" option is provided.
		let args = ["--executable", "/path/to/game"]
		let command = try BepInExLauncher.parse(args)

		// Assert that all other properties have their correct default values.
		XCTAssertEqual(command.executableName, "/path/to/game")
		XCTAssertEqual(command.inBaseDir, FileManager.default.currentDirectoryPath)
		XCTAssertEqual(command.doorstop, true)
		XCTAssertEqual(command.doorstopIgnoreDisabled, false)
		XCTAssertEqual(command.monoDebug, false)
		XCTAssertEqual(command.monoDebugSuspend, false)
		XCTAssertEqual(command.doorstopDir, "doorstop_libs")
		XCTAssertNil(command.targetArch)
		XCTAssertTrue(command.dllPaths.isEmpty)
		XCTAssertEqual(command.monoDebugAddress, "127.0.0.1:10000")
		XCTAssertEqual(command.targetAssembly, "BepInEx/core/BepInEx.Preloader.dll")
		XCTAssertTrue(command.gameArguments.isEmpty)
	}

	func test_argumentParsing_flags() throws {
		let args = [
			"--executable", "game",
			"--disable-doorstop", // Tests Flag Inversion
			"--enable-mono-debug", // Tests Flag Inversion
			"--ignoreDisable" // Tests customLong name
		]
		let command = try BepInExLauncher.parse(args)

		XCTAssertEqual(command.doorstop, false)
		XCTAssertEqual(command.monoDebug, true)
		XCTAssertEqual(command.doorstopIgnoreDisabled, true)
	}

	func test_argumentParsing_optionsWithMixedNameTypes() throws {
		let args = [
			"--executable", "game",

			// --- Test auto-generated kebab-case from `.long` ---
			// property `targetAssembly` -> `--target-assembly`
			"--target-assembly", "/custom/assembly.dll",
			// property `bootConfig` -> `--boot-config`
			"--boot-config", "/custom/boot.ini",

			// --- Test custom long names from `.customLong` ---
			"--baseDir", "/custom/base",
			"--r2Profile", "Staging",
			"--debugAddress", "localhost:12345",

			// --- Test custom long name that is repeated ---
			"--dllSearch", "path1",
			"--dllSearch", "path2"
		]
		let command = try BepInExLauncher.parse(args)

		XCTAssertEqual(command.targetAssembly, "/custom/assembly.dll")
		XCTAssertEqual(command.bootConfig, "/custom/boot.ini")
		XCTAssertEqual(command.inBaseDir, "/custom/base")
		XCTAssertEqual(command.profile, "Staging")
		XCTAssertEqual(command.monoDebugAddress, "localhost:12345")
		XCTAssertEqual(command.dllPaths, ["path1", "path2"])
	}

	func test_argumentParsing_allUnrecognizedArguments() throws {
		let args = ["--unrecognized-flag", "--executable", "MyGame.app", "positional-arg", "--disable-doorstop"]
		let command = try BepInExLauncher.parse(args)

		// Assert that a valid flag like "--disable-doorstop" is NOT captured.
		XCTAssertEqual(command.gameArguments, ["--unrecognized-flag", "positional-arg"])
	}

// MARK: - Test Suite Helper Methods

extension BepInExLauncherTests {

	@discardableResult
	private func createFakeAppBundle(named name: String, execName: String, execArchitectures: [Architecture]) throws -> URL {
		let bundleURL = testDirectoryURL.appendingPathComponent(name)
		let contentsURL = bundleURL.appendingPathComponent("Contents")
		let macOSURL = contentsURL.appendingPathComponent("MacOS")

		// 1. Create the directory structure.
		try FileManager.default.createDirectory(at: macOSURL, withIntermediateDirectories: true)

		// 2. Create the Info.plist that points to our executable name.
		let infoPlist: [String: Any] = [
			"CFBundleExecutable": execName,
			"CFBundleIdentifier": "com.bepinex.test.\(name)"
		]
		let plistData = try PropertyListSerialization.data(fromPropertyList: infoPlist, format: .xml, options: 0)
		try plistData.write(to: contentsURL.appendingPathComponent("Info.plist"))

		// 3. Generate a real (but fake) executable with the specified architectures.
		//    This is the key change: we no longer mock the Bundle property.
		if execArchitectures.count == 1 {
			// If there's only one architecture, create a thin binary.
			try createFakeBinary(named: execName, type: execArchitectures.first!, at: macOSURL)
		} else if execArchitectures.count > 1 {
			// If there are multiple, create a universal (FAT) binary.
			let slices: [(cpu_type_t, cpu_subtype_t)] = execArchitectures.map {
				switch $0 {
				case .x86_64: return (CPU_TYPE_X86_64, CPU_SUBTYPE_X86_64_ALL)
				case .arm64: return (CPU_TYPE_ARM64, CPU_SUBTYPE_ARM64_ALL)
				case .noarch: return (0, 0) // Should be filtered out or handled.
				}
			}
			try createFakeUniversalBinary(named: execName, at: macOSURL, slices: slices)
		} else {
			// If no architectures are specified, create an empty, executable file.
			FileManager.default.createFile(atPath: macOSURL.appendingPathComponent(execName).path, contents: nil)
			try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: macOSURL.appendingPathComponent(execName).path)
		}

		return bundleURL
	}

	@discardableResult
	private func createFakeBinary(named name: String, type: Architecture, at customPathURL: URL?, customCpuType: cpu_type_t? = nil) throws -> URL {
		var header = mach_header_64(); header.magic = MH_MAGIC_64

		if let customCpuType = customCpuType {
			header.cputype = customCpuType
			header.cpusubtype = 0 // Generic subtype is sufficient for this test
		} else {
			switch type {
			case .x86_64:
				header.cputype = CPU_TYPE_X86_64
				header.cpusubtype = CPU_SUBTYPE_X86_64_ALL
			case .arm64:
				header.cputype = CPU_TYPE_ARM64
				header.cpusubtype = CPU_SUBTYPE_ARM64_ALL
			case .noarch:
				header.cputype = 0
				header.cpusubtype = 0
			}
		}

		header.filetype = UInt32(MH_EXECUTE); header.ncmds = 0; header.sizeofcmds = 0; header.flags = 0

		let data = Data(bytes: &header, count: MemoryLayout<mach_header_64>.size)
		let baseURL = customPathURL ?? testDirectoryURL
		let fileURL = baseURL?.appendingPathComponent(name)

		try data.write(to: fileURL!)
		try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fileURL!.path)

		return fileURL!
	}

	@discardableResult
	private func createFake32BitBinary(named name: String) throws -> URL {
		var header = mach_header()
		header.magic = MH_MAGIC
		header.cputype = CPU_TYPE_I386
		header.cpusubtype = CPU_SUBTYPE_X86_ALL
		header.filetype = UInt32(MH_EXECUTE); header.ncmds = 0; header.sizeofcmds = 0; header.flags = 0

		let data = Data(bytes: &header, count: MemoryLayout<mach_header>.size)
		let fileURL = testDirectoryURL.appendingPathComponent(name)

		try data.write(to: fileURL)
		try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fileURL.path)

		return fileURL
	}

	@discardableResult
	private func createFakeUniversalBinary(
		named name: String,
		at customPathURL: URL?,
		slices: [(
			type: cpu_type_t,
			subType: cpu_subtype_t
		)]
	) throws -> URL {
		var data = Data(); var fatHeader = fat_header(); fatHeader.magic = FAT_MAGIC.bigEndian; fatHeader.nfat_arch = UInt32(
			slices.count
		).bigEndian
		data.append(
			Data(
				bytes: &fatHeader,
				count: MemoryLayout<fat_header>.size
			)
		)
		for slice in slices {
			var archHeader = fat_arch(); archHeader.cputype = slice.type.bigEndian; archHeader.cpusubtype = slice.subType.bigEndian; archHeader.offset = 0; archHeader.size = 0; archHeader.align = 0; data.append(
				Data(
					bytes: &archHeader,
					count: MemoryLayout<fat_arch>.size
				)
			)
		}
		let fileURL = (
			customPathURL ?? testDirectoryURL
		).appendingPathComponent(
			name
		); try data.write(
			to: fileURL
		); try FileManager.default.setAttributes(
			[.posixPermissions: 0o755],
			ofItemAtPath: fileURL.path
		)
		return fileURL
	}
}

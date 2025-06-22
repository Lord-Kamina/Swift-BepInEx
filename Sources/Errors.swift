import Foundation

/// Describes specific errors that can occur during path resolution and validation.
public enum BepInExError: Error, LocalizedError, Equatable {
	/// The provided base path for resolving a relative path is invalid.
	/// It might not exist, not be a directory, or be inaccessible.
	case basePathInvalid(path: String)

	/// The final, resolved path does not exist on the filesystem.
	case pathDoesNotExist(path: String)

	/// The item at the path exists, but the process lacks the necessary permissions to access it.
	/// For a file, this means it is not readable. For a directory, it means it is not traversable (executable).
	case permissionDenied(path: String)

	/// A general failure occurred during URL or path processing, often due to an invalid path format.
	case resolutionFailed(path: String, underlyingError: String)
	
	/// Only folders allowed are .app packages.
	case invalidFolder(path: String)
	
	/// Can't determine bundle executable.
	case couldNotFindExecutableInBundle(bundlePath: String)

	/// Target  file not a real executable.
	case notAMachOFile(path: String)

	/// Can't determine architecture for target file.
	case cantDetermineArch(path: String)

	case URLResourceValuesFailed(path: String)

	case incorrectArchitecture(path: String)

	case incorrectArchitecture32Bits(path: String)

	case unsupportedArch

	/// Provides user-friendly descriptions for each error case.
	public var errorDescription: String? {
		switch self {
		case .basePathInvalid(let path):
			return "Base path is invalid, or can't be accessed at: '\(path)'"
		case .pathDoesNotExist(let path):
			return "Item does not exist at resolved path: '\(path)'."
		case .permissionDenied(let path):
			return "Permission denied: The item at '\(path)' is not accessible. Files must be readable and directories must be traversable."
		case .resolutionFailed(let path, let underlyingError):
			return "Failed to resolve path '\(path)': \(underlyingError)"
		case .invalidFolder(let path):
			return "Target specified is a regular folder at path: \(path)"
		case .couldNotFindExecutableInBundle(let bundlePath):
			return "Could not find the main executable inside the application bundle: \(bundlePath)"
		case .notAMachOFile(let path):
			return "The target file does not appear to be a valid Mach-O executable: \(path)"
		case .cantDetermineArch(let path):
			return "Cannot determine architecture for executable at path: \(path)"
		case .unsupportedArch:
			return "Unable to detect current machine, or running on an unsupported architecture. Only x86_64 is actually supported, although the script also allows arm64 for the future."
		case .URLResourceValuesFailed(let path):
			return "Failed to determine resource values for file at: \(path)"
		case .incorrectArchitecture(let path):
			return "Current architecture not found in target at: \(path), if the target is not a Mach-O executable, manually specify the target arch using the --arch option."
		case .incorrectArchitecture32Bits(let path):
			return "Executable at: \(path) is a 32-bit executable, which is no longer supported."
		}
	}
}

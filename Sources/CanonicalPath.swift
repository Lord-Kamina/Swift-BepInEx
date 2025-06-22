import Foundation

extension String {
	/// - Parameter base: An absolute path to a directory to use as the base for resolving a
	///   relative path. Defaults to the current working directory. This base path itself
	///   is validated for existence and accessibility.
	/// - Throws: `BepInExError` if any step of the resolution or validation fails.
	/// - Returns: A `String` representing the absolute, canonical path to the file or directory.
	@available(macOS 10.15, *)
	public func asAbsoluteCanonicalPath(
		relativeTo base: String = FileManager.default.currentDirectoryPath
	) throws -> String {

		// Use modern URL APIs for robust path manipulation. They are superior to string manipulation.
		let fileManager = FileManager.default
		// The tilde character `~` must be expanded *before* we create a URL, or the URL system will treat it as a literal character.
		let expandedPath = (self as NSString).expandingTildeInPath
		if (base != fileManager.currentDirectoryPath) {
			// First, we must validate the base path itself. It must be an existing,
			// accessible directory for a relative path to be resolved correctly.
			var isBaseDirectory: ObjCBool = false
			guard fileManager.fileExists(atPath: base, isDirectory: &isBaseDirectory),
				  isBaseDirectory.boolValue,
				  fileManager.isExecutableFile(atPath: base) else {
				throw BepInExError.basePathInvalid(path: base)
			}
		}
		var tempURL = URL(fileURLWithPath: expandedPath, relativeTo: URL(fileURLWithPath: base))
		tempURL = tempURL.standardizedFileURL.resolvingSymlinksInPath()
		return tempURL.path
	}
}

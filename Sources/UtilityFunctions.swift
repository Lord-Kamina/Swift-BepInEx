import Foundation
import Darwin
import MachO

struct MachineInfo {
	// This code was written by Martin Albrecht, in
	// https://sanzaru84.medium.com/how-to-fetch-system-information-with-sysctl-in-swift-on-macos-8ffcdc9b5b99
	static func systemInfo(for key: String) -> String {
		var size = 0
		sysctlbyname(key, nil, &size, nil, 0)
		var value = [CChar](repeating: 0,  count: size)
		sysctlbyname(key, &value, &size, nil, 0)
		return String(cString: value)
	}
}

func detectArchitecture(at path: String) throws -> [Architecture] {
	var archs: [Architecture] = []
	let structSizes : [UInt32:Int] = [
		FAT_CIGAM:20,
		FAT_MAGIC:20,
		FAT_CIGAM_64: 32,
		FAT_MAGIC_64: 32,
		MH_MAGIC_64: 32,
		MH_CIGAM_64: 32,
	]
	let fileHandle = FileHandle(forReadingAtPath: path)
	guard (fileHandle != nil) else { throw BepInExError.cantDetermineArch(path: path) }
	let magic = try fileHandle?.read(upToCount: 8)
	guard (magic != nil) else { throw BepInExError.cantDetermineArch(path: path)  }
	if (magic!.count > 7) {
		let header = magic!.withUnsafeBytes { $0.load(as: fat_header.self) }
		switch header.magic {
		case FAT_CIGAM, FAT_MAGIC, FAT_CIGAM_64, FAT_MAGIC_64:
			let archCount = header.nfat_arch.bigEndian
			for _ in 1...archCount {
				let archHeader = try fileHandle?.read(upToCount: structSizes[header.magic]!)
				guard (archHeader != nil) else { throw BepInExError.cantDetermineArch(path: path)  }
				if (archHeader!.count >= structSizes[header.magic]!) {
					let fatArch = archHeader?.withUnsafeBytes { $0.load(as: fat_arch.self) }
					let cpuType = fatArch?.cputype.bigEndian
					switch cpuType {
					case CPU_TYPE_X86_64:
						archs.append(.x86_64)
					case CPU_TYPE_ARM64:
						archs.append(.arm64)
					default:
						continue
					}
				}
			}
			if (!archs.contains(.x86_64) && !archs.contains(.arm64)) {
				throw BepInExError.incorrectArchitecture(path: path)
			}
		case MH_MAGIC, MH_CIGAM:
			throw BepInExError.incorrectArchitecture32Bits(path: path)
		case MH_MAGIC_64, MH_CIGAM_64:
			try fileHandle?.seek(toOffset: 0)
			let magic = try fileHandle?.read(upToCount: structSizes[header.magic]!)
			guard (magic != nil) else { throw BepInExError.cantDetermineArch(path: path) }
			if (magic!.count >= structSizes[header.magic]!) {
				let machHeader = magic!.withUnsafeBytes { $0.load(as: mach_header_64.self) }
				let cpuType = machHeader.cputype.littleEndian
				switch cpuType {
				case CPU_TYPE_X86_64:
						archs.append(.x86_64)
				case CPU_TYPE_ARM64:
					archs.append(.arm64)
				default:
					throw BepInExError.incorrectArchitecture(path: path)
				}
			}
		default:
			break
		}
	}
	return archs
}

func withCStrings(_ strings: [String], scoped: ([UnsafeMutablePointer<CChar>?]) throws -> Void) rethrows {
	let cStrings = strings.map { strdup($0) }
	try scoped(cStrings + [nil])
	cStrings.forEach { free($0) }
}

func setEnv(_ variable: String, _ value: String) throws {
	let status = setenv(variable, value, 1)
	guard (status == 0) else {
		throw ExecError.setEnvFailed(error: String(cString: strerror(errno)))
	}
}

func envPrepend(_ value: String, to variable: String, withSep: String = "") throws {
	var newValue: String = value
	if let previousValue = ProcessInfo.processInfo.environment[variable] {
		newValue.append(withSep.appending(previousValue))
	}
	try setEnv(variable, newValue)
}

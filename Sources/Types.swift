//
//  Types.swift
//  
//
//  Created by Gregorio Litenstein Goldzweig on 17/06/2025.
//

import ArgumentParser

import Foundation

enum Architecture: String, ExpressibleByArgument {
	/// arm64 is not yet actually supported but it most likely will be eventually.
	case x86_64, arm64, noarch
	init?(arch: Int) {
		switch arch {
		case NSBundleExecutableArchitectureX86_64: self = .x86_64
		case NSBundleExecutableArchitectureARM64: self = .arm64
		case -1: self = .noarch
		default: return nil
		}
	}
}

struct ExecutableToRun {
	let path: String
	let isApplication: Bool
	let isDirectory: Bool
	let isFile: Bool
	let isReadable: Bool
	let isExecutable: Bool
	let archs: [Architecture]
}

enum ExecError: Error {
	case executionFailed(error: String)
	case setEnvFailed(error: String)
}

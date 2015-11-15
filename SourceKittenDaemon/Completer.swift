//
//  Completer.swift
//  SourceKittenDaemon
//
//  Created by Benedikt Terhechte on 12/11/15.
//  Copyright © 2015 Benedikt Terhechte. All rights reserved.
//

import Foundation
import SourceKittenFramework
import SwiftXPC


/**
Simple wrapper around an Xcode project. Can be a 
- Project (.xcodeproj)
- Workspace (.xcworkspace)
- Folder (future / linux)
Where a folder has to have some sort of other compile infrastructure. I've
just included it for completeness' sake
*/
internal enum ProjectType {
    case Project(project: String)
    case Workspace(workspace: String)
    case Folder(path: String)
    
    func folderPath() -> String {
        if case .Folder(let f) = self { return f }
        return (self.path() as NSString).stringByDeletingLastPathComponent
    }
    
    func path() -> String {
        switch self {
        case .Project(project: let s):
            return s
        case .Workspace(workspace: let s):
            return s
        case .Folder(path: let s):
            return s
        }
    }

    func xcodeprojURL() -> NSURL? {
        switch self {
        case .Project: return NSURL(fileURLWithPath: path(), isDirectory: true)
        // @TODO : implement folder and workspace support. This involves looking for
        // nested .xcodeproj's but workspaces will have to somehow support multiple .xcodeproj's
        case .Folder: fatalError("Folder projects not supported yet")
        case .Workspace: fatalError("Workspace projects not supported yet")
        }
    }
    
}

internal enum CompletionResult {
    case Success(result: [CodeCompletionItem])
    case Failure(message: String)
    
    func asJSON() -> NSData? {
        guard case .Success(let result) = self,
            let json = try? NSJSONSerialization.dataWithJSONObject(result.map { $0.dictionaryValue }, options: .PrettyPrinted)
            else { return nil }
        return json
    }
    
    func asJSONString() -> String? {
        guard let data = self.asJSON() else { return nil }
        return String(data: data, encoding: NSUTF8StringEncoding)
    }
}

/**
This keeps the connection to the XPC via SourceKitten and is being called
from the Completion Server to perform completions. */
internal class Completer {
    
    // The Arguments for XPC, i.e. SDK, Frameworks
    private let compilerArgs: [String]
    
    // The Base path to the .xcodeproj / workspace
    private let baseProject: ProjectType
    
    internal init(project: ProjectType, parser: XcodeParser) {
        self.baseProject = project
        self.compilerArgs = ["-c", project.folderPath(), "-sdk", sdkPath()]
        // FIXME: Parse the project, and get more info
    }
    
    /**
    For a folder-based project, there is no xcode parser required
    */
    internal init(project: ProjectType) {
        self.compilerArgs = []
        self.baseProject = project
    }
    
    internal func complete(filePath: String, fileInProject: String, offset: Int) -> CompletionResult {
        
        let path = filePath.absolutePathRepresentation()
        let contents: String
        if let file = File(path: path) {
            contents = file.contents
        } else {
            return .Failure(message: "Could not read file")
        }
        
        let request = Request.CodeCompletionRequest(file: path, contents: contents,
            offset: Int64(offset),
            arguments: self.compilerArgs)
        
        let response = CodeCompletionItem.parseResponse(request.send())
        
        return .Success(result: response)
    }
    
}

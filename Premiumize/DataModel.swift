//
//  DataModel.swift
//  Premiumize
//
//  Created by Tim Haug on 31.01.18.
//  Copyright © 2018 timh1004. All rights reserved.
//

import Foundation

enum Status: String, Codable {
    case success
    case error
}

enum FileType: String, Codable {
    case folder
    case file
}

enum TranscodeStatus: String, Codable {
    case notApplicable
    case goodAsIs
    case finished
    
    enum CodingKeys: String, CodingKey {
        case notApplicable = "not_applicable"
        case goodAsIs = "good_as_is"
        case finished
        
    }
}

enum TransferStatus: String, Codable {
    	case waiting
        case finished
        case deleted
        case banned
        case error
        case timeout
        case seeding
        case queued
    case running
}

struct Response: Codable {
    let status: Status
    let message: String?
}

struct CreateResult: Codable {
    let name: String?
    let id: String?
    let message: String?
    let status: Status
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        do {
            name = try container.decode(String.self, forKey: .name)
        } catch  {
            name = nil
        }
        do {
            id = try container.decode(String.self, forKey: .id)
        } catch  {
            id = nil
        }
        do {
            message = try container.decode(String.self, forKey: .message)
        } catch  {
            message = nil
        }
        status = try container.decode(Status.self, forKey: .status)
    }
}

struct Result : Codable {
    let fileList: [File]
    let status: Status
    
    enum CodingKeys : String, CodingKey {
        case fileList = "content"
        case status
    }
}

struct File: Codable {
    let name: String
    let id: String
    let type: FileType
    let createdAt: Double?
    let link: URL?
    let streamLink: URL?
    let transcodeStatus: TranscodeStatus?
    let size: Int64?
    
    
    enum CodingKeys : String, CodingKey {
        case name
        case id
        case type
        case createdAt = "created_at"
        case link
        case streamLink = "stream_link"
        case transcodeStatus = "transcode_status"
        case size
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(FileType.self, forKey: .type)
        do {
            createdAt = try container.decode(Double.self, forKey: .createdAt)
        } catch  {
            createdAt = nil
        }
        
        do {
            link = try container.decode(URL.self, forKey: .link)
        } catch  {
            link = nil
        }
        
        do {
            streamLink = try container.decode(URL.self, forKey: .streamLink)
        } catch  {
            streamLink = nil
        }
        
        do {
            transcodeStatus = try container.decode(TranscodeStatus.self, forKey: .transcodeStatus)
        } catch  {
            transcodeStatus = nil
        }
        
        do {
            size = try container.decode(Int64.self, forKey: .size)
        } catch  {
            size = nil
        }
    }
}

struct TransferResult : Codable {
    let transferList: [Transfer]
    let status: Status
    
    enum CodingKeys : String, CodingKey {
        case transferList = "transfers"
        case status
    }
}

struct Transfer: Codable {
    //        let schname: String
    let name: String
    let id: String
    let status: TransferStatus
    let message: String?
    let progress: Double
    let targetFolderId: String?
    let folderId: String?
    let fileId: String?
    
    
    enum CodingKeys : String, CodingKey {
        case name
        case id
        case status
        case message
        case progress
        case targetFolderId = "target_folder_id"
        case folderId = "folder_id"
        case fileId = "file_id"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        id = try container.decode(String.self, forKey: .id)
        status = try container.decode(TransferStatus.self, forKey: .status)
        do {
            message = try container.decode(String.self, forKey: .message)
        } catch  {
            message = nil
        }
        
        do {
            let progressString = try container.decode(String.self, forKey: .progress)
            progress = Double(progressString) ?? 0
        } catch {
            progress = 0
        }
        
        do {
            targetFolderId = try container.decode(String.self, forKey: .targetFolderId)
        } catch  {
            targetFolderId = nil
        }
        
        do {
            folderId = try container.decode(String.self, forKey: .folderId)
        } catch  {
            folderId = nil
        }
        
        do {
            fileId = try container.decode(String.self, forKey: .fileId)
        } catch  {
            fileId = nil
        }
    }
}

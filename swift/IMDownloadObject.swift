//
//  IMDownloadObject.swift
//  IMFileManager
//
//  Created by iMokhles on 20/11/2017.
//  Copyright © 2017 iMokhles. All rights reserved.
//

import Foundation
import CoreGraphics

typealias IMDownloadRemainingTimeBlock = (_ seconds: Int?) -> Void
typealias IMDownloadProgressBlock = (_ progress: CGFloat?) -> Void
typealias IMDownloadCompletionBlock = (_ completed: Bool?) -> Void


class IMDownloadObject: NSObject {
    
    var progressBlock: IMDownloadProgressBlock
    var completionBlock: IMDownloadCompletionBlock
    var remainingTimeBlock: IMDownloadRemainingTimeBlock

    var downloadTask: URLSessionDownloadTask!
    var fileName: String!
    var friendlyName: String!
    var directoryName: String!
    var startDate: NSDate!

    init(withDownloadTask downloadTask: URLSessionDownloadTask, progressBlock: @escaping IMDownloadProgressBlock, remainingTimeBlock: @escaping IMDownloadRemainingTimeBlock, completionBlock: @escaping IMDownloadCompletionBlock) {
        
        self.downloadTask = downloadTask
        self.progressBlock = progressBlock
        self.remainingTimeBlock = remainingTimeBlock
        self.completionBlock = completionBlock
        
    }
}

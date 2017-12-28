//
//  IMDownloader.swift
//  IMFileManager
//
//  Created by iMokhles on 20/11/2017.
//  Copyright © 2017 iMokhles. All rights reserved.
//

import Foundation
import CoreGraphics
import UIKit
class IMDownloader: NSObject, URLSessionDelegate, URLSessionDownloadDelegate {
    
    // Identifiers
    let backgroudnSessionId = "re.touchwa.downloadmanager"
    
    
    var backgroundTransferCompletionHandler: (() -> Void)? = nil
    var session: URLSession?
    var backgroundSession: URLSession?
    var downloads = [AnyHashable: Any]()
    
    static let sharedInstance: IMDownloader = { IMDownloader() }()

    
    override init() {
        super.init()
        
        // Default session
        let configuration = URLSessionConfiguration.default
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        // Background session
        var backgroundConfiguration: URLSessionConfiguration? = nil
        if floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_7_1 {
            backgroundConfiguration = URLSessionConfiguration.background(withIdentifier: (Bundle.main.bundleIdentifier)!)
        }
        else {
            backgroundConfiguration = URLSessionConfiguration.background(withIdentifier: self.backgroudnSessionId)
        }
        backgroundSession = URLSession(configuration: backgroundConfiguration!, delegate: self, delegateQueue: nil)
        downloads = [AnyHashable: Any]()
    }
    
    // MARK: - Downloading...
    
    func downloadFile(forURL urlString: String, withName fileName: String, inDirectoryNamed directory: String, friendlyName: String, progressBlock: @escaping IMDownloadProgressBlock, remainingTime remainingTimeBlock: @escaping IMDownloadRemainingTimeBlock, completionBlock: @escaping IMDownloadCompletionBlock, enableBackgroundMode backgroundMode: Bool) {
        
        let url = URL(string: urlString)
        
        var fileNameVar = fileName
        if fileName == "" {
            fileNameVar = (urlString as NSString).lastPathComponent
        }
        var friendlyNameVar = fileNameVar

        if friendlyName == "" {
            friendlyNameVar = fileNameVar
        }
        if !fileDownloadCompleted(forUrl: urlString) {
            print("File is downloading!")
        } else if !(fileExists(withName: fileName, inDirectory: directory)) {
            let request = URLRequest(url: url!)
            var downloadTask: URLSessionDownloadTask?
            if backgroundMode {
                downloadTask = backgroundSession?.downloadTask(with: request)
            } else {
                downloadTask = session?.downloadTask(with: request)
            }
            let downloadObject = IMDownloadObject(withDownloadTask: downloadTask!, progressBlock: progressBlock, remainingTimeBlock: remainingTimeBlock, completionBlock: completionBlock)
            downloadObject.startDate = NSDate()
            downloadObject.fileName = fileNameVar
            downloadObject.friendlyName = friendlyNameVar
            downloadObject.directoryName = directory
            for (k, v) in [urlString: downloadObject] { downloads.updateValue(v, forKey: k) }
        }
        
    }
    func downloadFile(forURL urlString: String, withName fileName: String, inDirectoryNamed directory: String?, progressBlock: @escaping (_ progress: CGFloat) -> Void, remainingTime remainingTimeBlock: @escaping (_ seconds: Int) -> Void, completionBlock: @escaping (_ completed: Bool) -> Void, enableBackgroundMode backgroundMode: Bool) {
    }
    func downloadFile(forURL url: String, inDirectoryNamed directory: String?, progressBlock: @escaping (_ progress: CGFloat) -> Void, remainingTime remainingTimeBlock: @escaping (_ seconds: Int) -> Void, completionBlock: @escaping (_ completed: Bool) -> Void, enableBackgroundMode backgroundMode: Bool) {
        downloadFile(forURL: url, withName: (url as NSString).lastPathComponent, inDirectoryNamed: directory, progressBlock: progressBlock, remainingTime: remainingTimeBlock, completionBlock: completionBlock, enableBackgroundMode: backgroundMode)
    }
    func downloadFile(forURL url: String, progressBlock: @escaping (_ progress: CGFloat) -> Void, remainingTime remainingTimeBlock: @escaping (_ seconds: Int) -> Void, completionBlock: @escaping (_ completed: Bool) -> Void, enableBackgroundMode backgroundMode: Bool) {
        downloadFile(forURL: url, withName: (url as NSString).lastPathComponent, inDirectoryNamed: nil, progressBlock: progressBlock, remainingTime: remainingTimeBlock, completionBlock: completionBlock, enableBackgroundMode: backgroundMode)
    }
    func downloadFile(forURL urlString: String, withName fileName: String, inDirectoryNamed directory: String?, progressBlock: @escaping (_ progress: CGFloat) -> Void, completionBlock: @escaping (_ completed: Bool) -> Void, enableBackgroundMode backgroundMode: Bool) {
        downloadFile(forURL: urlString, withName: fileName, inDirectoryNamed: directory, progressBlock: progressBlock, remainingTime: {_ in }, completionBlock: completionBlock, enableBackgroundMode: backgroundMode)
    }
    func downloadFile(forURL urlString: String, inDirectoryNamed directory: String?, progressBlock: @escaping (_ progress: CGFloat) -> Void, completionBlock: @escaping (_ completed: Bool) -> Void, enableBackgroundMode backgroundMode: Bool) {
        // if no file name was provided, use the last path component of the URL as its name
        downloadFile(forURL: urlString, withName: (urlString as NSString).lastPathComponent, inDirectoryNamed: directory, progressBlock: progressBlock, completionBlock: completionBlock, enableBackgroundMode: backgroundMode)
    }
    func downloadFile(forURL urlString: String, progressBlock: @escaping (_ progress: CGFloat) -> Void, completionBlock: @escaping (_ completed: Bool) -> Void, enableBackgroundMode backgroundMode: Bool) {
        downloadFile(forURL: urlString, inDirectoryNamed: nil, progressBlock: progressBlock, completionBlock: completionBlock, enableBackgroundMode: backgroundMode)
    }
    
    func cancelDownload(forUrl fileIdentifier: String) {
        let download = downloads[fileIdentifier] as? IMDownloadObject
        if download != nil {
            download?.downloadTask.cancel()
            downloads.removeValue(forKey: fileIdentifier)
            if download?.completionBlock != nil {
                download?.completionBlock(false)
            }
        }
        if downloads.count == 0 {
            cleanTmpDirectory()
        }
    }
    
    func cancelAllDownloads() {
        downloads.forEach { (arg: (key: AnyHashable, value: Any)) in
            
            let (key, download) = arg
            if (download as! IMDownloadObject).completionBlock != nil {
                (download as! IMDownloadObject).completionBlock(false)
            }
            (download as! IMDownloadObject).downloadTask.cancel()
            downloads.removeValue(forKey: key)
        }
        cleanTmpDirectory()
    }
    
    func currentDownloads() -> [Any] {
        var currentDownloads = [AnyHashable]()
        downloads.forEach { (arg: (key: AnyHashable, value: Any)) in
            let (key, download) = arg
            currentDownloads.append((download as! IMDownloadObject).downloadTask.originalRequest?.url?.absoluteString ?? "")

        }
        return currentDownloads
    }
    
    // MARK: - NSURLSession Delegate
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let fileIdentifier: String = downloadTask.originalRequest!.url!.absoluteString
        let download = downloads[fileIdentifier] as? IMDownloadObject
        if download?.progressBlock != nil {
            let progress = CGFloat(totalBytesWritten) / CGFloat(totalBytesExpectedToWrite)
            DispatchQueue.main.async(execute: {
                if download?.progressBlock != nil {
                    download?.progressBlock(progress)
                    //exception when progressblock is nil
                }
            })
        }
        
        let remainingTime: CGFloat = self.remainingTime(forDownload: download!, bytesTransferred: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
        if download!.remainingTimeBlock != nil {
            DispatchQueue.main.async(execute: {
                if download?.remainingTimeBlock != nil {
                    download?.remainingTimeBlock(Int(remainingTime))
                }
            })
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        //    NSLog(@"Download finisehd!");
        var error: Error?
        var destinationLocation: URL?
        let fileIdentifier: String = downloadTask.originalRequest!.url!.absoluteString
        let download = downloads[fileIdentifier] as? IMDownloadObject
        var success = true
        if (downloadTask.response is HTTPURLResponse) {
            let statusCode: Int = ((downloadTask.response as? HTTPURLResponse)?.statusCode)!
            if (statusCode >= 400) {
                print("ERROR: HTTP status code \(statusCode)")
                success = false
            }
        }
        
        if success {
            if (download!.directoryName != nil) {
                destinationLocation = cachesDirectoryUrlPath().appendingPathComponent((download?.directoryName)!).appendingPathComponent((download?.fileName)!)
            }
            else {
                destinationLocation = cachesDirectoryUrlPath().appendingPathComponent((download?.fileName)!)
            }
            // Move downloaded item from tmp directory to te caches directory
            // (not synced with user's iCloud documents)
            try? FileManager.default.moveItem(at: location, to: destinationLocation!)
            if error != nil {
                print("ERROR: \(error)")
            }
        }
        
        if download?.completionBlock != nil {
            DispatchQueue.main.async(execute: {
                download?.completionBlock(success)
            })
        }
        // remove object from the download
        downloads.removeValue(forKey: fileIdentifier)
        DispatchQueue.main.async(execute: {() -> Void in
            // Show a local notification when download is over.
            let localNotification = UILocalNotification()
            localNotification.alertBody = "\(download?.friendlyName) has been downloaded"
            UIApplication.shared.presentLocalNotificationNow(localNotification)
        })
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error != nil {
            print("ERROR: \(error)")
            let fileIdentifier: String? = task.originalRequest?.url?.absoluteString
            let download = downloads[fileIdentifier!] as? IMDownloadObject
            if download?.completionBlock != nil {
                DispatchQueue.main.async(execute: {
                    download?.completionBlock(false)
                })
            }
            // remove object from the download
            downloads.removeValue(forKey: fileIdentifier!)
        }
    }

    func remainingTime(forDownload download: IMDownloadObject, bytesTransferred: Int64, totalBytesExpectedToWrite: Int64) -> CGFloat {
        let timeInterval: TimeInterval = Date().timeIntervalSince(download.startDate as Date)
        let speed = CGFloat(bytesTransferred) / CGFloat(timeInterval)
        let remainingBytes = CGFloat((totalBytesExpectedToWrite - bytesTransferred))
        let remainingTime: CGFloat = remainingBytes / speed
        return remainingTime
    }


    
    // MARK: - File Management
    func createDirectoryNamed(_ directory: String) -> Bool {
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        let cachesDirectory: String = paths[0]
        let targetDirectory: String = URL(fileURLWithPath: cachesDirectory).appendingPathComponent(directory).absoluteString
        var error: Error?
        return ((try? FileManager.default.createDirectory(atPath: targetDirectory, withIntermediateDirectories: true, attributes: nil)) != nil)
    }
    
    func cachesDirectoryUrlPath() -> URL {
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        let cachesDirectory: String = paths[0]
        let cachesDirectoryUrl = URL(fileURLWithPath: cachesDirectory)
        return cachesDirectoryUrl
    }
    
    func fileDownloadCompleted(forUrl fileIdentifier: String) -> Bool {
        var retValue = true
        let download = downloads[fileIdentifier] as? IMDownloadObject
        if download != nil {
            // downloads are removed once they finish
            retValue = false
        }
        return retValue
    }
    
    func isFileDownloading(forUrl fileIdentifier: String) -> Bool {
        return isFileDownloading(forUrl: fileIdentifier, withProgressBlock: { (float) in
            //
        })
    }
    
    func isFileDownloading(forUrl fileIdentifier: String, withProgressBlock block: @escaping IMDownloadProgressBlock) -> Bool {
        return isFileDownloading(forUrl: fileIdentifier, withProgressBlock: block, completionBlock: { (completed) in
            //
        })
    }
    
    func isFileDownloading(forUrl fileIdentifier: String, withProgressBlock block: @escaping IMDownloadProgressBlock, completionBlock: @escaping IMDownloadCompletionBlock) -> Bool {
        var retValue = false
        let download = downloads[fileIdentifier] as? IMDownloadObject
        if download != nil {
            if block != nil {
                download?.progressBlock = block
            }
            if completionBlock != nil {
                download?.completionBlock = completionBlock
            }
            retValue = true
        }
        return retValue
    }


    
    // MARK: File existance
    
    func localPath(forFile fileIdentifier: String) -> String {
        return localPath(forFile: fileIdentifier as NSString, inDirectory: nil)
    }
    
    func localPath(forFile fileIdentifier: NSString, inDirectory directoryName: String?) -> String {
        let fileName: String = fileIdentifier.lastPathComponent
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        let cachesDirectory: String = paths[0]
        return URL(fileURLWithPath: URL(fileURLWithPath: cachesDirectory).appendingPathComponent(directoryName!).absoluteString).appendingPathComponent(fileName).absoluteString
    }
    
    func fileExists(forUrl urlString: String) -> Bool {
        return fileExists(forUrl: urlString as NSString, inDirectory: "")
    }
    
    func fileExists(forUrl urlString: NSString, inDirectory directoryName: NSString) -> Bool {
        return fileExists(withName: urlString.lastPathComponent, inDirectory: directoryName as String)
    }
    
    func fileExists(withName fileName: String, inDirectory directoryName: String) -> Bool {
        var exists = false
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        let cachesDirectory: String = paths[0]
        // if no directory was provided, we look by default in the base cached dir
        if FileManager.default.fileExists(atPath: URL(fileURLWithPath: URL(fileURLWithPath: cachesDirectory).appendingPathComponent(directoryName).absoluteString).appendingPathComponent(fileName).absoluteString) {
            exists = true
        }
        return exists
    }
    func fileExists(withName fileName: String) -> Bool {
        return fileExists(withName: fileName, inDirectory: "")
    }
    
    // MARK: File deletion
    
    func deleteFile(forUrl urlString: String) -> Bool {
        return deleteFile(forUrl: urlString, inDirectory: "")
    }
    
    func deleteFile(forUrl urlString: String, inDirectory directoryName: String) -> Bool {
        return deleteFile(withName: (urlString as NSString).lastPathComponent, inDirectory: directoryName)
    }
    
    func deleteFile(withName fileName: String) -> Bool {
        return deleteFile(withName: fileName, inDirectory: "")
    }
    func deleteFile(withName fileName: String, inDirectory directoryName: String) -> Bool {
        var deleted = false
        var error: Error?
        var fileLocation: URL?
        if directoryName != "" {
            fileLocation = cachesDirectoryUrlPath().appendingPathComponent(directoryName).appendingPathComponent(fileName)
        }
        else {
            fileLocation = cachesDirectoryUrlPath().appendingPathComponent(fileName)
        }
        // Move downloaded item from tmp directory to te caches directory
        // (not synced with user's iCloud documents)
        try? FileManager.default.removeItem(at: fileLocation!)
        if error != nil {
            deleted = false
            print("Error deleting file: \(error)")
        }
        else {
            deleted = true
        }
        return deleted
    }
    
    // MARK: - Clean directory
    
    func cleanDirectoryNamed(_ directory: String) {
        let fm = FileManager.default
        var error: Error? = nil
        for file: String in try! fm.contentsOfDirectory(atPath: directory) {
            try? fm.removeItem(atPath: URL(fileURLWithPath: directory).appendingPathComponent(file).absoluteString)
        }
    }
    
    func cleanTmpDirectory() {
        let tmpDirectory = try? FileManager.default.contentsOfDirectory(atPath: NSTemporaryDirectory())
        for file: String in tmpDirectory! {
            try? FileManager.default.removeItem(atPath: "\(NSTemporaryDirectory())\(file)")
        }
    }
    
    // MARK: - Background download
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        // Check if all download tasks have been finished.
        session.getTasksWithCompletionHandler { (_ dataTasks: [URLSessionDataTask], _ uploadTasks: [URLSessionUploadTask], _ downloadTasks: [URLSessionDownloadTask]) in
            if downloadTasks.count == 0 {
                if self.backgroundTransferCompletionHandler != nil {
                    // Copy locally the completion handler.
                    let completionHandler: (() -> Void)? = self.backgroundTransferCompletionHandler
                    OperationQueue.main.addOperation({() -> Void in
                        // Call the completion handler to tell the system that there are no other background transfers.
                        completionHandler!()
                        
                        // Show a local notification when all downloads are over.
                        let localNotification = UILocalNotification()
                        localNotification.alertBody = "All files have been downloaded!"
                        UIApplication.shared.presentLocalNotificationNow(localNotification)
                    })
                    // Make nil the backgroundTransferCompletionHandler.
                    self.backgroundTransferCompletionHandler = nil
                }
            }
        }
    }
}

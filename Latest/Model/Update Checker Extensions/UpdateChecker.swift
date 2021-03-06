//
//  UpdateChecker.swift
//  Latest
//
//  Created by Max Langer on 07.04.17.
//  Copyright © 2017 Max Langer. All rights reserved.
//

import Foundation

/**
 Protocol that defines some methods on reporting the progress of the update checking process.
 */
protocol UpdateCheckerProgress : class {
    
    /**
     The process of checking apps for updates has started
     - parameter numberOfApps: The number of apps that will be checked
     */
    func startChecking(numberOfApps: Int)
    
    /// Indicates that a single app has been checked.
    func didCheckApp()
}

/**
 UpdateChecker handles the logic for checking for updates.
 Each new method of checking for updates should be implemented in its own extension and then included in the `updateMethods` array
 */
struct UpdateChecker {
    
    /// The delegate for the progress of the entire update checking progress
    weak var progressDelegate : UpdateCheckerProgress?
    
    /// The delegate that will be assigned to all AppBundles
    weak var appUpdateDelegate : AppBundleDelegate?
    
    /// The methods that are executed upon each app
    private let updateMethods : [(UpdateChecker) -> (String, String, String) -> Bool] = [
        updatesThroughMacAppStore,
        updatesThroughSparkle
    ]
    
    private var folderListener : FolderUpdateListener?
    
    /// The url of the /Applications folder on the users Mac
    var applicationURL : URL? {
        let applicationURLList = fileManager.urls(for: .applicationDirectory, in: .localDomainMask)
        
        return applicationURLList.first
    }
    
    /// The path of the users /Applications folder
    private var applicationPath : String {
        return applicationURL?.path ?? "/Applications/"
    }
    let fileManager = FileManager.default
    
    /// Starts the update checking process
    mutating func run() {
        if self.folderListener == nil, let url = self.applicationURL {
            self.folderListener = FolderUpdateListener(url: url, updateChecker: self)
        }
        
        self.folderListener?.resumeTracking()
        
        let fileManager = FileManager.default
        guard var apps = try? fileManager.contentsOfDirectory(atPath: self.applicationPath), let url = self.applicationURL else { return }
        
        self.progressDelegate?.startChecking(numberOfApps: apps.count)
        
        for method in self.updateMethods {
            apps = apps.filter({ (file) -> Bool in
                var contentURL = url.appendingPathComponent(file)
                contentURL = contentURL.appendingPathComponent("Contents")
                
                // Check, if the changed file was the Info.plist
                guard let plists = try? FileManager.default.contentsOfDirectory(at: contentURL, includingPropertiesForKeys: nil)
                    .filter({ $0.pathExtension == "plist" }),
                    let plistURL = plists.first,
                    let infoDict = NSDictionary(contentsOf: plistURL),
                    let version = infoDict["CFBundleShortVersionString"] as? String,
                    let buildNumber = infoDict["CFBundleVersion"] as? String else { return true }
                
                return !method(self)(file, version, buildNumber)
            })
        }
        
        for _ in apps {
            self.progressDelegate?.didCheckApp()
        }
    }
    
}

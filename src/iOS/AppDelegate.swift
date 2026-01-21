// SPDX-License-Identifier: MIT
// AURA — Turn voice into a living fingerprint
// iOS/AppDelegate.swift — iOS application delegate

#if os(iOS)

import UIKit

// MARK: - Window Configuration

/// Shared window configuration for consistent appearance.
enum AuraWindowConfiguration {
    /// AURA background color: near-black (#0E0F12)
    static let backgroundColor = UIColor(red: 0.055, green: 0.059, blue: 0.071, alpha: 1.0)
    
    /// Configure a window with AURA appearance.
    static func configure(_ window: UIWindow) {
        window.overrideUserInterfaceStyle = .dark
        window.backgroundColor = backgroundColor
    }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    
    // MARK: - Properties
    
    var window: UIWindow?
    
    // MARK: - Application Lifecycle
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        // Create main window
        window = UIWindow(frame: UIScreen.main.bounds)
        
        // Create and set root view controller
        let viewController = AuraViewController()
        window?.rootViewController = viewController
        
        // Configure appearance
        if let window = window {
            AuraWindowConfiguration.configure(window)
        }
        
        // Show window
        window?.makeKeyAndVisible()
        
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Handle app becoming inactive
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Handle app entering background
        // Note: Recording should be handled gracefully
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Handle app returning to foreground
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Handle app becoming active
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Cleanup before termination
        if let viewController = window?.rootViewController as? AuraViewController {
            viewController.coordinator?.cancelExport()
            viewController.coordinator?.stopRecording()
        }
    }
    
    // MARK: - Scene Configuration (iOS 13+)
    
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(
        _ application: UIApplication,
        didDiscardSceneSessions sceneSessions: Set<UISceneSession>
    ) {
        // Handle discarded scene sessions
    }
}

// MARK: - SceneDelegate (iOS 13+)

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        
        // Create window with scene
        window = UIWindow(windowScene: windowScene)
        
        // Create and set root view controller
        let viewController = AuraViewController()
        window?.rootViewController = viewController
        
        // Configure appearance using shared configuration
        if let window = window {
            AuraWindowConfiguration.configure(window)
        }
        
        // Show window
        window?.makeKeyAndVisible()
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // Handle scene disconnect
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Handle scene becoming active
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        // Handle scene becoming inactive
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        // Handle scene entering foreground
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Handle scene entering background
    }
}

#endif

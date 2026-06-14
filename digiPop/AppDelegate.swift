//
//  AppDelegate.swift
//  digiPop
//
//  Created by Adam Gillen on 5/16/26.
//

import UIKit
import UserMessagingPlatform

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Pre-fetch consent status so it's ready by the time the root VC appears.
        // Actual form presentation and MobileAds.shared.start() happen in GameViewController
        // after consent is confirmed, as required by Google and Apple ATT policy.
        ConsentInformation.shared.requestConsentInfoUpdate(
            with: RequestParameters()
        ) { _ in }
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}

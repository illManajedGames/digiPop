//
//  AppDelegate.swift
//  digiPop
//
//  Created by Adam Gillen on 5/16/26.
//

import UIKit
import GoogleMobileAds
import UserMessagingPlatform

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Start the SDK as early as possible (Google's recommendation).
        // Actual ad loading is gated on consent in GameViewController.
        MobileAds.shared.start()
        // Pre-fetch consent status so it's ready by the time the root VC appears.
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

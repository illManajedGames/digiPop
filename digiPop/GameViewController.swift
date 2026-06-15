import UIKit
import SpriteKit
import GoogleMobileAds
import UserMessagingPlatform

class GameViewController: UIViewController {

    // Set to true to hide ads for screenshots / App Store captures
    static let screenshotMode = false

    private var bannerView: BannerView!
    private var bannerSetup = false
    private var consentFlowStarted = false
    private var splashFinished = false

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let view = self.view as? SKView else { return }
        view.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1)

        let scene = SplashScene(size: view.bounds.size)
        scene.scaleMode = .aspectFill
        view.presentScene(scene)

        view.ignoresSiblingOrder = true
        view.showsFPS = false
        view.showsNodeCount = false

        // Register before the splash can fire so splashFinished is always recorded,
        // even if the consent flow delays banner setup past the 2s splash.
        NotificationCenter.default.addObserver(self, selector: #selector(onSplashDidFinish),
                                               name: .splashDidFinish, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !Self.screenshotMode, !consentFlowStarted else { return }
        consentFlowStarted = true

        // Present the UMP consent form if required (handles GDPR, CCPA, and the ATT prompt).
        // Always start ads on completion — the SDK serves non-personalized ads when
        // explicit consent wasn't collected (handles GDPR automatically).
        ConsentForm.loadAndPresentIfRequired(from: self) { [weak self] _ in
            self?.startMobileAds()
        }
        // Fast path: start ads immediately if consent is already established.
        if ConsentInformation.shared.canRequestAds {
            startMobileAds()
        }
    }

    private func startMobileAds() {
        guard !bannerSetup else { return }
        bannerSetup = true
        setupBanner()
    }

    private func setupBanner() {
        let safeWidth = view.frame.inset(by: view.safeAreaInsets).width
        bannerView = BannerView(adSize: largeAnchoredAdaptiveBanner(width: safeWidth))
        #if DEBUG
        bannerView.adUnitID = "ca-app-pub-3940256099942544/2934735716"
        #else
        bannerView.adUnitID = "ca-app-pub-4626224236931889/5944146726"
        #endif
        bannerView.rootViewController = self
        bannerView.backgroundColor = .clear
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bannerView)

        // 105 = dashH(90) + bannerH/2(25) − bannerH/2(25) + 15 gap = bottom of placeholder slot
        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bannerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -105)
        ])

        bannerView.layer.borderWidth = 2
        bannerView.layer.borderColor = UIColor.clear.cgColor
        bannerView.alpha = 0
        bannerView.load(Request())

        NotificationCenter.default.addObserver(self, selector: #selector(updateBannerBorder),
                                               name: .uiThemeDidChange, object: nil)

        // Splash may have already fired if the consent form delayed ads setup past the 2s splash.
        if splashFinished {
            revealBanner()
        }
    }

    @objc private func updateBannerBorder() {
        let accent = SettingsManager.shared.palette.accentColor
        bannerView?.layer.borderColor = accent.withAlphaComponent(0.6).cgColor
    }

    @objc private func onSplashDidFinish() {
        splashFinished = true
        revealBanner()
    }

    private func revealBanner() {
        // Banner not set up yet (consent flow still running) — setupBanner() will
        // call revealBanner() itself once ready because splashFinished is already set.
        guard bannerView != nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
            guard let self, let banner = self.bannerView else { return }
            self.updateBannerBorder()
            UIView.animate(withDuration: 0.4) {
                banner.alpha = 1
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.window?.backgroundColor = .black
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}

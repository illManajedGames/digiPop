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
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !Self.screenshotMode, !consentFlowStarted else { return }
        consentFlowStarted = true

        // Present the UMP consent form if required (handles GDPR, CCPA, and the ATT prompt).
        // On completion — whether a form was shown or not — start ads if consent allows it.
        UMPConsentForm.loadAndPresentIfRequired(from: self) { [weak self] _ in
            if UMPConsentInformation.sharedInstance.canRequestAds {
                self?.startMobileAds()
            }
        }
        // Handle the case where consent was already given in a prior session.
        if UMPConsentInformation.sharedInstance.canRequestAds {
            startMobileAds()
        }
    }

    private func startMobileAds() {
        guard !bannerSetup else { return }
        bannerSetup = true
        MobileAds.shared.start()
        setupBanner()
    }

    private func setupBanner() {
        let safeWidth = view.frame.inset(by: view.safeAreaInsets).width
        bannerView = BannerView(adSize: largeAnchoredAdaptiveBanner(width: safeWidth))
        // TODO: replace with your production ad unit ID from AdMob console
        bannerView.adUnitID = "ca-app-pub-3940256099942544/2934735716"
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

        NotificationCenter.default.addObserver(self, selector: #selector(revealBanner),
                                               name: .splashDidFinish, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateBannerBorder),
                                               name: .uiThemeDidChange, object: nil)
    }

    @objc private func updateBannerBorder() {
        let accent = SettingsManager.shared.palette.accentColor
        bannerView?.layer.borderColor = accent.withAlphaComponent(0.6).cgColor
    }

    @objc private func revealBanner() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
            guard let self else { return }
            self.updateBannerBorder()
            UIView.animate(withDuration: 0.4) {
                self.bannerView.alpha = 1
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

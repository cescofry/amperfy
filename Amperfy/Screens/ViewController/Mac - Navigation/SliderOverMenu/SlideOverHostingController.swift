//
//  SlideOverHostingController.swift
//  Amperfy
//
//  Created by David Klopp on 29.08.24.
//  Copyright (c) 2024 Maximilian Bauer. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit
import AmperfyKit
import MediaPlayer

#if targetEnvironment(macCatalyst)

// A view controller with a primary view controller and a slide over view controller that can be displayed
// from the right hand side as an overlay.
class SlideOverHostingController: UIViewController {
    var sliderOverWidth: CGFloat = 300 {
        didSet(newValue) {
            self.slideOverWidthConstraint?.constant = newValue
            self.slideOverTrailingConstraint?.constant = newValue
        }
    }

    var _primaryViewController: UIViewController?

    var primaryViewController: UIViewController? {
        get { return self._primaryViewController }
        set(newValue) {
            self._primaryViewController?.view.removeFromSuperview()
            self._primaryViewController?.removeFromParent()
            self._primaryViewController?.didMove(toParent: nil)

            guard let vc = newValue else { return }

            self.addChild(vc)
            self.view.insertSubview(vc.view, at: 0)
            vc.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                vc.view.topAnchor.constraint(equalTo: self.view.topAnchor),
                vc.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                vc.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                vc.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
            ])
            vc.didMove(toParent: self)

            self._primaryViewController = vc
        }
    }

    let slideOverViewController: SlideOverVC

    private var slideOverWidthConstraint: NSLayoutConstraint?
    private var slideOverTrailingConstraint: NSLayoutConstraint?
    private var isPresentingSlideOver: Bool {
        self.slideOverTrailingConstraint?.constant == 0
    }

    init(slideOverViewController: SlideOverVC) {
        self.slideOverViewController = slideOverViewController
        super.init(nibName: nil, bundle: nil)

        // Add the slide over view controller
        self.addChild(slideOverViewController)
        self.view.addSubview(slideOverViewController.view)
        self.slideOverViewController.view.translatesAutoresizingMaskIntoConstraints = false

        let wc = self.slideOverViewController.view.widthAnchor.constraint(equalToConstant: self.sliderOverWidth)
        let tc = self.slideOverViewController.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: self.sliderOverWidth)

        NSLayoutConstraint.activate([
            self.slideOverViewController.view.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.slideOverViewController.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            wc,
            tc
        ])

        self.slideOverWidthConstraint = wc
        self.slideOverTrailingConstraint = tc

        self.slideOverViewController.didMove(toParent: self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.appDelegate.player.addNotifier(notifier: self)

        // Listen for setting changes to adjust the toolbar and slide over menu
        NotificationCenter.default.addObserver(self, selector: #selector(self.settingsDidChange), name: UserDefaults.didChangeNotification, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.setupToolbar()
    }
    
    private lazy var skipBackwardBarButton: UIBarButtonItem = {
        let player = appDelegate.player
        return SkipBackwardBarButton(player: player)
    }()
    private lazy var previousBarButton: UIBarButtonItem = {
        let player = appDelegate.player
        return PreviousBarButton(player: player)
    }()
    private lazy var nextBarButton: UIBarButtonItem = {
        let player = appDelegate.player
        return NextBarButton(player: player)
    }()
    private lazy var skipForwardBarButton: UIBarButtonItem = {
        let player = appDelegate.player
        return SkipForwardBarButton(player: player)
    }()
    private lazy var shuffleButton: UIBarButtonItem = {
        let player = appDelegate.player
        return ShuffleBarButton(player: player)
    }()
    private lazy var shufflePlaceholderButton: UIBarButtonItem = {
        return SpaceBarItem(fixedSpace: CustomBarButton.defaultSize.width)
    }()
    private lazy var repeatButton: UIBarButtonItem = {
        let player = appDelegate.player
        return RepeatBarButton(player: player)
    }()
    private lazy var repeatPlaceholderButton: UIBarButtonItem = {
        return SpaceBarItem(fixedSpace: CustomBarButton.defaultSize.width)
    }()

    private func setupToolbar() {
        guard let splitViewController = self.splitViewController as? SplitVC else { return }
        let player = appDelegate.player

        // Add the media player controls to the view's navigation item
        self.navigationItem.leftItemsSupplementBackButton = false
        let defaultSpacing: CGFloat = 10

        self.navigationItem.leftBarButtonItems = [
                SpaceBarItem(fixedSpace: defaultSpacing),
                self.shuffleButton,
                self.shufflePlaceholderButton,
                self.skipBackwardBarButton,
                self.previousBarButton,
                PlayBarButton(player: player),
                self.nextBarButton,
                self.skipForwardBarButton,
                self.repeatButton,
                self.repeatPlaceholderButton,
                SpaceBarItem(minSpace: defaultSpacing),
                NowPlayingBarItem(player: player, splitViewController: splitViewController),
                SpaceBarItem(),
                VolumeBarItem(player: player),
                SpaceBarItem(),
                AirplayBarButton(),
                QueueBarButton(splitViewController: splitViewController),
                SpaceBarItem(fixedSpace: defaultSpacing)
        ]

        self.updateButtonVisibility()
        self.navigationItem.leftBarButtonItems?.forEach { ($0 as? Refreshable)?.reload() }
    }

    private func updateButtonVisibility() {
        let isShuffleEnabled = appDelegate.storage.settings.isPlayerShuffleButtonEnabled &&
                              (appDelegate.player.playerMode == .music)
        let isRepeatEnabled = appDelegate.player.playerMode == .music

        if #available(macCatalyst 16.0, *) {
            // We can not remove toolbar items in `mac` style, therefore we hide them
            self.skipBackwardBarButton.isHidden = appDelegate.player.playerMode == .music
            self.previousBarButton.isHidden = appDelegate.player.playerMode == .podcast
            self.nextBarButton.isHidden = appDelegate.player.playerMode == .podcast
            self.skipForwardBarButton.isHidden = appDelegate.player.playerMode == .music
            
            self.shuffleButton.isHidden = !isShuffleEnabled
            self.shufflePlaceholderButton.isHidden = isShuffleEnabled
            self.repeatButton.isHidden = !isRepeatEnabled
            self.repeatPlaceholderButton.isHidden = isRepeatEnabled
        } else {
            // Below 16.0 there is no `mac` style and .isHidden is not available.
            if let index = self.navigationItem.leftBarButtonItems?.firstIndex(of: self.skipBackwardBarButton) {
                self.navigationItem.leftBarButtonItems?.remove(at: index)
            }
            if let index = self.navigationItem.leftBarButtonItems?.firstIndex(of: self.previousBarButton) {
                self.navigationItem.leftBarButtonItems?.remove(at: index)
            }
            if let index = self.navigationItem.leftBarButtonItems?.firstIndex(of: self.nextBarButton) {
                self.navigationItem.leftBarButtonItems?.remove(at: index)
            }
            if let index = self.navigationItem.leftBarButtonItems?.firstIndex(of: self.skipForwardBarButton) {
                self.navigationItem.leftBarButtonItems?.remove(at: index)
            }
            
            if let index = self.navigationItem.leftBarButtonItems?.firstIndex(of: self.shuffleButton) {
                self.navigationItem.leftBarButtonItems?.remove(at: index)
            }
            if let index = self.navigationItem.leftBarButtonItems?.firstIndex(of: self.shufflePlaceholderButton) {
                self.navigationItem.leftBarButtonItems?.remove(at: index)
            }
            if let index = self.navigationItem.leftBarButtonItems?.firstIndex(of: self.repeatButton) {
                self.navigationItem.leftBarButtonItems?.remove(at: index)
            }
            if let index = self.navigationItem.leftBarButtonItems?.firstIndex(of: self.repeatPlaceholderButton) {
                self.navigationItem.leftBarButtonItems?.remove(at: index)
            }
            
            if (isShuffleEnabled) {
                self.navigationItem.leftBarButtonItems?.insert(self.shuffleButton, at: 1)
            } else {
                self.navigationItem.leftBarButtonItems?.insert(self.shufflePlaceholderButton, at: 1)
            }
            
            switch appDelegate.player.playerMode {
            case .music:
                self.navigationItem.leftBarButtonItems?.insert(self.previousBarButton, at: 2)
                self.navigationItem.leftBarButtonItems?.insert(self.nextBarButton, at: 4)
            case .podcast:
                self.navigationItem.leftBarButtonItems?.insert(self.skipBackwardBarButton, at: 2)
                self.navigationItem.leftBarButtonItems?.insert(self.skipForwardBarButton, at: 4)
            }
            
            if (isRepeatEnabled) {
                self.navigationItem.leftBarButtonItems?.insert(self.repeatButton, at: 5)
            } else {
                self.navigationItem.leftBarButtonItems?.insert(self.repeatPlaceholderButton, at: 5)
            }
        }
    }

    @objc func settingsDidChange() {
        DispatchQueue.main.async {
            self.navigationItem.leftBarButtonItems?.forEach { ($0 as? Refreshable)?.reload() }
            self.updateButtonVisibility()
            self.slideOverViewController.settingsDidChange()
        }
    }

    func showSlideOverView() {
        self.slideOverTrailingConstraint?.constant = 0
        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
        }
    }

    func hideSlideOverView() {
        self.slideOverTrailingConstraint?.constant = self.sliderOverWidth
        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
        }
    }

    func toggleSlideOverView() {
        if self.isPresentingSlideOver {
            self.hideSlideOverView()
        } else {
            self.showSlideOverView()
        }
    }

    override func viewWillLayoutSubviews() {
        self.extendSafeAreaToAccountForTabbar()
        super.viewWillLayoutSubviews()
    }
}

extension SlideOverHostingController: MusicPlayable {
    func didStartPlayingFromBeginning() {}
    func didStartPlaying() {}
    func didLyricsTimeChange(time: CMTime) {}
    func didPause() {}
    func didStopPlaying() {}
    func didElapsedTimeChange() {}
    func didPlaylistChange() {
        settingsDidChange()
    }
    func didArtworkChange() {}
    func didShuffleChange() {}
    func didRepeatChange() {}
    func didPlaybackRateChange() {}
}

#endif

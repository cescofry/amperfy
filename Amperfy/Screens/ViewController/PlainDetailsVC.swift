//
//  PlainDetailsVC.swift
//  Amperfy
//
//  Created by Maximilian Bauer on 01.02.24.
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

import Foundation
import UIKit
import PromiseKit
import AmperfyKit
import MarqueeLabel

class PlainDetailsVC: UIViewController {
    
    override var sceneTitle: String? { podcast?.name }

    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var detailsTextView: UITextView!

    private var rootView: UIViewController?
    private var podcast: Podcast?
    private var podcastEpisode: PodcastEpisode?
    private var player: PlayerFacade?
    private var lyricsRelFilePath: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.setBackgroundBlur(style: .prominent)
        self.detailsTextView.textAlignment = .center

        if let presentationController = presentationController as? UISheetPresentationController {
            presentationController.detents = [
                .large()
            ]
            if traitCollection.horizontalSizeClass == .compact {
                presentationController.detents.append(.medium())
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        refresh()
    }

    func display(podcast: Podcast, on rootView: UIViewController) {
        self.rootView = rootView
        self.podcast = podcast
        self.podcastEpisode = nil
        self.player = nil
        self.lyricsRelFilePath = nil
    }
    func display(podcastEpisode: PodcastEpisode, on rootView: UIViewController) {
        self.rootView = rootView
        self.podcast = nil
        self.podcastEpisode = podcastEpisode
        self.player = nil
        self.lyricsRelFilePath = nil
    }
    func display(player: PlayerFacade, on rootView: UIViewController) {
        self.rootView = rootView
        self.podcast = nil
        self.podcastEpisode = nil
        self.player = player
        self.lyricsRelFilePath = nil
    }
    func display(lyricsRelFilePath: URL, on rootView: UIViewController) {
        self.rootView = rootView
        self.podcast = nil
        self.podcastEpisode = nil
        self.player = nil
        self.lyricsRelFilePath = lyricsRelFilePath
    }

    func refresh() {
        if let podcast = podcast {
            detailsTextView.text = podcast.depiction
            headerLabel.text = "Description"
        } else if let podcastEpisode = podcastEpisode {
            detailsTextView.text = podcastEpisode.depiction
            headerLabel.text = "Description"
        } else if let lyricsRelFilePath = lyricsRelFilePath {
            detailsTextView.text = ""
            headerLabel.text = "Lyrics"
            firstly {
                appDelegate.librarySyncer.parseLyrics(relFilePath: lyricsRelFilePath)
            }.done { lyricsList in
                self.displayLyrics(lyricsList: lyricsList)
            }.catch { error in
                self.detailsTextView.text = "Lyrics are not available anymore."
            }
        } else if let player = player {
            headerLabel.text = "Player Info"
            var details = ""
            details += "Play Time\n"
            details += "Remaining: \(player.remainingPlayDuration.asDurationString)\n"
            details += "Total: \(player.totalPlayDuration.asDurationString)\n"
            details += "\n"
            details += "\n"
            details += "Queue Items\n"
            details += "Previous: \(player.prevQueueCount)\n"
            details += "User: \(player.userQueueCount)\n"
            details += "Next: \(player.nextQueueCount)\n"
            detailsTextView.text = details
        }
    }
    
    private func displayLyrics(lyricsList: LyricsList) {
        guard let structuredLyrics = lyricsList.lyrics.object(at: 0) else { return }
        let lyricsLines = structuredLyrics.line.reduce("", { $0 == "" ? $1.value : $0 + "\n" + $1.value })
        self.detailsTextView.text = lyricsLines
    }
    
    @IBAction func pressedClose(_ sender: Any) {
        self.dismiss(animated: true)
    }

}

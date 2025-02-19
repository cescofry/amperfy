//
//  Album.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 31.12.19.
//  Copyright (c) 2019 Maximilian Bauer. All rights reserved.
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
import CoreData
import UIKit
import PromiseKit

public class Album: AbstractLibraryEntity {
    
    public let managedObject: AlbumMO
    
    public init(managedObject: AlbumMO) {
        self.managedObject = managedObject
        super.init(managedObject: managedObject)
    }
    override public func image(theme: ThemePreference, setting: ArtworkDisplayPreference) -> UIImage {
        return super.image(theme: theme, setting: setting)
    }
    private var embeddedArtworkImage: UIImage? {
        return songs.lazy.compactMap{ $0.embeddedArtwork }.first?.image
    }
    public var identifier: String {
        return name
    }
    public var name: String {
        get { return managedObject.name ?? "Unknown Album" }
        set {
            if managedObject.name != newValue {
                managedObject.name = newValue
                updateAlphabeticSectionInitial(section: newValue)
            }
        }
    }
    public var year: Int {
        get { return Int(managedObject.year) }
        set {
            guard Int16.isValid(value: newValue), managedObject.year != Int16(newValue) else { return }
            managedObject.year = Int16(newValue)
        }
    }
    public var duration: Int {
        get { return Int(managedObject.duration) }
    }
    public var remoteDuration: Int {
        get { return Int(managedObject.remoteDuration) }
        set {
            if Int16.isValid(value: newValue), managedObject.remoteDuration != Int16(newValue) {
                managedObject.remoteDuration = Int16(newValue)
            }
            updateDuration(updateArtistToo: true)
        }
    }
    public func updateDuration(updateArtistToo: Bool) {
        if isSongsMetaDataSynced {
            let playablesDuration = playables.reduce(0){ $0 + $1.duration }
            if Int16.isValid(value: playablesDuration), managedObject.duration != Int16(playablesDuration) {
                managedObject.duration = Int16(playablesDuration)
            }
        } else {
            if managedObject.duration != managedObject.remoteDuration {
                managedObject.duration = managedObject.remoteDuration
            }
        }
        if updateArtistToo {
            artist?.updateDuration()
        }
    }
    public var artist: Artist? {
        get {
            guard let artistMO = managedObject.artist else { return nil }
            return Artist(managedObject: artistMO)
        }
        set {
            if managedObject.artist != newValue?.managedObject { managedObject.artist = newValue?.managedObject }
        }
    }
    public var genre: Genre? {
        get {
            guard let genreMO = managedObject.genre else { return nil }
            return Genre(managedObject: genreMO) }
        set {
            if managedObject.genre != newValue?.managedObject { managedObject.genre = newValue?.managedObject }
        }
    }
    public var isSongsMetaDataSynced: Bool {
        get { return managedObject.isSongsMetaDataSynced }
        set { managedObject.isSongsMetaDataSynced = newValue }
    }
    public func updateIsNewestInfo(index: Int) {
        guard Int16.isValid(value: index), managedObject.newestIndex != index else { return }
        managedObject.newestIndex = Int16(index)
    }
    public func markAsNotNewAnymore() {
        managedObject.newestIndex = 0
    }
    public func updateIsRecentInfo(index: Int) {
        guard Int16.isValid(value: index), managedObject.recentIndex != index else { return }
        managedObject.recentIndex = Int16(index)
    }
    public func markAsNotRecentAnymore() {
        managedObject.recentIndex = 0
    }
    public var remoteSongCount: Int {
        get {
            return Int(managedObject.remoteSongCount)
        }
        set {
            guard Int16.isValid(value: newValue), managedObject.remoteSongCount != Int16(newValue) else { return }
            managedObject.remoteSongCount = Int16(newValue)
        }
    }
    public var songCount: Int {
        get {
            let moSongCount = Int(managedObject.songCount)
            let moRemoteSongCount = Int(managedObject.remoteSongCount)
            return moRemoteSongCount != 0 ? moRemoteSongCount : moSongCount
        }
    }
    public var songs: [AbstractPlayable] {
        guard let songsSet = managedObject.songs, let songsMO = songsSet.array as? [SongMO] else { return [Song]() }
        var returnSongs = [Song]()
        for songMO in songsMO {
            returnSongs.append(Song(managedObject: songMO))
        }
        return returnSongs.sortByTrackNumber()
    }
    public var playables: [AbstractPlayable] { return songs }
    
    public var isOrphaned: Bool {
        return identifier == "Unknown (Orphaned)"
    }
    override public func getDefaultImage(theme: ThemePreference) -> UIImage  {
        return UIImage.getGeneratedArtwork(theme: theme, artworkType: .album)
    }
    
    public func markAsRemoteDeleted() {
        self.remoteStatus = .deleted
        self.songs.forEach {
            $0.remoteStatus = .deleted
        }
    }

}

extension Album: PlayableContainable  {
    public var subtitle: String? { return artist?.name }
    public var subsubtitle: String? { return nil }
    public func infoDetails(for api: BackenApiType, details: DetailInfoType) -> [String] {
        var infoContent = [String]()
        if songCount == 1 {
            infoContent.append("1 Song")
        } else if songCount > 1 {
            infoContent.append("\(songCount) Songs")
        }
        if details.type == .short, details.isShowAlbumDuration, duration > 0 {
            infoContent.append("\(duration.asDurationShortString)")
        }
        if details.type == .long {
            if isCompletelyCached {
                infoContent.append("Cached")
            }
            if year > 0 {
                infoContent.append("Year \(year)")
            }
            if let genre = genre {
                infoContent.append("Genre: \(genre.name)")
            }
            if duration > 0 {
                infoContent.append("\(duration.asDurationShortString)")
            }
            if details.isShowDetailedInfo {
                infoContent.append("ID: \(!self.id.isEmpty ? self.id : "-")")
            }
        }
        return infoContent
    }
    public var playContextType: PlayerMode { return .music }
    public var isRateable: Bool { return true }
    public var isFavoritable: Bool { return true }
    public func remoteToggleFavorite(syncer: LibrarySyncer) -> Promise<Void> {
        guard let context = managedObject.managedObjectContext else { return Promise<Void>(error: BackendError.persistentSaveFailed) }
        isFavorite.toggle()
        let library = LibraryStorage(context: context)
        library.saveContext()
        return syncer.setFavorite(album: self, isFavorite: isFavorite)
    }
    public func fetchFromServer(storage: PersistentStorage, librarySyncer: LibrarySyncer, playableDownloadManager: DownloadManageable) -> Promise<Void> {
        return librarySyncer.sync(album: self)
    }
    public func getArtworkCollection(theme: ThemePreference) -> ArtworkCollection {
        return ArtworkCollection(defaultImage: getDefaultImage(theme: theme), singleImageEntity: self)
    }
    public var containerIdentifier: PlayableContainerIdentifier { return PlayableContainerIdentifier(type: .album, objectID: managedObject.objectID.uriRepresentation().absoluteString) }
}

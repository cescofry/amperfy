//
//  MusicFolderMO+CoreDataClass.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 27.05.21.
//  Copyright (c) 2021 Maximilian Bauer. All rights reserved.
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

@objc(MusicFolderMO)
public class MusicFolderMO: NSManagedObject {
    
    override public func willSave() {
        super.willSave()
        if hasChangedSongs {
            updateSongCount()
        }
        if hasChangedDirectories {
            updateDirectoryCount()
        }
    }

    fileprivate var hasChangedSongs: Bool {
        return changedValue(forKey: #keyPath(songs)) != nil
    }

    fileprivate func updateSongCount() {
        guard Int16(songs?.count ?? 0) != songCount else { return }
        songCount = Int16(songs?.count ?? 0)
    }

    fileprivate var hasChangedDirectories: Bool {
        return changedValue(forKey: #keyPath(directories)) != nil
    }

    fileprivate func updateDirectoryCount() {
        guard Int16(directories?.count ?? 0) != directoryCount else { return }
        directoryCount = Int16(directories?.count ?? 0)
    }
    
    static var idSortedFetchRequest: NSFetchRequest<MusicFolderMO> {
        let fetchRequest: NSFetchRequest<MusicFolderMO> = MusicFolderMO.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(MusicFolderMO.id), ascending: true)
        ]
        return fetchRequest
    }

    static func getSearchPredicate(searchText: String) -> NSPredicate {
        var predicate: NSPredicate = NSPredicate.alwaysTrue
        if searchText.count > 0 {
            predicate = NSPredicate(format: "%K contains[cd] %@", #keyPath(MusicFolderMO.name), searchText)
        }
        return predicate
    }
    
}

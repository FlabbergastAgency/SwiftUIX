//
// Copyright (c) Vatsal Manot
//

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

import Swift
import SwiftUI
import UIKit

extension UIHostingCollectionViewController {
    class Cache: NSObject, UICollectionViewDelegateFlowLayout {
        unowned let parent: UIHostingCollectionViewController
        
        private var cellIdentifierToContentSizeMap: [UICollectionViewCellType.Configuration.ID: CGSize] = [:]
        private var cellIdentifierToPreferencesMap: [UICollectionViewCellType.Configuration.ID: UICollectionViewCellType.Preferences] = [:]
        private var cellIdentifierToIndexPathMap: [UICollectionViewCellType.Configuration.ID: IndexPath] = [:]
        private var indexPathToContentSizeMap: [IndexPath: CGSize] = [:]
        private var indexPathToIdentifierMap: [IndexPath: UICollectionViewCellType.Configuration.ID] = [:]
        
        private var supplementaryViewIdentifierToContentSizeMap: [UICollectionViewSupplementaryViewType.Configuration.ID: CGSize] = [:]
        private var supplementaryViewIdentifierToIndexPathMap: [UICollectionViewSupplementaryViewType.Configuration.ID: IndexPath] = [:]
        private var indexPathToSupplementaryViewContentSizeMap: [IndexPath: CGSize] = [:]
        
        private var itemIdentifierHashToIndexPathMap: [Int: IndexPath] = [:]
        
        private let prototypeHeaderView = UICollectionViewSupplementaryViewType()
        private let prototypeCell = UICollectionViewCellType()
        private let prototypeFooterView = UICollectionViewSupplementaryViewType()
        
        init(parent: UIHostingCollectionViewController) {
            self.parent = parent
        }
        
        // MARK: - UICollectionViewDelegateFlowLayout -
        
        public func collectionView(
            _ collectionView: UICollectionView,
            layout collectionViewLayout: UICollectionViewLayout,
            sizeForItemAt indexPath: IndexPath
        ) -> CGSize {
            guard let dataSource = parent.dataSource, dataSource.contains(indexPath) else {
                return .init(width: 1.0, height: 1.0)
            }
            
            let section = parent._unsafelyUnwrappedSection(from: indexPath)
            let sectionIdentifier = parent.dataSourceConfiguration.identifierMap[section]
            let item = parent._unsafelyUnwrappedItem(at: indexPath)
            let itemIdentifier = parent.dataSourceConfiguration.identifierMap[item]
            let id = UICollectionViewCellType.Configuration.ID(item: itemIdentifier, section: sectionIdentifier)
            
            let indexPathBasedSize = indexPathToContentSizeMap[indexPath]
            let identifierBasedSize = cellIdentifierToContentSizeMap[id]
            
            if let size = identifierBasedSize, indexPathBasedSize == nil {
                indexPathToContentSizeMap[indexPath] = size
                return size
            } else if let size = indexPathBasedSize, size == identifierBasedSize {
                return size
            } else {
                invalidateCachedContentSize(forIndexPath: indexPath)
                
                return sizeForItem(
                    atIndexPath: indexPath,
                    withCellConfiguration: .init(
                        item: item,
                        section: section,
                        itemIdentifier: itemIdentifier,
                        sectionIdentifier: sectionIdentifier,
                        indexPath: indexPath,
                        makeContent: parent.viewProvider.rowContent,
                        maximumSize: parent.maximumCellSize
                    )
                )
            }
        }
        
        public func collectionView(
            _ collectionView: UICollectionView,
            layout collectionViewLayout: UICollectionViewLayout,
            referenceSizeForHeaderInSection section: Int
        ) -> CGSize {
            let indexPath = IndexPath(row: -1, section: section)
            
            guard let dataSource = parent.dataSource, dataSource.contains(indexPath) else {
                return .init(width: 1.0, height: 1.0)
            }
            
            let section = parent._unsafelyUnwrappedSection(from: indexPath)
            let sectionIdentifier = parent.dataSourceConfiguration.identifierMap[section]
            let id = UICollectionViewSupplementaryViewType.Configuration.ID(kind: UICollectionView.elementKindSectionHeader, item: nil, section: sectionIdentifier)
            
            if let size = supplementaryViewIdentifierToContentSizeMap[id] {
                return size
            } else {
                // invalidateCachedContentSize(forIndexPath: indexPath)
                
                return sizeForSupplementaryView(
                    atIndexPath: indexPath,
                    withConfiguration: .init(
                        kind: UICollectionView.elementKindSectionHeader,
                        item: nil,
                        section: section,
                        itemIdentifier: nil,
                        sectionIdentifier: sectionIdentifier,
                        indexPath: indexPath,
                        viewProvider: parent.viewProvider,
                        maximumSize: parent.maximumCellSize
                    )
                )
            }
        }
        
        public func collectionView(
            _ collectionView: UICollectionView,
            layout collectionViewLayout: UICollectionViewLayout,
            referenceSizeForFooterInSection section: Int
        ) -> CGSize {
            let indexPath = IndexPath(row: -1, section: section)
            
            let section = parent._unsafelyUnwrappedSection(from: .init(row: -1, section: section))
            let sectionIdentifier = parent.dataSourceConfiguration.identifierMap[section]
            
            let size = sizeForSupplementaryView(
                atIndexPath: indexPath,
                withConfiguration: .init(
                    kind: UICollectionView.elementKindSectionFooter,
                    item: nil,
                    section: section,
                    itemIdentifier: nil,
                    sectionIdentifier: sectionIdentifier,
                    indexPath: indexPath,
                    viewProvider: parent.viewProvider,
                    maximumSize: parent.maximumCellSize
                )
            )
            
            return size
        }
    }
}

extension UIHostingCollectionViewController.Cache {
    private func sizeForItem(
        atIndexPath indexPath: IndexPath,
        withCellConfiguration cellConfiguration: UIHostingCollectionViewController.UICollectionViewCellType.Configuration
    ) -> CGSize {
        prototypeCell.configuration = cellConfiguration
        prototypeCell.preferences = cellIdentifierToPreferencesMap[cellConfiguration.id] ?? .init()
        
        prototypeCell.cellWillDisplay(inParent: nil, isPrototype: true)
        
        let size = prototypeCell.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        
        guard !(size.width == 1 && size.height == 1) else {
            return size
        }
        
        cellIdentifierToContentSizeMap[cellConfiguration.id] = size
        cellIdentifierToIndexPathMap[cellConfiguration.id] = indexPath
        indexPathToContentSizeMap[cellConfiguration.indexPath] = size
        indexPathToIdentifierMap[cellConfiguration.indexPath] = .init(item: cellConfiguration.itemIdentifier, section: cellConfiguration.sectionIdentifier)
        itemIdentifierHashToIndexPathMap[cellConfiguration.itemIdentifier.hashValue] = indexPath
        
        return size
    }
    
    private func sizeForSupplementaryView(
        atIndexPath indexPath: IndexPath,
        withConfiguration configuration: UIHostingCollectionViewController.UICollectionViewSupplementaryViewType.Configuration
    ) -> CGSize {
        let prototypeView = configuration.kind == UICollectionView.elementKindSectionHeader ? prototypeHeaderView : prototypeFooterView
        
        prototypeView.configuration = configuration
        prototypeView.supplementaryViewWillDisplay(inParent: nil, isPrototype: true)
        
        let size = prototypeView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        
        guard !(size.width == 1 && size.height == 1) else {
            return size
        }
        
        supplementaryViewIdentifierToContentSizeMap[configuration.id] = size
        supplementaryViewIdentifierToIndexPathMap[configuration.id] = indexPath
        
        return size
    }
    
    func invalidateCachedContentSize(forIndexPath indexPath: IndexPath) {
        guard let id = indexPathToIdentifierMap[indexPath] else {
            return
        }
        
        cellIdentifierToContentSizeMap[id] = nil
        indexPathToContentSizeMap[indexPath] = nil
    }
    
    func invalidateIndexPath(_ indexPath: IndexPath) {
        invalidateCachedContentSize(forIndexPath: indexPath)
        
        guard let id = indexPathToIdentifierMap[indexPath] else {
            return
        }
        
        cellIdentifierToIndexPathMap[id] = nil
        indexPathToIdentifierMap[indexPath] = nil
        itemIdentifierHashToIndexPathMap[id.item.hashValue] = nil
    }
    
    func invalidate() {
        cellIdentifierToContentSizeMap = [:]
        indexPathToContentSizeMap = [:]
        cellIdentifierToIndexPathMap = [:]
        indexPathToIdentifierMap = [:]
    }
    
    func firstIndexPath(for identifier: AnyHashable) -> IndexPath? {
        if let indexPath = itemIdentifierHashToIndexPathMap[identifier.hashValue] {
            return indexPath
        } else {
            return nil
        }
    }
    
    func identifier(for indexPath: IndexPath) -> UIHostingCollectionViewController.UICollectionViewCellType.Configuration.ID? {
        indexPathToIdentifierMap[indexPath]
    }
    
    subscript(preferencesFor id: UIHostingCollectionViewController.UICollectionViewCellType.Configuration.ID) -> UIHostingCollectionViewController.UICollectionViewCellType.Preferences? {
        get {
            cellIdentifierToPreferencesMap[id]
        } set {
            let oldValue = self[preferencesFor: id]
            
            cellIdentifierToPreferencesMap[id] = newValue
            
            guard let indexPath = cellIdentifierToIndexPathMap[id] else {
                return
            }
            
            if oldValue?.relativeFrame != newValue?.relativeFrame {
                parent.cache.invalidateIndexPath(indexPath)
                parent.invalidateLayout(includingCache: false)
            }
        }
    }
}

#endif

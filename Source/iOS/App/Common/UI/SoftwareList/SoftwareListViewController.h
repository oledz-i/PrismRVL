// Copyright 2022 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

#import <UIKit/UIKit.h>

namespace DiscIO {
enum class Region;
}

@class EmulationBootParameter;
@class GameFilePtrWrapper;

NS_ASSUME_NONNULL_BEGIN

@interface SoftwareListViewController : UICollectionViewController<UICollectionViewDelegateFlowLayout> {
  NSArray<GameFilePtrWrapper*>* _gameFiles;
  GameFilePtrWrapper* _selectedFile;
  EmulationBootParameter* _bootParameter;
}

- (void)reloadGameFiles;
- (void)loadGameFile:(GameFilePtrWrapper*)gameFileWrapper;
- (void)loadGameCubeIPLForRegion:(DiscIO::Region)region;

- (void)performSegueForWiiUpdateWithSource:(NSString*)source isOnline:(bool)online;

/// Number of tile columns for the current width.
- (NSInteger)prismColumnCount;

/// Called when the "Add Game" slot is tapped. Subclasses present an import picker.
- (void)prismAddSlotSelected;

/// The game shown at an index path, or nil for the add and empty slots.
- (nullable GameFilePtrWrapper*)prismGameAtIndexPath:(NSIndexPath*)indexPath;

@end

NS_ASSUME_NONNULL_END

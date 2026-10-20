// Copyright 2022 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

#import "SoftwareListViewController.h"

#import "EmulationBootParameter.h"
#import "EmulationViewController.h"
#import "FoundationStringUtil.h"
#import "GameFileCacheManager.h"
#import "GameFilePtrWrapper.h"
#import "SoftwarePropertiesViewController.h"
#import "PrismInterop.h"
#import "Swift.h"
#import "WiiSystemUpdateViewController.h"

#import "UICommon/GameFile.h"

static NSString* const PrismChannelReuseIdentifier = @"prismChannel";

// Wii and GameCube banners are 32-bit ARGB in native byte order, the same layout Dolphin Qt reads.
static UIImage* PrismImageFromBanner(const UICommon::GameBanner& banner) {
  if (banner.empty() || banner.width == 0 || banner.height == 0) {
    return nil;
  }

  const size_t width = banner.width;
  const size_t height = banner.height;

  if (banner.buffer.size() < width * height) {
    return nil;
  }

  NSData* data = [NSData dataWithBytes:banner.buffer.data() length:width * height * sizeof(u32)];
  CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

  const CGBitmapInfo info = (CGBitmapInfo)kCGBitmapByteOrder32Little | (CGBitmapInfo)kCGImageAlphaFirst;
  CGImageRef cgImage = CGImageCreate(width, height, 8, 32, width * 4, colorSpace, info, provider, NULL,
                                     false, kCGRenderingIntentDefault);

  CGColorSpaceRelease(colorSpace);
  CGDataProviderRelease(provider);

  if (cgImage == NULL) {
    return nil;
  }

  UIImage* image = [UIImage imageWithCGImage:cgImage];
  CGImageRelease(cgImage);

  return image;
}

static NSString* PrismPlatformName(DiscIO::Platform platform) {
  switch (platform) {
    case DiscIO::Platform::GameCubeDisc:
    case DiscIO::Platform::Triforce:
      return @"GameCube";
    case DiscIO::Platform::WiiDisc:
      return @"Wii";
    case DiscIO::Platform::WiiWAD:
      return @"WiiWare";
    case DiscIO::Platform::ELFOrDOL:
      return @"Homebrew";
    default:
      return @"Game";
  }
}

static NSString* PrismPlatformSymbol(DiscIO::Platform platform) {
  switch (platform) {
    case DiscIO::Platform::GameCubeDisc:
    case DiscIO::Platform::Triforce:
      return @"cube.fill";
    case DiscIO::Platform::WiiDisc:
      return @"opticaldisc";
    case DiscIO::Platform::WiiWAD:
      return @"square.stack.3d.up.fill";
    case DiscIO::Platform::ELFOrDOL:
      return @"hammer.fill";
    default:
      return @"gamecontroller.fill";
  }
}

@interface SoftwareListViewController ()

@end

@implementation SoftwareListViewController {
  NSString* _wiiUpdateSource;
  bool _wiiUpdateIsOnline;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  [self.collectionView registerClass:PrismChannelCellClass() forCellWithReuseIdentifier:PrismChannelReuseIdentifier];
  
  self->_gameFiles = [[GameFileCacheManager sharedManager] getGames];
}

- (NSInteger)prismColumnCount {
  UIEdgeInsets safe = self.collectionView.safeAreaInsets;
  CGFloat width = self.collectionView.bounds.size.width - safe.left - safe.right;
  
  return [PrismHomeMetricsClass() columnsForWidth:width];
}

- (void)prismAddSlotSelected {
  // Overridden by the platform subclass.
}

- (nullable GameFilePtrWrapper*)prismGameAtIndexPath:(NSIndexPath*)indexPath {
  if (indexPath.item < 0 || indexPath.item >= (NSInteger)self->_gameFiles.count) {
    return nil;
  }
  
  return [self->_gameFiles objectAtIndex:indexPath.item];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  
  [self reloadGameFiles];
}

- (void)reloadGameFiles {
  [[GameFileCacheManager sharedManager] rescanAndFetchMetadataWithCompletionHandler:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      self->_gameFiles = [[GameFileCacheManager sharedManager] getGames];
      [self.collectionView reloadData];
    });
  }];
}

- (void)loadGameFile:(GameFilePtrWrapper*)gameFileWrapper {
  std::shared_ptr<const UICommon::GameFile> game = gameFileWrapper.gameFile;
  
  std::shared_ptr<const UICommon::GameFile> second_game = nullptr;
  std::shared_ptr<const UICommon::GameFile> match_without_revision = nullptr;
  
  if (DiscIO::IsDisc(game->GetPlatform())) {
    for (GameFilePtrWrapper* otherWrapper in self->_gameFiles) {
      std::shared_ptr<const UICommon::GameFile> other_game = otherWrapper.gameFile;
      
      if (game->GetGameID() == other_game->GetGameID() &&
          game->GetDiscNumber() != other_game->GetDiscNumber()) {
        if (game->GetRevision() == other_game->GetRevision()) {
          second_game = other_game;
          break;
        } else {
          match_without_revision = other_game;
        }
      }
    }
  }
  
  if (second_game == nullptr) {
    second_game = match_without_revision;
  }
  
  _bootParameter = [[EmulationBootParameter alloc] init];
  _bootParameter.bootType = EmulationBootTypeFile;
  _bootParameter.path = CppToFoundationString(game->GetFilePath());
  _bootParameter.secondPath = second_game != nullptr ? CppToFoundationString(second_game->GetFilePath()) : nil;
  _bootParameter.isNKit = gameFileWrapper.gameFile->IsNKit();
  
  [self performSegueWithIdentifier:@"emulation" sender:nil];
}

- (void)loadGameCubeIPLForRegion:(DiscIO::Region)region {
  _bootParameter = [[EmulationBootParameter alloc] init];
  _bootParameter.bootType = EmulationBootTypeGCIPL;
  _bootParameter.iplRegion = region;
  
  [self performSegueWithIdentifier:@"emulation" sender:nil];
}

#pragma mark <UICollectionViewDataSource>

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView*)collectionView {
  return 1;
}

- (NSInteger)collectionView:(UICollectionView*)collectionView numberOfItemsInSection:(NSInteger)section {
  return [PrismHomeMetricsClass() slotCountForGameCount:(NSInteger)self->_gameFiles.count columns:[self prismColumnCount]];
}

- (UICollectionViewCell*)collectionView:(UICollectionView*)collectionView cellForItemAtIndexPath:(NSIndexPath*)indexPath {
  UICollectionViewCell<PrismChannelCellMethods>* cell = (UICollectionViewCell<PrismChannelCellMethods>*)[collectionView dequeueReusableCellWithReuseIdentifier:PrismChannelReuseIdentifier forIndexPath:indexPath];
  
  GameFilePtrWrapper* gameFileWrapper = [self prismGameAtIndexPath:indexPath];
  
  if (gameFileWrapper == nil) {
    if (indexPath.item == (NSInteger)self->_gameFiles.count) {
      [cell configureAddSlot];
    } else {
      [cell configureEmptySlot];
    }
    
    return cell;
  }
  
  const auto& game = gameFileWrapper.gameFile;
  
  NSString* gameName = CppToFoundationString(game->GetName(UICommon::GameFile::Variant::LongAndPossiblyCustom));
  
  UIImage* image = nil;
  
  const UICommon::GameCover& cover = game->GetCoverImage();
  if (!cover.buffer.empty()) {
    NSData* data = [NSData dataWithBytes:cover.buffer.data() length:cover.buffer.size()];
    image = [UIImage imageWithData:data];
  }
  
  if (image == nil) {
    image = PrismImageFromBanner(game->GetBannerImage());
  }
  
  [cell configureGameWithTitle:gameName
                         image:image
                      platform:PrismPlatformName(game->GetPlatform())
                        symbol:PrismPlatformSymbol(game->GetPlatform())];
  
  return cell;
}

- (BOOL)collectionView:(UICollectionView*)collectionView shouldHighlightItemAtIndexPath:(NSIndexPath*)indexPath {
  return indexPath.item <= (NSInteger)self->_gameFiles.count;
}

- (void)collectionView:(UICollectionView*)collectionView didSelectItemAtIndexPath:(NSIndexPath*)indexPath {
  GameFilePtrWrapper* gameFileWrapper = [self prismGameAtIndexPath:indexPath];
  
  if (gameFileWrapper != nil) {
    [PrismAmbienceShared() playSelect];
    [self loadGameFile:gameFileWrapper];
  } else if (indexPath.item == (NSInteger)self->_gameFiles.count) {
    [PrismAmbienceShared() playSelect];
    [self prismAddSlotSelected];
  }
}

#pragma mark <UICollectionViewDelegateFlowLayout>

- (CGSize)collectionView:(UICollectionView*)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath*)indexPath {
  UIEdgeInsets safe = collectionView.safeAreaInsets;
  CGFloat width = collectionView.bounds.size.width - safe.left - safe.right;
  
  return [PrismHomeMetricsClass() itemSizeForWidth:width columns:[self prismColumnCount]];
}

- (UIEdgeInsets)collectionView:(UICollectionView*)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
  UIEdgeInsets safe = collectionView.safeAreaInsets;
  const CGFloat margin = [PrismHomeMetricsClass() margin];
  
  return UIEdgeInsetsMake(0, margin + safe.left, 0, margin + safe.right);
}

- (CGFloat)collectionView:(UICollectionView*)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
  return [PrismHomeMetricsClass() spacing];
}

- (CGFloat)collectionView:(UICollectionView*)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
  // Slightly under the real gap so rounding never pushes a tile onto the next row.
  return [PrismHomeMetricsClass() spacing] - 1;
}

#pragma mark Segue

- (void)performSegueForWiiUpdateWithSource:(NSString*)source isOnline:(bool)online {
  _wiiUpdateSource = source;
  _wiiUpdateIsOnline = online;
  
  [self performSegueWithIdentifier:@"wiiUpdate" sender:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue*)segue sender:(id)sender
{
  if ([segue.identifier isEqualToString:@"emulation"]) {
    UINavigationController* navigationController = segue.destinationViewController;
    EmulationViewController* viewController = navigationController.viewControllers[0];
    
    viewController.bootParameter = _bootParameter;
  } else if ([segue.identifier isEqualToString:@"wiiUpdate"]) {
    WiiSystemUpdateViewController* updateController = segue.destinationViewController;
    
    updateController.updateSource = _wiiUpdateSource;
    updateController.isOnlineUpdate = _wiiUpdateIsOnline;
  } else if ([segue.identifier isEqualToString:@"properties"]) {
    UINavigationController* navigationController = segue.destinationViewController;
    SoftwarePropertiesViewController* propertiesController = navigationController.viewControllers[0];
    
    propertiesController.gameFileWrapper = _selectedFile;
  }
}

@end

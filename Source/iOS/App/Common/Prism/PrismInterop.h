// Copyright 2026 PrismRVL Project
// SPDX-License-Identifier: GPL-2.0-or-later

// Objective-C(++) view of the PrismRVL Swift classes.
//
// The Swift classes pin their runtime names with @objc(Name), so Objective-C++ code can look
// them up with NSClassFromString and message them through these protocols. That keeps the
// Objective-C++ side independent of what the generated Swift header chooses to expose.

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol PrismHomeMetricsMethods <NSObject>
+ (NSInteger)columnsForWidth:(CGFloat)width;
+ (NSInteger)slotCountForGameCount:(NSInteger)gameCount columns:(NSInteger)columns;
+ (CGSize)itemSizeForWidth:(CGFloat)width columns:(NSInteger)columns;
+ (CGFloat)margin;
+ (CGFloat)spacing;
+ (CGFloat)dockHeight;
@end

@protocol PrismChannelCellMethods <NSObject>
- (void)configureGameWithTitle:(NSString*)title
                         image:(nullable UIImage*)image
                      platform:(NSString*)platform
                        symbol:(NSString*)symbol;
- (void)configureAddSlot;
- (void)configureEmptySlot;
@end

@protocol PrismBackgroundMethods <NSObject>
- (void)applyTheme;
@end

@protocol PrismDockMethods <NSObject>
@property (nonatomic, copy, nullable) void (^onSettings)(void);
- (void)setLibraryMenu:(UIMenu*)menu;
- (void)startClock;
- (void)stopClock;
- (void)applyTheme;
@end

@protocol PrismAmbienceMethods <NSObject>
- (void)playSelect;
- (void)playBack;
- (void)homeDidAppear;
- (void)homeWillDisappear;
@end

@protocol PrismThemeManagerMethods <NSObject>
- (void)applyToApp;
@end

@protocol PrismSharedInstance <NSObject>
+ (id)shared;
@end

@protocol PrismSettingsFactory <NSObject>
+ (UINavigationController*)makeNavigationController;
@end

static inline Class<PrismHomeMetricsMethods> PrismHomeMetricsClass(void) {
  return (Class<PrismHomeMetricsMethods>)NSClassFromString(@"PrismHomeMetrics");
}

static inline Class PrismChannelCellClass(void) {
  return NSClassFromString(@"PrismChannelCell");
}

static inline UIView<PrismBackgroundMethods>* PrismMakeHomeBackground(CGRect frame) {
  return (UIView<PrismBackgroundMethods>*)[[NSClassFromString(@"PrismHomeBackgroundView") alloc] initWithFrame:frame];
}

static inline UIView<PrismDockMethods>* PrismMakeDock(void) {
  return (UIView<PrismDockMethods>*)[[NSClassFromString(@"PrismDockView") alloc] initWithFrame:CGRectZero];
}

static inline id<PrismAmbienceMethods> PrismAmbienceShared(void) {
  Class<PrismSharedInstance> type = (Class<PrismSharedInstance>)NSClassFromString(@"PrismAmbience");
  return (id<PrismAmbienceMethods>)[type shared];
}

static inline id<PrismThemeManagerMethods> PrismThemeManagerShared(void) {
  Class<PrismSharedInstance> type = (Class<PrismSharedInstance>)NSClassFromString(@"PrismThemeManager");
  return (id<PrismThemeManagerMethods>)[type shared];
}

static inline UINavigationController* PrismMakeSettingsController(void) {
  Class<PrismSettingsFactory> factory = (Class<PrismSettingsFactory>)NSClassFromString(@"PrismSettingsViewController");
  return [factory makeNavigationController];
}

NS_ASSUME_NONNULL_END

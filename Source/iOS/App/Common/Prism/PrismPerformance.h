// Copyright 2026 PrismRVL Project
// SPDX-License-Identifier: GPL-2.0-or-later

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PrismPerformancePreset) {
  /// Your own graphics settings, untouched.
  PrismPerformancePresetQuality NS_SWIFT_NAME(quality) = 0,
  /// Stutter-free shader compilation and fast EFB paths. Default.
  PrismPerformancePresetBalanced NS_SWIFT_NAME(balanced) = 1,
  /// Balanced plus native resolution and the cheapest accuracy trade-offs.
  PrismPerformancePresetPerformance NS_SWIFT_NAME(performance) = 2,
};

/// Slows the emulated CPU when JIT is unavailable. Most games tolerate a modest underclock,
/// and the interpreter is almost always the bottleneck without JIT.
typedef NS_ENUM(NSInteger, PrismNoJitUnderclock) {
  PrismNoJitUnderclockOff NS_SWIFT_NAME(off) = 0,
  PrismNoJitUnderclock90 NS_SWIFT_NAME(light) = 1,
  PrismNoJitUnderclock80 NS_SWIFT_NAME(medium) = 2,
  PrismNoJitUnderclock70 NS_SWIFT_NAME(strong) = 3,
};

@interface PrismPerformance : NSObject

@property (class, nonatomic) PrismPerformancePreset preset;
@property (class, nonatomic) PrismNoJitUnderclock noJitUnderclock;
@property (class, nonatomic) BOOL showPerformanceOverlay;

+ (NSString*)nameForPreset:(PrismPerformancePreset)preset NS_SWIFT_NAME(presetName(_:));
+ (NSString*)detailForPreset:(PrismPerformancePreset)preset NS_SWIFT_NAME(presetDetail(_:));
+ (NSString*)nameForUnderclock:(PrismNoJitUnderclock)underclock NS_SWIFT_NAME(underclockName(_:));

/// Called right before the core boots. Writes the preset into a config layer that sits
/// above your own settings but below per-game fixes, so game INIs still win.
+ (void)applyForBootWithJit:(BOOL)jitAvailable NS_SWIFT_NAME(applyForBoot(jitAvailable:));

/// Removes the preset layer values once a game has stopped, so the settings screens show your
/// own values again.
+ (void)clearAfterEmulation NS_SWIFT_NAME(clearAfterEmulation());

@end

NS_ASSUME_NONNULL_END

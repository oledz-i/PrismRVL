// Copyright 2026 PrismRVL Project
// SPDX-License-Identifier: GPL-2.0-or-later

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// How the emulated Wii Remote on port 1 is held, and what is plugged into it.
typedef NS_ENUM(NSInteger, PrismWiiStyle) {
  PrismWiiStyleVertical NS_SWIFT_NAME(vertical) = 0,
  PrismWiiStyleSideways NS_SWIFT_NAME(sideways) = 1,
  PrismWiiStyleNunchuk NS_SWIFT_NAME(nunchuk) = 2,
  PrismWiiStyleMotionPlus NS_SWIFT_NAME(motionPlus) = 3,
  PrismWiiStyleNunchukMotionPlus NS_SWIFT_NAME(nunchukMotionPlus) = 4,
  PrismWiiStyleClassic NS_SWIFT_NAME(classic) = 5,
};

/// Where the inputs for a port come from.
typedef NS_ENUM(NSInteger, PrismInputSource) {
  PrismInputSourceTouchscreen NS_SWIFT_NAME(touchscreen) = 0,
  PrismInputSourcePhysicalController NS_SWIFT_NAME(physicalController) = 1,
  PrismInputSourceOther NS_SWIFT_NAME(other) = 2,
};

@interface PrismInput : NSObject

@property (class, nonatomic, readonly) NSArray<NSNumber*>* allWiiStyles;

+ (NSString*)nameForWiiStyle:(PrismWiiStyle)style NS_SWIFT_NAME(name(for:));
+ (NSString*)detailForWiiStyle:(PrismWiiStyle)style NS_SWIFT_NAME(detail(for:));
+ (NSString*)symbolForWiiStyle:(PrismWiiStyle)style NS_SWIFT_NAME(symbolName(for:));

/// Reads the configuration of the emulated Wii Remote on port 1.
+ (PrismWiiStyle)currentWiiStyle NS_SWIFT_NAME(currentWiiStyle());

/// Applies a style to Wii Remote 1 and saves WiimoteNew.ini. Safe to call while a game runs.
+ (void)applyWiiStyle:(PrismWiiStyle)style NS_SWIFT_NAME(apply(_:));

@property (class, nonatomic) BOOL uprightWiiRemote;

@property (class, nonatomic) PrismInputSource wiiInputSource;
@property (class, nonatomic) PrismInputSource gameCubeInputSource;

/// Identifier of the running game, or nil when nothing is running.
+ (nullable NSString*)currentGameID NS_SWIFT_NAME(currentGameID());
+ (nullable NSString*)currentGameName NS_SWIFT_NAME(currentGameName());

+ (void)rememberStyle:(PrismWiiStyle)style
            forGameID:(NSString*)gameID NS_SWIFT_NAME(remember(_:forGameID:));
+ (void)forgetStyleForGameID:(NSString*)gameID NS_SWIFT_NAME(forgetStyle(forGameID:));
+ (nullable NSNumber*)rememberedStyleForGameID:(NSString*)gameID
    NS_SWIFT_NAME(rememberedStyle(forGameID:));

/// Number of games with a remembered style.
+ (NSInteger)rememberedStyleCount NS_SWIFT_NAME(rememberedStyleCount());
+ (void)forgetAllRememberedStyles NS_SWIFT_NAME(forgetAllRememberedStyles());

/// If the running game has a remembered style, applies it. Returns YES when something changed.
+ (BOOL)applyRememberedStyleForCurrentGame NS_SWIFT_NAME(applyRememberedStyleForCurrentGame());

@end

NS_ASSUME_NONNULL_END

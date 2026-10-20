// Copyright 2026 PrismRVL Project
// SPDX-License-Identifier: GPL-2.0-or-later

#import "PrismInput.h"

#import <cstring>
#import <string>

#import "Common/Config/Config.h"
#import "Common/IniFile.h"

#import "Core/Config/MainSettings.h"
#import "Core/Config/WiimoteSettings.h"
#import "Core/ConfigManager.h"
#import "Core/Core.h"
#import "Core/HW/GCPad.h"
#import "Core/HW/SI/SI_Device.h"
#import "Core/HW/Wiimote.h"
#import "Core/HW/WiimoteEmu/ExtensionPort.h"
#import "Core/HW/WiimoteEmu/WiimoteEmu.h"
#import "Core/System.h"

#import "InputCommon/ControllerEmu/ControlGroup/Attachments.h"
#import "InputCommon/ControllerEmu/ControlGroup/ControlGroup.h"
#import "InputCommon/ControllerEmu/ControllerEmu.h"
#import "InputCommon/ControllerEmu/Setting/NumericSetting.h"
#import "InputCommon/ControllerInterface/ControllerInterface.h"
#import "InputCommon/InputConfig.h"

static NSString* const PrismRememberedStylesKey = @"prism_wii_style_per_game";

static constexpr const char* PrismTouchscreenProfile = "Touchscreen.ini";
static constexpr const char* PrismPhysicalProfile = "Physical Controller.ini";

namespace
{
WiimoteEmu::Wiimote* PrimaryWiimote()
{
  return static_cast<WiimoteEmu::Wiimote*>(Wiimote::GetConfig()->GetController(0));
}

ControllerEmu::NumericSetting<bool>* FindBoolSetting(ControllerEmu::ControlGroup* group,
                                                     const char* ini_name)
{
  if (group == nullptr)
    return nullptr;

  for (auto& setting : group->numeric_settings)
  {
    if (setting->GetType() == ControllerEmu::SettingType::Bool &&
        std::strcmp(setting->GetININame(), ini_name) == 0)
    {
      return static_cast<ControllerEmu::NumericSetting<bool>*>(setting.get());
    }
  }

  return nullptr;
}

bool GetBool(ControllerEmu::ControlGroup* group, const char* ini_name)
{
  auto* setting = FindBoolSetting(group, ini_name);
  return setting != nullptr && setting->GetValue();
}

void SetBool(ControllerEmu::ControlGroup* group, const char* ini_name, bool value)
{
  if (auto* setting = FindBoolSetting(group, ini_name))
    setting->SetValue(value);
}

PrismInputSource SourceForController(ControllerEmu::EmulatedController* controller)
{
  const std::string source = controller->GetDefaultDevice().source;

  if (source == "iOS")
    return PrismInputSourceTouchscreen;

  if (source == "MFi")
    return PrismInputSourcePhysicalController;

  return PrismInputSourceOther;
}

void LoadBuiltInProfile(InputConfig* config, const char* file_name)
{
  ControllerEmu::EmulatedController* controller = config->GetController(0);

  Common::IniFile ini_file;
  if (!ini_file.Load(config->GetSysProfileDirectoryPath() + file_name))
    return;

  const auto lock = ControllerEmu::EmulatedController::GetStateLock();
  controller->LoadConfig(ini_file.GetOrCreateSection("Profile"));
  controller->UpdateReferences(g_controller_interface);
}
}  // namespace

@implementation PrismInput

+ (NSArray<NSNumber*>*)allWiiStyles {
  return @[
    @(PrismWiiStyleVertical), @(PrismWiiStyleSideways), @(PrismWiiStyleNunchuk),
    @(PrismWiiStyleMotionPlus), @(PrismWiiStyleNunchukMotionPlus), @(PrismWiiStyleClassic)
  ];
}

+ (NSString*)nameForWiiStyle:(PrismWiiStyle)style {
  switch (style) {
    case PrismWiiStyleVertical:
      return @"Wii Remote (Vertical)";
    case PrismWiiStyleSideways:
      return @"Wii Remote (Sideways)";
    case PrismWiiStyleNunchuk:
      return @"Wii Remote + Nunchuk";
    case PrismWiiStyleMotionPlus:
      return @"Wii Remote + MotionPlus";
    case PrismWiiStyleNunchukMotionPlus:
      return @"Wii Remote + Nunchuk + MotionPlus";
    case PrismWiiStyleClassic:
      return @"Classic Controller";
  }

  return @"Wii Remote";
}

+ (NSString*)detailForWiiStyle:(PrismWiiStyle)style {
  switch (style) {
    case PrismWiiStyleVertical:
      return @"Pointed at the screen. Menus, shooters, most Wii titles.";
    case PrismWiiStyleSideways:
      return @"Held like an NES pad. Mario Kart, NSMB, Virtual Console.";
    case PrismWiiStyleNunchuk:
      return @"Analog stick plus C and Z. Zelda, Metroid, Mario Galaxy.";
    case PrismWiiStyleMotionPlus:
      return @"1:1 gyro aiming with your device. Wii Sports Resort.";
    case PrismWiiStyleNunchukMotionPlus:
      return @"Nunchuk with gyro. Skyward Sword and Red Steel 2.";
    case PrismWiiStyleClassic:
      return @"Two sticks, ZL and ZR. Xenoblade, Smash, Virtual Console.";
  }

  return @"";
}

+ (NSString*)symbolForWiiStyle:(PrismWiiStyle)style {
  switch (style) {
    case PrismWiiStyleVertical:
      return @"hand.point.up.left";
    case PrismWiiStyleSideways:
      return @"rectangle.landscape.rotate";
    case PrismWiiStyleNunchuk:
      return @"circle.grid.cross";
    case PrismWiiStyleMotionPlus:
      return @"gyroscope";
    case PrismWiiStyleNunchukMotionPlus:
      return @"move.3d";
    case PrismWiiStyleClassic:
      return @"gamecontroller";
  }

  return @"gamecontroller";
}

+ (PrismWiiStyle)currentWiiStyle {
  WiimoteEmu::Wiimote* wiimote = PrimaryWiimote();

  const auto* attachments = static_cast<ControllerEmu::Attachments*>(
      Wiimote::GetWiimoteGroup(0, WiimoteEmu::WiimoteGroup::Attachments));
  const u32 extension = attachments->GetSelectedAttachment();
  const bool motion_plus = wiimote->GetMotionPlusSetting().GetValue();

  if (extension == WiimoteEmu::ExtensionNumber::CLASSIC)
    return PrismWiiStyleClassic;

  if (extension == WiimoteEmu::ExtensionNumber::NUNCHUK)
    return motion_plus ? PrismWiiStyleNunchukMotionPlus : PrismWiiStyleNunchuk;

  if (motion_plus)
    return PrismWiiStyleMotionPlus;

  const bool sideways =
      GetBool(Wiimote::GetWiimoteGroup(0, WiimoteEmu::WiimoteGroup::Options),
              WiimoteEmu::Wiimote::SIDEWAYS_OPTION);

  return sideways ? PrismWiiStyleSideways : PrismWiiStyleVertical;
}

+ (void)applyWiiStyle:(PrismWiiStyle)style {
  if (Config::Get(Config::GetInfoForWiimoteSource(0)) == WiimoteSource::None) {
    Config::SetBaseOrCurrent(Config::GetInfoForWiimoteSource(0), WiimoteSource::Emulated);
  }

  u32 extension = WiimoteEmu::ExtensionNumber::NONE;
  bool motion_plus = false;
  bool sideways = false;

  switch (style) {
    case PrismWiiStyleVertical:
      break;
    case PrismWiiStyleSideways:
      sideways = true;
      break;
    case PrismWiiStyleNunchuk:
      extension = WiimoteEmu::ExtensionNumber::NUNCHUK;
      break;
    case PrismWiiStyleMotionPlus:
      motion_plus = true;
      break;
    case PrismWiiStyleNunchukMotionPlus:
      extension = WiimoteEmu::ExtensionNumber::NUNCHUK;
      motion_plus = true;
      break;
    case PrismWiiStyleClassic:
      extension = WiimoteEmu::ExtensionNumber::CLASSIC;
      break;
  }

  {
    const auto lock = ControllerEmu::EmulatedController::GetStateLock();

    auto* attachments = static_cast<ControllerEmu::Attachments*>(
        Wiimote::GetWiimoteGroup(0, WiimoteEmu::WiimoteGroup::Attachments));
    attachments->SetSelectedAttachment(extension);

    PrimaryWiimote()->GetMotionPlusSetting().SetValue(motion_plus);

    ControllerEmu::ControlGroup* options =
        Wiimote::GetWiimoteGroup(0, WiimoteEmu::WiimoteGroup::Options);
    SetBool(options, WiimoteEmu::Wiimote::SIDEWAYS_OPTION, sideways);
  }

  Wiimote::GetConfig()->SaveConfig();
}

+ (BOOL)uprightWiiRemote {
  return GetBool(Wiimote::GetWiimoteGroup(0, WiimoteEmu::WiimoteGroup::Options),
                 WiimoteEmu::Wiimote::UPRIGHT_OPTION);
}

+ (void)setUprightWiiRemote:(BOOL)upright {
  {
    const auto lock = ControllerEmu::EmulatedController::GetStateLock();
    SetBool(Wiimote::GetWiimoteGroup(0, WiimoteEmu::WiimoteGroup::Options),
            WiimoteEmu::Wiimote::UPRIGHT_OPTION, upright);
  }

  Wiimote::GetConfig()->SaveConfig();
}

+ (PrismInputSource)wiiInputSource {
  return SourceForController(Wiimote::GetConfig()->GetController(0));
}

+ (void)setWiiInputSource:(PrismInputSource)source {
  if (source == PrismInputSourceOther) {
    return;
  }

  // Loading a profile resets the extension and orientation, so keep the user's style.
  const PrismWiiStyle style = [self currentWiiStyle];
  const BOOL upright = [self uprightWiiRemote];

  LoadBuiltInProfile(Wiimote::GetConfig(), source == PrismInputSourceTouchscreen ?
                                               PrismTouchscreenProfile :
                                               PrismPhysicalProfile);

  [self applyWiiStyle:style];
  [self setUprightWiiRemote:upright];
}

+ (PrismInputSource)gameCubeInputSource {
  return SourceForController(Pad::GetConfig()->GetController(0));
}

+ (void)setGameCubeInputSource:(PrismInputSource)source {
  if (source == PrismInputSourceOther) {
    return;
  }

  if (Config::Get(Config::GetInfoForSIDevice(0)) == SerialInterface::SIDEVICE_NONE) {
    Config::SetBaseOrCurrent(Config::GetInfoForSIDevice(0),
                             SerialInterface::SIDEVICE_GC_CONTROLLER);
  }

  LoadBuiltInProfile(Pad::GetConfig(), source == PrismInputSourceTouchscreen ?
                                           PrismTouchscreenProfile :
                                           PrismPhysicalProfile);

  Pad::GetConfig()->SaveConfig();
}

+ (nullable NSString*)currentGameID {
  if (!Core::IsRunning(Core::System::GetInstance())) {
    return nil;
  }

  const std::string game_id = SConfig::GetInstance().GetGameID();

  if (game_id.empty() || game_id == "00000000") {
    return nil;
  }

  return [NSString stringWithUTF8String:game_id.c_str()];
}

+ (nullable NSString*)currentGameName {
  if (!Core::IsRunning(Core::System::GetInstance())) {
    return nil;
  }

  const std::string name = SConfig::GetInstance().GetTitleName();

  if (name.empty()) {
    return nil;
  }

  return [NSString stringWithUTF8String:name.c_str()];
}

+ (NSDictionary<NSString*, NSNumber*>*)rememberedStyles {
  NSDictionary* stored = [NSUserDefaults.standardUserDefaults dictionaryForKey:PrismRememberedStylesKey];
  return stored ?: @{};
}

+ (void)rememberStyle:(PrismWiiStyle)style forGameID:(NSString*)gameID {
  NSMutableDictionary* styles = [[self rememberedStyles] mutableCopy];
  styles[gameID] = @(style);
  [NSUserDefaults.standardUserDefaults setObject:styles forKey:PrismRememberedStylesKey];
}

+ (void)forgetStyleForGameID:(NSString*)gameID {
  NSMutableDictionary* styles = [[self rememberedStyles] mutableCopy];
  [styles removeObjectForKey:gameID];
  [NSUserDefaults.standardUserDefaults setObject:styles forKey:PrismRememberedStylesKey];
}

+ (nullable NSNumber*)rememberedStyleForGameID:(NSString*)gameID {
  return [self rememberedStyles][gameID];
}

+ (NSInteger)rememberedStyleCount {
  return (NSInteger)[self rememberedStyles].count;
}

+ (void)forgetAllRememberedStyles {
  [NSUserDefaults.standardUserDefaults removeObjectForKey:PrismRememberedStylesKey];
}

+ (BOOL)applyRememberedStyleForCurrentGame {
  NSString* gameID = [self currentGameID];

  if (gameID == nil) {
    return NO;
  }

  NSNumber* remembered = [self rememberedStyleForGameID:gameID];

  if (remembered == nil) {
    return NO;
  }

  const PrismWiiStyle style = (PrismWiiStyle)remembered.integerValue;

  if (style == [self currentWiiStyle]) {
    return NO;
  }

  [self applyWiiStyle:style];
  return YES;
}

@end

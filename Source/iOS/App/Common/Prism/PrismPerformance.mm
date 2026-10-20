// Copyright 2026 PrismRVL Project
// SPDX-License-Identifier: GPL-2.0-or-later

#import "PrismPerformance.h"

#import <memory>

#import "Common/Config/Config.h"
#import "Common/Config/Layer.h"

#import "Core/Config/GraphicsSettings.h"
#import "Core/Config/MainSettings.h"

#import "VideoCommon/VideoConfig.h"

static NSString* const PrismPresetKey = @"prism_performance_preset";
static NSString* const PrismUnderclockKey = @"prism_nojit_underclock";

namespace
{
// Dolphin's layer order is Base < CommandLine < GlobalGame < LocalGame < ... < CurrentRun.
// iOS never registers a CommandLine layer, so PrismRVL owns it: values written here beat the
// user's base settings but lose to the per-game INIs that carry compatibility fixes.
class PrismPresetLayerLoader final : public Config::ConfigLayerLoader
{
public:
  PrismPresetLayerLoader() : ConfigLayerLoader(Config::LayerType::CommandLine) {}

  void Load(Config::Layer*) override {}
  void Save(Config::Layer*) override {}
};

std::shared_ptr<Config::Layer> PresetLayer()
{
  if (!Config::GetLayer(Config::LayerType::CommandLine))
    Config::AddLayer(std::make_unique<PrismPresetLayerLoader>());

  return Config::GetLayer(Config::LayerType::CommandLine);
}

template <typename T, typename V>
void SetPreset(const Config::Info<T>& info, const V& value)
{
  Config::Set(Config::LayerType::CommandLine, info, static_cast<T>(value));
}
}  // namespace

@implementation PrismPerformance

+ (PrismPerformancePreset)preset {
  NSUserDefaults* defaults = NSUserDefaults.standardUserDefaults;

  if ([defaults objectForKey:PrismPresetKey] == nil) {
    return PrismPerformancePresetBalanced;
  }

  return (PrismPerformancePreset)[defaults integerForKey:PrismPresetKey];
}

+ (void)setPreset:(PrismPerformancePreset)preset {
  [NSUserDefaults.standardUserDefaults setInteger:preset forKey:PrismPresetKey];
}

+ (PrismNoJitUnderclock)noJitUnderclock {
  return (PrismNoJitUnderclock)[NSUserDefaults.standardUserDefaults integerForKey:PrismUnderclockKey];
}

+ (void)setNoJitUnderclock:(PrismNoJitUnderclock)underclock {
  [NSUserDefaults.standardUserDefaults setInteger:underclock forKey:PrismUnderclockKey];
}

+ (BOOL)showPerformanceOverlay {
  return Config::GetBase(Config::GFX_SHOW_FPS) && Config::GetBase(Config::GFX_SHOW_SPEED);
}

+ (void)setShowPerformanceOverlay:(BOOL)show {
  Config::ConfigChangeCallbackGuard guard;
  Config::SetBase(Config::GFX_SHOW_FPS, (bool)show);
  Config::SetBase(Config::GFX_SHOW_SPEED, (bool)show);
}

+ (NSString*)nameForPreset:(PrismPerformancePreset)preset {
  switch (preset) {
    case PrismPerformancePresetQuality:
      return @"Quality";
    case PrismPerformancePresetBalanced:
      return @"Balanced";
    case PrismPerformancePresetPerformance:
      return @"Performance";
  }

  return @"Balanced";
}

+ (NSString*)detailForPreset:(PrismPerformancePreset)preset {
  switch (preset) {
    case PrismPerformancePresetQuality:
      return @"Uses your Graphics settings exactly as you set them.";
    case PrismPerformancePresetBalanced:
      return @"Compiles shaders in the background so games don't hitch, and keeps EFB copies on the GPU.";
    case PrismPerformancePresetPerformance:
      return @"Balanced, plus native resolution, no MSAA or anisotropy, and skips CPU EFB access. "
             @"Per-game fixes still apply.";
  }

  return @"";
}

+ (NSString*)nameForUnderclock:(PrismNoJitUnderclock)underclock {
  switch (underclock) {
    case PrismNoJitUnderclockOff:
      return @"Off";
    case PrismNoJitUnderclock90:
      return @"90%";
    case PrismNoJitUnderclock80:
      return @"80%";
    case PrismNoJitUnderclock70:
      return @"70%";
  }

  return @"Off";
}

+ (void)applyForBootWithJit:(BOOL)jitAvailable {
  std::shared_ptr<Config::Layer> layer = PresetLayer();

  if (!layer) {
    return;
  }

  Config::ConfigChangeCallbackGuard guard;

  layer->DeleteAllKeys();

  const PrismPerformancePreset preset = [self preset];

  if (preset != PrismPerformancePresetQuality) {
    SetPreset(Config::GFX_SHADER_COMPILATION_MODE, ShaderCompilationMode::AsynchronousSkipRendering);
    SetPreset(Config::GFX_WAIT_FOR_SHADERS_BEFORE_STARTING, false);
    SetPreset(Config::GFX_HACK_DEFER_EFB_COPIES, true);
    SetPreset(Config::GFX_HACK_SKIP_EFB_COPY_TO_RAM, true);
    SetPreset(Config::GFX_HACK_SKIP_XFB_COPY_TO_RAM, true);
    SetPreset(Config::GFX_HACK_FAST_TEXTURE_SAMPLING, true);
    SetPreset(Config::MAIN_CPU_THREAD, true);
    SetPreset(Config::MAIN_SYNC_GPU, false);
  }

  if (preset == PrismPerformancePresetPerformance) {
    SetPreset(Config::GFX_EFB_SCALE, 1);
    SetPreset(Config::GFX_MSAA, 1u);
    SetPreset(Config::GFX_ENHANCE_MAX_ANISOTROPY, AnisotropicFilteringMode::Force1x);
    SetPreset(Config::GFX_HACK_EFB_ACCESS_ENABLE, false);
    SetPreset(Config::GFX_HACK_BBOX_ENABLE, false);
    SetPreset(Config::GFX_HACK_EFB_EMULATE_FORMAT_CHANGES, false);
  }

  if (!jitAvailable) {
    float clock = 1.0f;

    switch ([self noJitUnderclock]) {
      case PrismNoJitUnderclockOff:
        break;
      case PrismNoJitUnderclock90:
        clock = 0.9f;
        break;
      case PrismNoJitUnderclock80:
        clock = 0.8f;
        break;
      case PrismNoJitUnderclock70:
        clock = 0.7f;
        break;
    }

    if (clock < 1.0f) {
      SetPreset(Config::MAIN_OVERCLOCK_ENABLE, true);
      SetPreset(Config::MAIN_OVERCLOCK, clock);
    }
  }

  Config::OnConfigChanged();
}

+ (void)clearAfterEmulation {
  std::shared_ptr<Config::Layer> layer = Config::GetLayer(Config::LayerType::CommandLine);

  if (!layer) {
    return;
  }

  layer->DeleteAllKeys();
  Config::OnConfigChanged();
}

@end

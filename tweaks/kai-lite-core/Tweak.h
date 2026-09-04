#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import <YouTubeHeader/YTSettingsSectionItem.h>
#import <YouTubeHeader/YTSettingsSectionItemManager.h>
#import <YouTubeHeader/YTSettingsViewController.h>
#import <YouTubeHeader/YTSettingsPickerViewController.h>
#import <YouTubeHeader/YTSettingsCell.h>
#import <YouTubeHeader/YTUIUtils.h>
#import <YouTubeHeader/MLFormat.h>
#import <YouTubeHeader/MLQuickMenuVideoQualitySettingFormatConstraint.h>
#import <YouTubeHeader/YTPlayerViewController.h>
#import <YouTubeHeader/YTSingleVideoController.h>

#import "Utils/NSBundle+KL.h"
#import "Utils/KLUserDefaults.h"

#define LOC(key) ({ \
    NSString *s = [NSBundle.kl_defaultBundle localizedStringForKey:(key) value:nil table:nil]; \
    (s.length > 0) ? s : (key); \
})

#define klBool(key)         [[KLUserDefaults standardUserDefaults] boolForKey:key]
#define klInt(key)          [[KLUserDefaults standardUserDefaults] integerForKey:key]
#define klStr(key)          [[KLUserDefaults standardUserDefaults] stringForKey:key]
#define klSetBool(v, key)   [[KLUserDefaults standardUserDefaults] setBool:(v) forKey:key]
#define klSetInt(v, key)    [[KLUserDefaults standardUserDefaults] setInteger:(v) forKey:key]
#define klSetStr(v, key)    [[KLUserDefaults standardUserDefaults] setObject:(v) forKey:key]

// kai-lite owns settings category 999 in YouTube's Settings UI.
static const NSInteger KaiLiteSection = 999;

// SponsorBlock category list (implemented in Tweak.x).
NSArray<NSString *> *KLSponsorCategoriesList(void);

// Shared quality choices for the Wi-Fi and mobile selectors.
NSArray<NSString *> *KLQualityLabels(void);

@interface YTPlayerViewController (KaiLite)
@property (nonatomic, strong) NSMutableDictionary *kl_sbSegments;
- (void)kl_skipIfInSegment;
- (void)kl_applyConfiguredQuality;
@end

@interface YTSingleVideoController (KaiLiteQuality)
- (void)setVideoFormatConstraint:(id)formatConstraint;
@end

@interface YTToastResponderEvent : NSObject
+ (instancetype)eventWithMessage:(NSString *)message firstResponder:(id)responder;
- (void)send;
@end

@interface YTSettingsSectionItemManager (KaiLite)
- (void)updateKaiLiteSectionWithEntry:(id)entry;
- (YTSettingsSectionItem *)kl_switchWithTitle:(NSString *)titleKey key:(NSString *)key;
- (YTSettingsSectionItem *)kl_qualityItemWithTitle:(NSString *)titleKey key:(NSString *)key;
@end

@interface YTAppSettingsPresentationData : NSObject
+ (NSArray *)settingsCategoryOrder;
@end

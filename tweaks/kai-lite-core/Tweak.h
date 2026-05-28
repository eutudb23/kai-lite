#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import <YouTubeHeader/YTSettingsSectionItem.h>
#import <YouTubeHeader/YTSettingsSectionItemManager.h>
#import <YouTubeHeader/YTSettingsViewController.h>
#import <YouTubeHeader/YTSettingsPickerViewController.h>
#import <YouTubeHeader/YTSettingsCell.h>
#import <YouTubeHeader/YTUIUtils.h>

#import "Utils/NSBundle+KL.h"
#import "Utils/KLUserDefaults.h"

#define LOC(key) ({ \
    NSString *s = [NSBundle.kl_defaultBundle localizedStringForKey:(key) value:nil table:nil]; \
    (s.length > 0) ? s : (key); \
})

#define klBool(key)         [[KLUserDefaults standardUserDefaults] boolForKey:key]
#define klInt(key)          [[KLUserDefaults standardUserDefaults] integerForKey:key]
#define klSetBool(v, key)   [[KLUserDefaults standardUserDefaults] setBool:(v) forKey:key]
#define klSetInt(v, key)    [[KLUserDefaults standardUserDefaults] setInteger:(v) forKey:key]

// kai-lite owns settings category 27500 in YouTube's Settings UI.
static const NSInteger KaiLiteSection = 27500;

// SponsorBlock category list. Order matters for the settings UI.
static NSArray<NSString *> *const KLSponsorCategories = nil;  // defined in Tweak.x

@interface YTPlayerViewController : UIViewController
@property (nonatomic, strong) NSMutableDictionary *kl_sbSegments;
- (void)seekToTime:(CGFloat)time;
- (NSString *)currentVideoID;
- (CGFloat)currentVideoMediaTime;
- (void)kl_skipIfInSegment;
@end

@interface YTToastResponderEvent : NSObject
+ (instancetype)eventWithMessage:(NSString *)message firstResponder:(id)responder;
- (void)send;
@end

@interface YTSettingsSectionItemManager (KaiLite)
- (void)updateKaiLiteSectionWithEntry:(id)entry;
- (YTSettingsSectionItem *)kl_switchWithTitle:(NSString *)title key:(NSString *)key;
@end

@interface YTAppSettingsPresentationData : NSObject
+ (NSArray *)settingsCategoryOrder;
@end

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <os/log.h>

// Diagnostic logging — uses %{public}@ markers so values survive iOS unified
// log redaction (vanilla NSLog values come out as <private>). View on Mac via
// Console.app or `idevicesyslog -u <udid> | grep kai-lite`.
#define KL_LOG(fmt, ...) os_log(OS_LOG_DEFAULT, "[kai-lite] " fmt, ##__VA_ARGS__)

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

// kai-lite owns settings category 999 in YouTube's Settings UI. Matches
// the low-number range used by every working PoomSmart tweak (YouPiP=200,
// YTABC=404, RYD=1080) — large IDs are not rendered on current YouTube.
static const NSInteger KaiLiteSection = 999;

// SponsorBlock category list (implemented in Tweak.x). Order matters for the settings UI.
NSArray<NSString *> *KLSponsorCategoriesList(void);

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

@interface YTAppDelegate : UIResponder <UIApplicationDelegate>
@end

@interface YTSettingsSectionItemManager (KaiLite)
- (void)updateKaiLiteSectionWithEntry:(id)entry;
@end

@interface YTAppSettingsPresentationData : NSObject
+ (NSArray *)settingsCategoryOrder;
@end

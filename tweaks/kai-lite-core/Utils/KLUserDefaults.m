#import "KLUserDefaults.h"

@implementation KLUserDefaults

static NSString *const kSuiteName = @"com.kai-lite.core";

+ (KLUserDefaults *)standardUserDefaults {
    static dispatch_once_t onceToken;
    static KLUserDefaults *defaults = nil;

    dispatch_once(&onceToken, ^{
        defaults = [[self alloc] initWithSuiteName:kSuiteName];
        [defaults registerDefaults];
    });

    return defaults;
}

- (void)registerDefaults {
    [self registerDefaults:@{
        // SponsorBlock
        @"sponsorBlock":       @YES,
        @"sbSkipMode":         @0,    // 0 = auto-skip, 1 = ask
        @"sbDuration":         @5,    // notification duration (seconds)
        @"sb_cat_sponsor":     @YES,  // paid promotion
        @"sb_cat_selfpromo":   @YES,  // unpaid self promotion
        @"sb_cat_interaction": @NO,   // like / subscribe reminders
        @"sb_cat_intro":       @NO,   // animation intro
        @"sb_cat_outro":       @NO,   // animation outro / credits
        @"sb_cat_preview":     @NO,   // recap / preview
        @"sb_cat_music_offtopic": @NO,
        @"sb_cat_filler":      @NO,
    }];
}

@end

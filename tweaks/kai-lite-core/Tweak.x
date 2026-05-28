#import "Tweak.h"

// Fires at dylib load. If the user sees this in the log, the dylib injected and
// its constructors ran — confirming Settings.x hooks should also be installed.
__attribute__((constructor))
static void KL_DylibLoaded(void) {
    KL_LOG("dylib loaded section=%ld", (long)KaiLiteSection);
}

// Categories supported by sponsor.ajay.app. Each maps to a settings key sb_cat_<name>.
NSArray<NSString *> *KLSponsorCategoriesList(void) {
    static NSArray<NSString *> *cats = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cats = @[
            @"sponsor",
            @"selfpromo",
            @"interaction",
            @"intro",
            @"outro",
            @"preview",
            @"music_offtopic",
            @"filler",
        ];
    });
    return cats;
}

static NSString *KLEnabledCategoriesParam(void) {
    NSMutableArray<NSString *> *enabled = [NSMutableArray array];
    for (NSString *cat in KLSponsorCategoriesList()) {
        NSString *key = [@"sb_cat_" stringByAppendingString:cat];
        if (klBool(key)) {
            [enabled addObject:[NSString stringWithFormat:@"\"%@\"", cat]];
        }
    }
    if (enabled.count == 0) return nil;
    return [NSString stringWithFormat:@"[%@]", [enabled componentsJoinedByString:@","]];
}

%hook YTPlayerViewController

%property (nonatomic, strong) NSMutableDictionary *kl_sbSegments;

- (void)playbackController:(id)arg1 didActivateVideo:(id)arg2 withPlaybackData:(id)arg3 {
    %orig;

    if (!klBool(@"sponsorBlock")) return;

    NSString *videoID = self.currentVideoID;
    if (videoID.length == 0) return;

    NSString *categoriesParam = KLEnabledCategoriesParam();
    if (categoriesParam == nil) return;  // no categories enabled, nothing to fetch

    self.kl_sbSegments = [NSMutableDictionary dictionary];

    NSString *encodedCategories = [categoriesParam stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://sponsor.ajay.app/api/skipSegments?videoID=%@&categories=%@", videoID, encodedCategories]];
    NSURLRequest *req = [NSURLRequest requestWithURL:url];

    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || data == nil) return;
        id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![parsed isKindOfClass:[NSArray class]]) return;

        NSMutableDictionary *skipFlags = [NSMutableDictionary dictionary];
        for (NSDictionary *segment in parsed) {
            if (![segment isKindOfClass:[NSDictionary class]]) continue;
            NSString *uuid = segment[@"UUID"];
            if (uuid) skipFlags[uuid] = @(1);
        }

        @synchronized(self) {
            self.kl_sbSegments[videoID] = parsed;
            self.kl_sbSegments[@"flags"] = skipFlags;
        }
    }] resume];
}

- (void)singleVideo:(id)video currentVideoTimeDidChange:(id)time {
    %orig;
    [self kl_skipIfInSegment];
}

- (void)potentiallyMutatedSingleVideo:(id)video currentVideoTimeDidChange:(id)time {
    %orig;
    [self kl_skipIfInSegment];
}

%new
- (void)kl_skipIfInSegment {
    if (!klBool(@"sponsorBlock")) return;
    if (self.kl_sbSegments == nil) return;

    NSString *videoID = self.currentVideoID;
    if (videoID.length == 0) return;

    NSArray *segments = nil;
    NSMutableDictionary *flags = nil;
    @synchronized(self.kl_sbSegments) {
        id s = self.kl_sbSegments[videoID];
        id f = self.kl_sbSegments[@"flags"];
        if ([s isKindOfClass:[NSArray class]]) segments = s;
        if ([f isKindOfClass:[NSMutableDictionary class]]) flags = f;
    }
    if (segments == nil || flags == nil) return;

    CGFloat now = self.currentVideoMediaTime;

    for (NSDictionary *seg in segments) {
        if (![seg isKindOfClass:[NSDictionary class]]) continue;

        NSString *uuid = seg[@"UUID"];
        NSNumber *flag = flags[uuid];
        if (flag == nil || ![flag isEqual:@(1)]) continue;

        NSString *category = seg[@"category"];
        NSString *catKey = [@"sb_cat_" stringByAppendingString:category ?: @""];
        if (!klBool(catKey)) continue;  // user toggled this category off after the fetch

        NSArray *bounds = seg[@"segment"];
        if (![bounds isKindOfClass:[NSArray class]] || bounds.count < 2) continue;
        CGFloat start = [bounds[0] floatValue];
        CGFloat end   = [bounds[1] floatValue];

        if (now >= start && now <= (end - 1)) {
            @synchronized(self) {
                flags[uuid] = @(0);  // mark consumed
                self.kl_sbSegments[@"flags"] = flags;
            }

            if (klInt(@"sbSkipMode") == 0) {
                [self seekToTime:end];

                Class toastCls = %c(YTToastResponderEvent);
                if (toastCls) {
                    NSString *msg = [NSString stringWithFormat:@"%@ (%@)", LOC(@"SegmentSkipped"), LOC([@"Cat_" stringByAppendingString:category])];
                    YTToastResponderEvent *event = [toastCls eventWithMessage:msg firstResponder:self];
                    [event send];
                }
            }
            // sbSkipMode == 1 (ask): silently do nothing for Phase 1. Interactive
            // skip prompt UI ships in a follow-up.
        }
    }
}

%end

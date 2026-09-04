#import "Tweak.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>
#import <stdlib.h>
#import <string.h>

NSArray<NSString *> *KLQualityLabels(void) {
    static NSArray<NSString *> *labels = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        labels = @[
            @"Default",
            @"Best",
            @"2160p60",
            @"2160p",
            @"1440p60",
            @"1440p",
            @"1080p60",
            @"1080p",
            @"720p60",
            @"720p",
            @"480p",
            @"360p",
            @"240p",
            @"144p",
        ];
    });
    return labels;
}

static BOOL KLIsUsingWiFi(void) {
    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_len = sizeof(address);
    address.sin_family = AF_INET;

    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithAddress(NULL, (const struct sockaddr *)&address);
    if (reachability == NULL) return NO;

    SCNetworkReachabilityFlags flags = 0;
    BOOL gotFlags = SCNetworkReachabilityGetFlags(reachability, &flags);
    CFRelease(reachability);
    if (!gotFlags) return NO;

    BOOL reachable = (flags & kSCNetworkReachabilityFlagsReachable) != 0;
    BOOL connectionRequired = (flags & kSCNetworkReachabilityFlagsConnectionRequired) != 0;
    BOOL cellular = (flags & kSCNetworkReachabilityFlagsIsWWAN) != 0;
    return reachable && !connectionRequired && !cellular;
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

- (void)loadWithPlayerTransition:(id)transition playbackConfig:(id)playbackConfig {
    %orig;

    NSString *qualityKey = KLIsUsingWiFi() ? @"wiFiQualityIndex" : @"cellQualityIndex";
    if (klInt(qualityKey) != 0) {
        [self performSelector:@selector(kl_applyConfiguredQuality) withObject:nil afterDelay:1.0];
    }
}

%new
- (void)kl_applyConfiguredQuality {
    if (![self.view.superview isKindOfClass:NSClassFromString(@"YTWatchView")]) return;

    NSString *qualityKey = KLIsUsingWiFi() ? @"wiFiQualityIndex" : @"cellQualityIndex";
    NSInteger selectedIndex = klInt(qualityKey);
    NSArray<NSString *> *qualityLabels = KLQualityLabels();
    if (selectedIndex <= 0 || selectedIndex >= (NSInteger)qualityLabels.count) return;

    NSString *targetQualityLabel = qualityLabels[selectedIndex];
    NSInteger targetResolution = targetQualityLabel.integerValue;
    YTSingleVideoController *activeVideo = (YTSingleVideoController *)self.activeVideo;
    if (![activeVideo respondsToSelector:@selector(selectableVideoFormats)] ||
        ![activeVideo respondsToSelector:@selector(setVideoFormatConstraint:)]) return;

    MLFormat *closestFormat = nil;
    NSInteger closestDifference = selectedIndex == 1 ? -1 : NSIntegerMax;

    for (MLFormat *format in activeVideo.selectableVideoFormats) {
        if (selectedIndex == 1) {
            NSInteger resolution = format.singleDimensionResolution;
            if (resolution > closestDifference) {
                closestDifference = resolution;
                closestFormat = format;
            }
            continue;
        }

        if ([format.qualityLabel isEqualToString:targetQualityLabel]) {
            closestFormat = format;
            break;
        }

        NSInteger resolution = format.singleDimensionResolution;
        if (resolution <= 0 || format.qualityLabel.length == 0) continue;

        NSInteger difference = labs(resolution - targetResolution);
        if (difference < closestDifference) {
            closestDifference = difference;
            closestFormat = format;
        }
    }

    if (closestFormat == nil) return;

    Class constraintClass = %c(MLQuickMenuVideoQualitySettingFormatConstraint);
    if (constraintClass == Nil) return;

    MLQuickMenuVideoQualitySettingFormatConstraint *constraint = [[constraintClass alloc] init];
    if ([constraint respondsToSelector:@selector(initWithVideoQualitySetting:formatSelectionReason:qualityLabel:)]) {
        constraint = [constraint initWithVideoQualitySetting:3 formatSelectionReason:2 qualityLabel:closestFormat.qualityLabel];
        [activeVideo setVideoFormatConstraint:constraint];
    }
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
    @synchronized(self) {
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
        if (!klBool(catKey)) continue;

        NSArray *bounds = seg[@"segment"];
        if (![bounds isKindOfClass:[NSArray class]] || bounds.count < 2) continue;
        CGFloat start = [bounds[0] floatValue];
        CGFloat end   = [bounds[1] floatValue];

        if (now >= start && now <= (end - 1)) {
            @synchronized(self) {
                flags[uuid] = @(0);
                self.kl_sbSegments[@"flags"] = flags;
            }

            if (klInt(@"sbSkipMode") == 0) {
                [self seekToTime:end];
                Class toastCls = %c(YTToastResponderEvent);
                if (toastCls) {
                    NSString *msg = [NSString stringWithFormat:@"%@ (%@)", LOC(@"SegmentSkipped"), LOC([@"Cat_" stringByAppendingString:category])];
                    [[toastCls eventWithMessage:msg firstResponder:self] send];
                }
            }
        }
    }
}

%end

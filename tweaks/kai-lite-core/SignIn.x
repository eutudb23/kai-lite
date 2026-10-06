#import "Tweak.h"

static NSString *const KLOfficialYouTubeBundleID = @"com.google.ios.youtube";
static NSString *const KLOfficialYouTubeName = @"YouTube";

// Based on the current uYouEnhanced sign-in patch, with the identity spoof
// kept behind kai-lite's own opt-in setting.
// Google sign-in validates YouTube's App Store identity. A resigned IPA has a
// different on-disk bundle identifier, so expose the official identity only
// while the user explicitly enables this temporary compatibility patch.
%group KLGoogleSignInPatch

%hook NSBundle

+ (NSBundle *)bundleWithIdentifier:(NSString *)identifier {
    if ([identifier isEqualToString:KLOfficialYouTubeBundleID]) {
        return NSBundle.mainBundle;
    }
    return %orig(identifier);
}

- (NSString *)bundleIdentifier {
    if ([self isEqual:NSBundle.mainBundle]) {
        return KLOfficialYouTubeBundleID;
    }
    return %orig;
}

- (NSDictionary *)infoDictionary {
    NSDictionary *originalInfo = %orig;
    if (![self isEqual:NSBundle.mainBundle]) {
        return originalInfo;
    }

    NSMutableDictionary *patchedInfo = [originalInfo mutableCopy];
    patchedInfo[@"CFBundleIdentifier"] = KLOfficialYouTubeBundleID;
    patchedInfo[@"CFBundleDisplayName"] = KLOfficialYouTubeName;
    patchedInfo[@"CFBundleName"] = KLOfficialYouTubeName;
    return patchedInfo.copy;
}

- (id)objectForInfoDictionaryKey:(NSString *)key {
    if (![self isEqual:NSBundle.mainBundle]) {
        return %orig;
    }
    if ([key isEqualToString:@"CFBundleIdentifier"]) {
        return KLOfficialYouTubeBundleID;
    }
    if ([key isEqualToString:@"CFBundleDisplayName"] ||
        [key isEqualToString:@"CFBundleName"]) {
        return KLOfficialYouTubeName;
    }
    return %orig;
}

%end

%end

%ctor {
    if (klBool(@"googleSignInPatch")) {
        %init(KLGoogleSignInPatch);
    }
}

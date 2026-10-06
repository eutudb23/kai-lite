#import "Tweak.h"

static NSString *const KLOfficialYouTubeBundleID = @"com.google.ios.youtube";

// YTSideload already supplies Dany's caller-scoped bundle-identity and
// keychain hooks in the assembled IPA. The newer sign-in patch also resolves
// official-bundle lookups back to the resigned main bundle. Keep only that
// missing hook here: unconditional NSBundle instance overrides leak into
// UIKit and crash iPadOS 17 while it builds the keyboard assistant bar.
%group KLGoogleSignInPatch

%hook NSBundle

+ (NSBundle *)bundleWithIdentifier:(NSString *)identifier {
    if ([identifier isEqualToString:KLOfficialYouTubeBundleID]) {
        return NSBundle.mainBundle;
    }
    return %orig(identifier);
}

%end

%end

%ctor {
    if (klBool(@"googleSignInPatchV2")) {
        %init(KLGoogleSignInPatch);
    }
}

#import "Tweak.h"

static NSString *const KLOfficialYouTubeBundleID = @"com.google.ios.youtube";

// Keep a privacy-safe trace in the app container so device tests can establish
// which SSO path actually ran. No URLs, account identifiers, or request bodies
// are recorded.
static void KLSignInTrace(NSString *event) {
    if (event.length == 0) return;

    NSURL *cachesURL = [NSFileManager.defaultManager URLsForDirectory:NSCachesDirectory
                                                            inDomains:NSUserDomainMask].lastObject;
    NSURL *logURL = [cachesURL URLByAppendingPathComponent:@"KaiLiteSignIn.log"];
    NSString *line = [NSString stringWithFormat:@"%@ %@\n", NSDate.date, event];
    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];

    @synchronized (NSFileManager.defaultManager) {
        if (![NSFileManager.defaultManager fileExistsAtPath:logURL.path]) {
            [data writeToURL:logURL options:NSDataWritingAtomic error:nil];
            return;
        }

        NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:logURL.path];
        [handle seekToEndOfFile];
        [handle writeData:data];
        [handle closeFile];
    }
}

// Dany's current sideloading implementation reports the official app identity
// at Google's SSO boundary and keeps Safari sign-in enabled. These hooks are
// deliberately limited to SSO classes: process-wide NSBundle impersonation
// caused UIKit to crash on iPadOS 17.
%group KLGoogleSignInPatch

%hook SSOBundleIdServiceImpl

- (id)bundleId {
    KLSignInTrace(@"SSOBundleIdServiceImpl.bundleId");
    return KLOfficialYouTubeBundleID;
}

%end

%hook SSOConfiguration

- (id)applicationIdentifier {
    KLSignInTrace(@"SSOConfiguration.applicationIdentifier");
    return KLOfficialYouTubeBundleID;
}

- (BOOL)shouldEnableSafariSignIn {
    KLSignInTrace(@"SSOConfiguration.shouldEnableSafariSignIn");
    return YES;
}

- (BOOL)temporarilyDisableSafariSignIn {
    KLSignInTrace(@"SSOConfiguration.temporarilyDisableSafariSignIn");
    return NO;
}

- (void)setTemporarilyDisableSafariSignIn:(BOOL)disabled {
    KLSignInTrace(@"SSOConfiguration.setTemporarilyDisableSafariSignIn");
    %orig(NO);
}

%end

%hook SSOService

+ (id)fetcherWithRequest:(NSMutableURLRequest *)request configuration:(id)configuration {
    if ([request isKindOfClass:NSMutableURLRequest.class] && request.HTTPBody.length > 0) {
        NSError *readError = nil;
        id object = [NSJSONSerialization JSONObjectWithData:request.HTTPBody
                                                    options:NSJSONReadingMutableContainers
                                                      error:&readError];
        if (readError == nil && [object isKindOfClass:NSMutableDictionary.class]) {
            NSMutableDictionary *body = object;
            if (body[@"device_challenge_request"] != nil) {
                [body removeObjectForKey:@"device_challenge_request"];

                NSError *writeError = nil;
                NSData *data = [NSJSONSerialization dataWithJSONObject:body
                                                               options:0
                                                                 error:&writeError];
                if (writeError == nil && data != nil) {
                    request.HTTPBody = data;
                    KLSignInTrace(@"SSOService.removedDeviceChallenge");
                }
            }
        }
    }

    return %orig(request, configuration);
}

%end

%end


%ctor {
    if (klBool(@"googleSignInPatchV5")) {
        KLSignInTrace(@"patch.enabled.v5");
        %init(KLGoogleSignInPatch);
    }
}

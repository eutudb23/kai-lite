#import "Tweak.h"

// Google rejects the device challenge generated for a resigned YouTube app.
// Limit the workaround to the SSO request that carries that challenge instead
// of changing NSBundle or NSJSONSerialization process-wide.
%group KLGoogleSignInPatch

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
                }
            }
        }
    }

    return %orig(request, configuration);
}

%end

%end


%ctor {
    if (klBool(@"googleSignInPatchV4")) {
        %init(KLGoogleSignInPatch);
    }
}

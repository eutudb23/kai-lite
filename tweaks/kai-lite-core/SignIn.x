#import "Tweak.h"
#import <Security/Security.h>

static NSString *const KLOfficialYouTubeBundleID = @"com.google.ios.youtube";

static NSString *KLSignerKeychainAccessGroup(void) {
    NSDictionary *query = @{
        (__bridge NSString *)kSecClass: (__bridge NSString *)kSecClassGenericPassword,
        (__bridge NSString *)kSecAttrAccount: @"bundleSeedID",
        (__bridge NSString *)kSecAttrService: @"",
        (__bridge NSString *)kSecReturnAttributes: @YES,
    };

    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status == errSecItemNotFound) {
        status = SecItemAdd((__bridge CFDictionaryRef)query, &result);
    }
    if (status != errSecSuccess || result == NULL) {
        if (result != NULL) CFRelease(result);
        return nil;
    }

    NSDictionary *attributes = CFBridgingRelease(result);
    return attributes[(__bridge NSString *)kSecAttrAccessGroup];
}

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

// YouTube 21.40.5 uses these newer Google/Firebase storage paths in addition
// to SSOKeychainHelper/Core, which the bundled YTSideload already patches.
%hook SSOClientLogin
+ (NSString *)defaultSourceString {
    return KLOfficialYouTubeBundleID;
}
%end

%hook YTHotConfig
- (BOOL)clientInfraClientConfigIosEnableFillingEncodedHacksInnertubeContext {
    return NO;
}
%end

%hook SSOFolsomKeychainUtils
- (id)sharedAccessGroup {
    return KLSignerKeychainAccessGroup();
}
%end

%hook GULKeychainStorage
- (void)getObjectForKey:(id)key objectClass:(Class)objectClass accessGroup:(id)accessGroup completionHandler:(id)handler {
    %orig(key, objectClass, KLSignerKeychainAccessGroup(), handler);
}

- (void)setObject:(id)object forKey:(id)key accessGroup:(id)accessGroup completionHandler:(id)handler {
    %orig(object, key, KLSignerKeychainAccessGroup(), handler);
}

- (void)removeObjectForKey:(id)key accessGroup:(id)accessGroup completionHandler:(id)handler {
    %orig(key, KLSignerKeychainAccessGroup(), handler);
}

- (void)getObjectFromKeychainForKey:(id)key objectClass:(Class)objectClass accessGroup:(id)accessGroup completionHandler:(id)handler {
    %orig(key, objectClass, KLSignerKeychainAccessGroup(), handler);
}

- (id)keychainQueryWithKey:(id)key accessGroup:(id)accessGroup {
    return %orig(key, KLSignerKeychainAccessGroup());
}
%end

%hook GNPEncryptionConfiguration
- (id)initWithKeychainAccessGroup:(id)accessGroup {
    return %orig(KLSignerKeychainAccessGroup());
}

- (id)keychainAccessGroup {
    return KLSignerKeychainAccessGroup();
}
%end

%hook FIRInstallationsStore
- (id)initWithSecureStorage:(id)secureStorage accessGroup:(id)accessGroup {
    return %orig(secureStorage, KLSignerKeychainAccessGroup());
}

- (id)accessGroup {
    return KLSignerKeychainAccessGroup();
}
%end

%hook CHMConfiguration
- (void)setKeychainAccessGroup:(id)accessGroup {
    %orig(KLSignerKeychainAccessGroup());
}

- (id)keychainAccessGroup {
    return KLSignerKeychainAccessGroup();
}
%end

%end

%ctor {
    if (klBool(@"googleSignInPatchV3")) {
        %init(KLGoogleSignInPatch);
    }
}

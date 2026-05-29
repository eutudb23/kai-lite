#import "Tweak.h"
#import <YouTubeHeader/YTIIcon.h>
#import <YouTubeHeader/YTSettingsGroupData.h>

#pragma mark - Helpers

// Builds a sub-section picker push action. Strong-self capture matches the
// proven YTLite/RYD pattern — avoiding the weakSelf+block-parameter combo
// that crashes (nil rows inside @[] literal).
#define KL_PUSH_PICKER(titleKey, rowsExpr) \
    selectBlock:^BOOL(YTSettingsCell *cell, NSUInteger arg1) { \
        YTSettingsViewController *vc = [self valueForKey:@"_dataDelegate"]; \
        if (!vc) vc = [self valueForKey:@"_settingsViewControllerDelegate"]; \
        NSArray<YTSettingsSectionItem *> *rows = rowsExpr; \
        YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc] \
            initWithNavTitle:LOC(titleKey) \
          pickerSectionTitle:nil \
                        rows:rows \
           selectedItemIndex:NSNotFound \
             parentResponder:[self parentResponder]]; \
        [vc pushViewController:picker]; \
        return YES; \
    }

// Uses the `itemWithTitle:accessibilityIdentifier:detailTextBlock:selectBlock:`
// variant (NOT the titleDescription one) — that's the one whose detailTextBlock
// param is typed as a BLOCK. The titleDescription variant types it as (id) and
// crashes if you pass a block.
#define KL_NAV_ITEM(titleKey, rowsExpr) \
    [%c(YTSettingsSectionItem) itemWithTitle:LOC(titleKey) \
                   accessibilityIdentifier:@"KaiLiteSectionItem" \
                           detailTextBlock:^NSString *() { return @"›"; } \
                               KL_PUSH_PICKER(titleKey, rowsExpr)]

#pragma mark - Category hooks (sidebar registration)

%hook YTSettingsGroupData

+ (NSMutableArray<NSNumber *> *)tweaks {
    NSMutableArray<NSNumber *> *originalTweaks = %orig;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (![originalTweaks containsObject:@(KaiLiteSection)]) {
            [originalTweaks addObject:@(KaiLiteSection)];
        }
    });
    return originalTweaks;
}

- (NSArray<NSNumber *> *)orderedCategories {
    if (self.type != 1 || class_getClassMethod(objc_getClass("YTSettingsGroupData"), @selector(tweaks)))
        return %orig;
    NSMutableArray *mutableCategories = %orig.mutableCopy;
    [mutableCategories insertObject:@(KaiLiteSection) atIndex:0];
    return mutableCategories.copy;
}

%end

%hook YTAppSettingsPresentationData

+ (NSArray<NSNumber *> *)settingsCategoryOrder {
    NSArray<NSNumber *> *order = %orig;
    NSUInteger insertIndex = [order indexOfObject:@(1)];
    if (insertIndex != NSNotFound) {
        NSMutableArray<NSNumber *> *mutableOrder = [order mutableCopy];
        [mutableOrder insertObject:@(KaiLiteSection) atIndex:insertIndex + 1];
        order = mutableOrder.copy;
    }
    return order;
}

%end

#pragma mark - Section content

%hook YTSettingsSectionItemManager

%new
- (YTSettingsSectionItem *)kl_switchWithTitle:(NSString *)titleKey key:(NSString *)key {
    NSString *descKey = [titleKey stringByAppendingString:@"Desc"];
    return [%c(YTSettingsSectionItem)
        switchItemWithTitle:LOC(titleKey)
           titleDescription:LOC(descKey)
    accessibilityIdentifier:@"KaiLiteSectionItem"
                   switchOn:klBool(key)
                switchBlock:^BOOL(YTSettingsCell *cell, BOOL enabled) {
                    klSetBool(enabled, key);
                    return YES;
                }
              settingItemId:0];
}

%new(v@:@)
- (void)updateKaiLiteSectionWithEntry:(id)entry {
    NSMutableArray<YTSettingsSectionItem *> *items = [NSMutableArray array];
    YTSettingsViewController *delegate = [self valueForKey:@"_dataDelegate"];
    if (!delegate) delegate = [self valueForKey:@"_settingsViewControllerDelegate"];

    // 1. Downloading
    [items addObject:KL_NAV_ITEM(@"Downloading", (@[
        [self kl_switchWithTitle:@"DownloadManager"    key:@"downloadManager"],
        [self kl_switchWithTitle:@"SavePostInfo"       key:@"savePostInfo"],
        [self kl_switchWithTitle:@"SaveProfilePic"     key:@"saveProfilePic"],
        [self kl_switchWithTitle:@"SaveCommentInfo"    key:@"saveCommentInfo"],
        [self kl_switchWithTitle:@"PreferStableVolume" key:@"preferStableVolume"],
        [self kl_switchWithTitle:@"EmbedThumbnails"    key:@"embedThumbnails"],
        [self kl_switchWithTitle:@"EmbedCaptions"      key:@"embedCaptions"],
    ]))];

    // 2. Navigation bar
    [items addObject:KL_NAV_ITEM(@"NavigationBar", (@[
        [self kl_switchWithTitle:@"HideCastButton"          key:@"hideCastButton"],
        [self kl_switchWithTitle:@"HideNotificationsButton" key:@"hideNotificationsButton"],
        [self kl_switchWithTitle:@"HideSearchButton"        key:@"hideSearchButton"],
        [self kl_switchWithTitle:@"HideVoiceSearchButton"   key:@"hideVoiceSearchButton"],
        [self kl_switchWithTitle:@"StickyNavigationBar"     key:@"stickyNavigationBar"],
        [self kl_switchWithTitle:@"HideSubbar"              key:@"hideSubbar"],
        [self kl_switchWithTitle:@"RemoveYouTubeLogo"       key:@"removeYouTubeLogo"],
        [self kl_switchWithTitle:@"SetPremiumLogo"          key:@"setPremiumLogo"],
    ]))];

    // 3. Feed
    [items addObject:KL_NAV_ITEM(@"Feed", (@[
        [self kl_switchWithTitle:@"RemoveAds"             key:@"removeAds"],
        [self kl_switchWithTitle:@"HideShortsVideos"      key:@"hideShortsVideos"],
        [self kl_switchWithTitle:@"KeepShortsInSubs"      key:@"keepShortsInSubs"],
        [self kl_switchWithTitle:@"RemoveMoreTopics"      key:@"removeMoreTopics"],
        [self kl_switchWithTitle:@"RemoveCommunityPosts"  key:@"removeCommunityPosts"],
        [self kl_switchWithTitle:@"RemoveMixes"           key:@"removeMixes"],
        [self kl_switchWithTitle:@"RemoveLiveVideos"      key:@"removeLiveVideos"],
        [self kl_switchWithTitle:@"RemoveHorizontalFeeds" key:@"removeHorizontalFeeds"],
        [self kl_switchWithTitle:@"RemovePlayables"       key:@"removePlayables"],
        [self kl_switchWithTitle:@"FixCovers"             key:@"fixCovers"],
    ]))];

    // 4. Player
    [items addObject:KL_NAV_ITEM(@"Player", (@[
        [self kl_switchWithTitle:@"IgnoreAutoDubbed"        key:@"ignoreAutoDubbed"],
        [self kl_switchWithTitle:@"AutoGeneratedCaptions"   key:@"autoGeneratedCaptions"],
        [self kl_switchWithTitle:@"SpeedControls"           key:@"speedControls"],
        [self kl_switchWithTitle:@"MuteButton"              key:@"muteButton"],
        [self kl_switchWithTitle:@"LockButton"              key:@"lockButton"],
        [self kl_switchWithTitle:@"HideAutoplaySwitch"      key:@"hideAutoplaySwitch"],
        [self kl_switchWithTitle:@"HideSubtitlesButton"     key:@"hideSubtitlesButton"],
        [self kl_switchWithTitle:@"HidePrevNextButtons"     key:@"hidePrevNextButtons"],
        [self kl_switchWithTitle:@"FastForwardRewind"       key:@"fastForwardRewind"],
        [self kl_switchWithTitle:@"RememberLoopMode"        key:@"rememberLoopMode"],
        [self kl_switchWithTitle:@"PortraitFullscreen"      key:@"portraitFullscreen"],
        [self kl_switchWithTitle:@"ClassicVideoQuality"     key:@"classicVideoQuality"],
        [self kl_switchWithTitle:@"ExtraSpeedOptions"       key:@"extraSpeedOptions"],
        [self kl_switchWithTitle:@"RemoveDarkBackground"    key:@"removeDarkBackground"],
        [self kl_switchWithTitle:@"HideEndScreens"          key:@"hideEndScreens"],
        [self kl_switchWithTitle:@"HideAutoPlayEnd"         key:@"hideAutoPlayEnd"],
        [self kl_switchWithTitle:@"DisableFullscreenActions" key:@"disableFullscreenActions"],
        [self kl_switchWithTitle:@"DisableSnackbars"        key:@"disableSnackbars"],
        [self kl_switchWithTitle:@"PersistentProgressBar"   key:@"persistentProgressBar"],
        [self kl_switchWithTitle:@"StockVolumeHUD"          key:@"stockVolumeHUD"],
        [self kl_switchWithTitle:@"NoRelatedInOverlay"      key:@"noRelatedInOverlay"],
    ]))];

    // 5. Shorts
    [items addObject:KL_NAV_ITEM(@"Shorts", (@[
        [self kl_switchWithTitle:@"ShortsOnlyMode"       key:@"shortsOnlyMode"],
        [self kl_switchWithTitle:@"LimitShorts"          key:@"limitShorts"],
        [self kl_switchWithTitle:@"ShortsEnableProgress" key:@"shortsEnableProgress"],
        [self kl_switchWithTitle:@"ShortsSpeedUp"        key:@"shortsSpeedUp"],
        [self kl_switchWithTitle:@"PinchToFullscreen"    key:@"pinchToFullscreen"],
        [self kl_switchWithTitle:@"ShortsToRegular"      key:@"shortsToRegular"],
        [self kl_switchWithTitle:@"ShortsRemoveLive"     key:@"shortsRemoveLive"],
        [self kl_switchWithTitle:@"HideShortsLogo"       key:@"hideShortsLogo"],
        [self kl_switchWithTitle:@"ShortsHideSearch"     key:@"shortsHideSearch"],
    ]))];

    // 6. Tab bar
    [items addObject:KL_NAV_ITEM(@"TabBar", (@[
        [self kl_switchWithTitle:@"TranslucentTabBar"   key:@"translucentTabBar"],
        [self kl_switchWithTitle:@"RemoveTabLabels"     key:@"removeTabLabels"],
        [self kl_switchWithTitle:@"RemoveTabIndicators" key:@"removeTabIndicators"],
    ]))];

    // 7. Interface
    [items addObject:KL_NAV_ITEM(@"Interface", (@[
        [self kl_switchWithTitle:@"OledTheme"           key:@"oledTheme"],
        [self kl_switchWithTitle:@"OledKeyboard"        key:@"oledKeyboard"],
        [self kl_switchWithTitle:@"HideSearchHistory"   key:@"hideSearchHistory"],
        [self kl_switchWithTitle:@"RemoveGuidelines"    key:@"removeGuidelines"],
        [self kl_switchWithTitle:@"StickCommentsHeader" key:@"stickCommentsHeader"],
        [self kl_switchWithTitle:@"HideCommentsHeader"  key:@"hideCommentsHeader"],
        [self kl_switchWithTitle:@"OldPlaylistMinibar"  key:@"oldPlaylistMinibar"],
        [self kl_switchWithTitle:@"DisableRTL"          key:@"disableRTL"],
    ]))];

    // 8. SponsorBlock — built dynamically since category list comes from helper.
    NSMutableArray<YTSettingsSectionItem *> *sbRows = [NSMutableArray array];
    [sbRows addObject:[self kl_switchWithTitle:@"Enabled" key:@"sponsorBlock"]];
    for (NSString *cat in KLSponsorCategoriesList()) {
        [sbRows addObject:[self kl_switchWithTitle:[@"Cat_" stringByAppendingString:cat]
                                                key:[@"sb_cat_" stringByAppendingString:cat]]];
    }
    [items addObject:KL_NAV_ITEM(@"SponsorBlock", [sbRows copy])];

    NSString *settingsTitle = LOC(@"KaiLite");
    if ([delegate respondsToSelector:@selector(setSectionItems:forCategory:title:icon:titleDescription:headerHidden:)]) {
        YTIIcon *icon = [%c(YTIIcon) new];
        icon.iconType = YT_TUNE;
        [delegate setSectionItems:items forCategory:KaiLiteSection title:settingsTitle icon:icon titleDescription:nil headerHidden:NO];
    } else {
        [delegate setSectionItems:items forCategory:KaiLiteSection title:settingsTitle titleDescription:nil headerHidden:NO];
    }
}

- (void)updateSectionForCategory:(NSUInteger)category withEntry:(id)entry {
    if (category == KaiLiteSection) {
        [self updateKaiLiteSectionWithEntry:entry];
        return;
    }
    %orig;
}

%end

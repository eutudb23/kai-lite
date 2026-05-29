#import "Tweak.h"
#import <YouTubeHeader/YTIIcon.h>
#import <YouTubeHeader/YTSettingsGroupData.h>

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

+ (NSArray *)settingsCategoryOrder {
    NSArray *order = %orig;
    NSMutableArray *mutableOrder = [order mutableCopy];
    NSUInteger insertIndex = [order indexOfObject:@(1)];
    if (insertIndex != NSNotFound)
        [mutableOrder insertObject:@(KaiLiteSection) atIndex:insertIndex + 1];
    return mutableOrder;
}

%end

// THE CRITICAL PROTECTIVE HOOK from dany's YTLite. When sub-pages are pushed
// with selectedItemIndex:NSNotFound, YouTube's internal code calls
// setSelectedItem:NSNotFound on the section controller — and that path crashes
// on current YouTube. Short-circuiting it here is what makes sub-page
// navigation actually work.
%hook YTSettingsSectionController
- (void)setSelectedItem:(NSUInteger)selectedItem {
    if (selectedItem != NSNotFound) %orig;
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
    NSMutableArray *sectionItems = [NSMutableArray array];
    Class YTSettingsSectionItemClass = %c(YTSettingsSectionItem);
    YTSettingsViewController *settingsViewController = [self valueForKey:@"_settingsViewControllerDelegate"];

    // 1. Downloading
    YTSettingsSectionItem *downloading = [YTSettingsSectionItemClass itemWithTitle:LOC(@"Downloading")
        accessibilityIdentifier:@"KaiLiteSectionItem"
        detailTextBlock:^NSString *() { return @"‣"; }
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            NSArray <YTSettingsSectionItem *> *rows = @[
                [self kl_switchWithTitle:@"DownloadManager"    key:@"downloadManager"],
                [self kl_switchWithTitle:@"SavePostInfo"       key:@"savePostInfo"],
                [self kl_switchWithTitle:@"SaveProfilePic"     key:@"saveProfilePic"],
                [self kl_switchWithTitle:@"SaveCommentInfo"    key:@"saveCommentInfo"],
                [self kl_switchWithTitle:@"PreferStableVolume" key:@"preferStableVolume"],
                [self kl_switchWithTitle:@"EmbedThumbnails"    key:@"embedThumbnails"],
                [self kl_switchWithTitle:@"EmbedCaptions"      key:@"embedCaptions"],
            ];
            YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc] initWithNavTitle:LOC(@"Downloading") pickerSectionTitle:nil rows:rows selectedItemIndex:NSNotFound parentResponder:[self parentResponder]];
            [settingsViewController pushViewController:picker];
            return YES;
        }];
    [sectionItems addObject:downloading];

    // 2. Navigation bar
    YTSettingsSectionItem *navbar = [YTSettingsSectionItemClass itemWithTitle:LOC(@"NavigationBar")
        accessibilityIdentifier:@"KaiLiteSectionItem"
        detailTextBlock:^NSString *() { return @"‣"; }
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            NSArray <YTSettingsSectionItem *> *rows = @[
                [self kl_switchWithTitle:@"HideCastButton"          key:@"hideCastButton"],
                [self kl_switchWithTitle:@"HideNotificationsButton" key:@"hideNotificationsButton"],
                [self kl_switchWithTitle:@"HideSearchButton"        key:@"hideSearchButton"],
                [self kl_switchWithTitle:@"HideVoiceSearchButton"   key:@"hideVoiceSearchButton"],
                [self kl_switchWithTitle:@"StickyNavigationBar"     key:@"stickyNavigationBar"],
                [self kl_switchWithTitle:@"HideSubbar"              key:@"hideSubbar"],
                [self kl_switchWithTitle:@"RemoveYouTubeLogo"       key:@"removeYouTubeLogo"],
                [self kl_switchWithTitle:@"SetPremiumLogo"          key:@"setPremiumLogo"],
            ];
            YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc] initWithNavTitle:LOC(@"NavigationBar") pickerSectionTitle:nil rows:rows selectedItemIndex:NSNotFound parentResponder:[self parentResponder]];
            [settingsViewController pushViewController:picker];
            return YES;
        }];
    [sectionItems addObject:navbar];

    // 3. Feed
    YTSettingsSectionItem *feed = [YTSettingsSectionItemClass itemWithTitle:LOC(@"Feed")
        accessibilityIdentifier:@"KaiLiteSectionItem"
        detailTextBlock:^NSString *() { return @"‣"; }
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            NSArray <YTSettingsSectionItem *> *rows = @[
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
            ];
            YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc] initWithNavTitle:LOC(@"Feed") pickerSectionTitle:nil rows:rows selectedItemIndex:NSNotFound parentResponder:[self parentResponder]];
            [settingsViewController pushViewController:picker];
            return YES;
        }];
    [sectionItems addObject:feed];

    // 4. Player
    YTSettingsSectionItem *player = [YTSettingsSectionItemClass itemWithTitle:LOC(@"Player")
        accessibilityIdentifier:@"KaiLiteSectionItem"
        detailTextBlock:^NSString *() { return @"‣"; }
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            NSArray <YTSettingsSectionItem *> *rows = @[
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
            ];
            YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc] initWithNavTitle:LOC(@"Player") pickerSectionTitle:nil rows:rows selectedItemIndex:NSNotFound parentResponder:[self parentResponder]];
            [settingsViewController pushViewController:picker];
            return YES;
        }];
    [sectionItems addObject:player];

    // 5. Shorts
    YTSettingsSectionItem *shorts = [YTSettingsSectionItemClass itemWithTitle:LOC(@"Shorts")
        accessibilityIdentifier:@"KaiLiteSectionItem"
        detailTextBlock:^NSString *() { return @"‣"; }
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            NSArray <YTSettingsSectionItem *> *rows = @[
                [self kl_switchWithTitle:@"ShortsOnlyMode"       key:@"shortsOnlyMode"],
                [self kl_switchWithTitle:@"LimitShorts"          key:@"limitShorts"],
                [self kl_switchWithTitle:@"ShortsEnableProgress" key:@"shortsEnableProgress"],
                [self kl_switchWithTitle:@"ShortsSpeedUp"        key:@"shortsSpeedUp"],
                [self kl_switchWithTitle:@"PinchToFullscreen"    key:@"pinchToFullscreen"],
                [self kl_switchWithTitle:@"ShortsToRegular"      key:@"shortsToRegular"],
                [self kl_switchWithTitle:@"ShortsRemoveLive"     key:@"shortsRemoveLive"],
                [self kl_switchWithTitle:@"HideShortsLogo"       key:@"hideShortsLogo"],
                [self kl_switchWithTitle:@"ShortsHideSearch"     key:@"shortsHideSearch"],
            ];
            YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc] initWithNavTitle:LOC(@"Shorts") pickerSectionTitle:nil rows:rows selectedItemIndex:NSNotFound parentResponder:[self parentResponder]];
            [settingsViewController pushViewController:picker];
            return YES;
        }];
    [sectionItems addObject:shorts];

    // 6. Tab bar
    YTSettingsSectionItem *tabbar = [YTSettingsSectionItemClass itemWithTitle:LOC(@"TabBar")
        accessibilityIdentifier:@"KaiLiteSectionItem"
        detailTextBlock:^NSString *() { return @"‣"; }
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            NSArray <YTSettingsSectionItem *> *rows = @[
                [self kl_switchWithTitle:@"TranslucentTabBar"   key:@"translucentTabBar"],
                [self kl_switchWithTitle:@"RemoveTabLabels"     key:@"removeTabLabels"],
                [self kl_switchWithTitle:@"RemoveTabIndicators" key:@"removeTabIndicators"],
            ];
            YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc] initWithNavTitle:LOC(@"TabBar") pickerSectionTitle:nil rows:rows selectedItemIndex:NSNotFound parentResponder:[self parentResponder]];
            [settingsViewController pushViewController:picker];
            return YES;
        }];
    [sectionItems addObject:tabbar];

    // 7. Interface
    YTSettingsSectionItem *interface = [YTSettingsSectionItemClass itemWithTitle:LOC(@"Interface")
        accessibilityIdentifier:@"KaiLiteSectionItem"
        detailTextBlock:^NSString *() { return @"‣"; }
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            NSArray <YTSettingsSectionItem *> *rows = @[
                [self kl_switchWithTitle:@"OledTheme"           key:@"oledTheme"],
                [self kl_switchWithTitle:@"OledKeyboard"        key:@"oledKeyboard"],
                [self kl_switchWithTitle:@"HideSearchHistory"   key:@"hideSearchHistory"],
                [self kl_switchWithTitle:@"RemoveGuidelines"    key:@"removeGuidelines"],
                [self kl_switchWithTitle:@"StickCommentsHeader" key:@"stickCommentsHeader"],
                [self kl_switchWithTitle:@"HideCommentsHeader"  key:@"hideCommentsHeader"],
                [self kl_switchWithTitle:@"OldPlaylistMinibar"  key:@"oldPlaylistMinibar"],
                [self kl_switchWithTitle:@"DisableRTL"          key:@"disableRTL"],
            ];
            YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc] initWithNavTitle:LOC(@"Interface") pickerSectionTitle:nil rows:rows selectedItemIndex:NSNotFound parentResponder:[self parentResponder]];
            [settingsViewController pushViewController:picker];
            return YES;
        }];
    [sectionItems addObject:interface];

    // 8. SponsorBlock
    YTSettingsSectionItem *sponsorBlock = [YTSettingsSectionItemClass itemWithTitle:LOC(@"SponsorBlock")
        accessibilityIdentifier:@"KaiLiteSectionItem"
        detailTextBlock:^NSString *() { return @"‣"; }
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            NSMutableArray <YTSettingsSectionItem *> *rows = [NSMutableArray array];
            [rows addObject:[self kl_switchWithTitle:@"Enabled" key:@"sponsorBlock"]];
            for (NSString *cat in KLSponsorCategoriesList()) {
                [rows addObject:[self kl_switchWithTitle:[@"Cat_" stringByAppendingString:cat]
                                                     key:[@"sb_cat_" stringByAppendingString:cat]]];
            }
            YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc] initWithNavTitle:LOC(@"SponsorBlock") pickerSectionTitle:nil rows:rows selectedItemIndex:NSNotFound parentResponder:[self parentResponder]];
            [settingsViewController pushViewController:picker];
            return YES;
        }];
    [sectionItems addObject:sponsorBlock];

    // Register the kai-lite section against the data delegate (separate ivar
    // from the settingsViewController above — _dataDelegate is for registration,
    // _settingsViewControllerDelegate is for navigation).
    YTSettingsViewController *delegate = [self valueForKey:@"_dataDelegate"];
    NSString *settingsTitle = LOC(@"KaiLite");
    if ([delegate respondsToSelector:@selector(setSectionItems:forCategory:title:icon:titleDescription:headerHidden:)]) {
        YTIIcon *icon = [%c(YTIIcon) new];
        icon.iconType = YT_TUNE;
        [delegate setSectionItems:sectionItems forCategory:KaiLiteSection title:settingsTitle icon:icon titleDescription:nil headerHidden:NO];
    } else {
        [delegate setSectionItems:sectionItems forCategory:KaiLiteSection title:settingsTitle titleDescription:nil headerHidden:NO];
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

#import "Tweak.h"
#import "TabBar.h"
#import "V2Bridge.h"
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
    NSArray<NSNumber *> *originalCategories = %orig;
    NSMutableArray<NSNumber *> *mutableCategories = [originalCategories mutableCopy];
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

%new
- (YTSettingsSectionItem *)kl_qualityItemWithTitle:(NSString *)titleKey key:(NSString *)key {
    NSArray<NSString *> *qualityLabels = KLQualityLabels();
    YTSettingsViewController *settingsViewController = [self valueForKey:@"_settingsViewControllerDelegate"];

    return [%c(YTSettingsSectionItem)
        itemWithTitle:LOC(titleKey)
        accessibilityIdentifier:@"KaiLiteSectionItem"
        detailTextBlock:^NSString *() {
            NSInteger selectedIndex = klInt(key);
            if (selectedIndex < 0 || selectedIndex >= (NSInteger)qualityLabels.count) selectedIndex = 0;
            NSString *qualityLabel = qualityLabels[selectedIndex];
            return selectedIndex < 2 ? LOC(qualityLabel) : qualityLabel;
        }
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            NSMutableArray<YTSettingsSectionItem *> *rows = [NSMutableArray array];
            for (NSUInteger index = 0; index < qualityLabels.count; index++) {
                NSString *qualityLabel = qualityLabels[index];
                NSString *displayLabel = index < 2 ? LOC(qualityLabel) : qualityLabel;
                [rows addObject:[%c(YTSettingsSectionItem)
                    checkmarkItemWithTitle:displayLabel
                    titleDescription:nil
                    selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger selectedIndex) {
                        klSetInt(selectedIndex, key);
                        [settingsViewController reloadData];
                        return YES;
                    }]];
            }

            NSInteger selectedIndex = klInt(key);
            if (selectedIndex < 0 || selectedIndex >= (NSInteger)qualityLabels.count) selectedIndex = 0;
            YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc]
                initWithNavTitle:LOC(@"SelectQuality")
                pickerSectionTitle:nil
                rows:rows
                selectedItemIndex:(NSUInteger)selectedIndex
                parentResponder:[self parentResponder]];
            [settingsViewController pushViewController:picker];
            return YES;
        }];
}

%new(v@:@)
- (void)updateKaiLiteSectionWithEntry:(id)entry {
    NSMutableArray *sectionItems = [NSMutableArray array];
    Class YTSettingsSectionItemClass = %c(YTSettingsSectionItem);
    YTSettingsViewController *settingsViewController = [self valueForKey:@"_settingsViewControllerDelegate"];

    // Temporary sign-in compatibility patch. It is intentionally a direct
    // kai-lite row so it remains reachable while the user is signed out.
    [sectionItems addObject:[self kl_switchWithTitle:@"YouTubeSignInPatch"
                                                  key:@"googleSignInPatchV6"]];

    // 1. Downloading
    YTSettingsSectionItem *downloading = [YTSettingsSectionItemClass itemWithTitle:LOC(@"Downloading")
        accessibilityIdentifier:@"KaiLiteSectionItem"
        detailTextBlock:^NSString *() { return @"‣"; }
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            if (KLOpenV2Page(@"downloads", settingsViewController)) return YES;
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
            if (KLOpenV2Page(@"topbar", settingsViewController)) return YES;
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
            if (KLOpenV2Page(@"feed", settingsViewController)) return YES;
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
            if (KLHasV2Features()) {
                NSMutableArray<YTSettingsSectionItem *> *v2Rows = [NSMutableArray array];
                for (NSDictionary<NSString *, NSString *> *page in @[
                    @{@"title": @"MorePlayerControls", @"id": @"player"},
                    @{@"title": @"Captions", @"id": @"captions"},
                    @{@"title": @"Gestures", @"id": @"gestures"},
                    @{@"title": @"WatchPage", @"id": @"watch"},
                ]) {
                    [v2Rows addObject:[YTSettingsSectionItemClass itemWithTitle:LOC(page[@"title"])
                        accessibilityIdentifier:@"KaiLiteSectionItem"
                        detailTextBlock:^NSString *() { return @"‣"; }
                        selectBlock:^BOOL(YTSettingsCell *pageCell, NSUInteger pageArg) {
                            return KLOpenV2Page(page[@"id"], settingsViewController);
                        }]];
                }
                [v2Rows addObject:[self kl_qualityItemWithTitle:@"PlaybackQualityOnWiFi" key:@"wiFiQualityIndex"]];
                [v2Rows addObject:[self kl_qualityItemWithTitle:@"PlaybackQualityOnMobile" key:@"cellQualityIndex"]];
                YTSettingsPickerViewController *v2Picker = [[%c(YTSettingsPickerViewController) alloc]
                    initWithNavTitle:LOC(@"Player") pickerSectionTitle:nil rows:v2Rows
                    selectedItemIndex:NSNotFound parentResponder:[self parentResponder]];
                [settingsViewController pushViewController:v2Picker];
                return YES;
            }
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
                [self kl_qualityItemWithTitle:@"PlaybackQualityOnWiFi" key:@"wiFiQualityIndex"],
                [self kl_qualityItemWithTitle:@"PlaybackQualityOnMobile" key:@"cellQualityIndex"],
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
            if (KLOpenV2Page(@"shorts", settingsViewController)) return YES;
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
            if (KLOpenV2Page(@"tabs", settingsViewController)) return YES;
            NSMutableArray<YTSettingsSectionItem *> *rows = [NSMutableArray arrayWithArray:@[
                [self kl_switchWithTitle:@"TranslucentTabBar"   key:@"translucentTabBar"],
                [self kl_switchWithTitle:@"RemoveTabLabels"     key:@"removeTabLabels"],
                [self kl_switchWithTitle:@"RemoveTabIndicators" key:@"removeTabIndicators"],
            ]];
            NSDictionary<NSString *, NSString *> *tabTitles = @{
                @"FEwhat_to_watch": @"HomeTab",
                @"FEshorts": @"ShortsTab",
                @"FEuploads": @"CreateTab",
                @"FEsubscriptions": @"SubscriptionsTab",
                @"FElibrary": @"LibraryTab",
            };
            for (NSString *identifier in @[@"FEshorts", @"FEuploads", @"FEsubscriptions", @"FElibrary"]) {
                NSString *title = [@"Show" stringByAppendingString:tabTitles[identifier]];
                [rows addObject:[YTSettingsSectionItemClass
                    switchItemWithTitle:LOC(title)
                    titleDescription:LOC([title stringByAppendingString:@"Desc"])
                    accessibilityIdentifier:@"KaiLiteSectionItem"
                    switchOn:KLTabIsVisible(identifier)
                    switchBlock:^BOOL(YTSettingsCell *switchCell, BOOL enabled) {
                        KLSetTabVisible(identifier, enabled);
                        return YES;
                    }
                    settingItemId:0]];
            }
            [rows addObject:[YTSettingsSectionItemClass itemWithTitle:LOC(@"TabOrder")
                accessibilityIdentifier:@"KaiLiteSectionItem"
                detailTextBlock:^NSString *() { return @"‣"; }
                selectBlock:^BOOL(YTSettingsCell *orderCell, NSUInteger orderArg) {
                    NSMutableArray<YTSettingsSectionItem *> *orderRows = [NSMutableArray array];
                    for (NSString *identifier in KLTabOrder()) {
                        [orderRows addObject:[YTSettingsSectionItemClass itemWithTitle:LOC(tabTitles[identifier])
                            accessibilityIdentifier:@"KaiLiteSectionItem"
                            detailTextBlock:^NSString *() {
                                return [NSString stringWithFormat:@"%lu", (unsigned long)([KLTabOrder() indexOfObject:identifier] + 1)];
                            }
                            selectBlock:^BOOL(YTSettingsCell *tabCell, NSUInteger tabArg) {
                                NSMutableArray<YTSettingsSectionItem *> *moveRows = [NSMutableArray array];
                                for (NSNumber *direction in @[@(-1), @(1)]) {
                                    NSString *moveTitle = direction.integerValue < 0 ? @"MoveEarlier" : @"MoveLater";
                                    [moveRows addObject:[YTSettingsSectionItemClass itemWithTitle:LOC(moveTitle)
                                        accessibilityIdentifier:@"KaiLiteSectionItem"
                                        detailTextBlock:nil
                                        selectBlock:^BOOL(YTSettingsCell *moveCell, NSUInteger moveArg) {
                                            KLMoveTab(identifier, direction.integerValue);
                                            [settingsViewController reloadData];
                                            return YES;
                                        }]];
                                }
                                YTSettingsPickerViewController *movePicker = [[%c(YTSettingsPickerViewController) alloc]
                                    initWithNavTitle:LOC(tabTitles[identifier]) pickerSectionTitle:nil
                                    rows:moveRows selectedItemIndex:NSNotFound parentResponder:[self parentResponder]];
                                [settingsViewController pushViewController:movePicker];
                                return YES;
                            }]];
                    }
                    YTSettingsPickerViewController *orderPicker = [[%c(YTSettingsPickerViewController) alloc]
                        initWithNavTitle:LOC(@"TabOrder") pickerSectionTitle:nil
                        rows:orderRows selectedItemIndex:NSNotFound parentResponder:[self parentResponder]];
                    [settingsViewController pushViewController:orderPicker];
                    return YES;
                }]];
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
            if (KLOpenV2Page(@"general", settingsViewController)) return YES;
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

#import "Tweak.h"
#import <YouTubeHeader/YTIIcon.h>
#import <YouTubeHeader/YTSettingsGroupData.h>

#pragma mark - Category hooks (sidebar registration)

%hook YTSettingsGroupData

// Newer YouTube renders the "Tweaks" sidebar group from +tweaks.
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

%new
- (YTSettingsSectionItem *)kl_navItemWithTitle:(NSString *)titleKey rowsBuilder:(NSArray<YTSettingsSectionItem *> *(^)(void))rowsBuilder {
    __weak __typeof(self) weakSelf = self;
    return [%c(YTSettingsSectionItem)
        itemWithTitle:LOC(titleKey)
     titleDescription:nil
accessibilityIdentifier:@"KaiLiteSectionItem"
      detailTextBlock:^NSString *() { return @"›"; }
          selectBlock:^BOOL(YTSettingsCell *cell, NSUInteger arg1) {
              YTSettingsViewController *settingsVC = [weakSelf valueForKey:@"_dataDelegate"];
              if (!settingsVC) settingsVC = [weakSelf valueForKey:@"_settingsViewControllerDelegate"];
              NSArray<YTSettingsSectionItem *> *rows = rowsBuilder();
              YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc]
                  initWithNavTitle:LOC(titleKey)
                pickerSectionTitle:nil
                              rows:rows
                 selectedItemIndex:NSNotFound
                   parentResponder:[weakSelf parentResponder]];
              [settingsVC pushViewController:picker];
              return YES;
          }];
}

%new(v@:@)
- (void)updateKaiLiteSectionWithEntry:(id)entry {
    NSMutableArray<YTSettingsSectionItem *> *items = [NSMutableArray array];
    YTSettingsViewController *delegate = [self valueForKey:@"_dataDelegate"];
    if (!delegate) delegate = [self valueForKey:@"_settingsViewControllerDelegate"];

    __weak __typeof(self) weakSelf = self;

    // 1. Downloading
    [items addObject:[self kl_navItemWithTitle:@"Downloading" rowsBuilder:^NSArray *{
        return @[
            [weakSelf kl_switchWithTitle:@"DownloadManager"    key:@"downloadManager"],
            [weakSelf kl_switchWithTitle:@"SavePostInfo"       key:@"savePostInfo"],
            [weakSelf kl_switchWithTitle:@"SaveProfilePic"     key:@"saveProfilePic"],
            [weakSelf kl_switchWithTitle:@"SaveCommentInfo"    key:@"saveCommentInfo"],
            [weakSelf kl_switchWithTitle:@"PreferStableVolume" key:@"preferStableVolume"],
            [weakSelf kl_switchWithTitle:@"EmbedThumbnails"    key:@"embedThumbnails"],
            [weakSelf kl_switchWithTitle:@"EmbedCaptions"      key:@"embedCaptions"],
        ];
    }]];

    // 2. Navigation bar
    [items addObject:[self kl_navItemWithTitle:@"NavigationBar" rowsBuilder:^NSArray *{
        return @[
            [weakSelf kl_switchWithTitle:@"HideCastButton"          key:@"hideCastButton"],
            [weakSelf kl_switchWithTitle:@"HideNotificationsButton" key:@"hideNotificationsButton"],
            [weakSelf kl_switchWithTitle:@"HideSearchButton"        key:@"hideSearchButton"],
            [weakSelf kl_switchWithTitle:@"HideVoiceSearchButton"   key:@"hideVoiceSearchButton"],
            [weakSelf kl_switchWithTitle:@"StickyNavigationBar"     key:@"stickyNavigationBar"],
            [weakSelf kl_switchWithTitle:@"HideSubbar"              key:@"hideSubbar"],
            [weakSelf kl_switchWithTitle:@"RemoveYouTubeLogo"       key:@"removeYouTubeLogo"],
            [weakSelf kl_switchWithTitle:@"SetPremiumLogo"          key:@"setPremiumLogo"],
        ];
    }]];

    // 3. Feed
    [items addObject:[self kl_navItemWithTitle:@"Feed" rowsBuilder:^NSArray *{
        return @[
            [weakSelf kl_switchWithTitle:@"RemoveAds"             key:@"removeAds"],
            [weakSelf kl_switchWithTitle:@"HideShortsVideos"      key:@"hideShortsVideos"],
            [weakSelf kl_switchWithTitle:@"KeepShortsInSubs"      key:@"keepShortsInSubs"],
            [weakSelf kl_switchWithTitle:@"RemoveMoreTopics"      key:@"removeMoreTopics"],
            [weakSelf kl_switchWithTitle:@"RemoveCommunityPosts"  key:@"removeCommunityPosts"],
            [weakSelf kl_switchWithTitle:@"RemoveMixes"           key:@"removeMixes"],
            [weakSelf kl_switchWithTitle:@"RemoveLiveVideos"      key:@"removeLiveVideos"],
            [weakSelf kl_switchWithTitle:@"RemoveHorizontalFeeds" key:@"removeHorizontalFeeds"],
            [weakSelf kl_switchWithTitle:@"RemovePlayables"       key:@"removePlayables"],
            [weakSelf kl_switchWithTitle:@"FixCovers"             key:@"fixCovers"],
        ];
    }]];

    // 4. Player
    [items addObject:[self kl_navItemWithTitle:@"Player" rowsBuilder:^NSArray *{
        return @[
            [weakSelf kl_switchWithTitle:@"IgnoreAutoDubbed"      key:@"ignoreAutoDubbed"],
            [weakSelf kl_switchWithTitle:@"AutoGeneratedCaptions" key:@"autoGeneratedCaptions"],
            [weakSelf kl_switchWithTitle:@"SpeedControls"         key:@"speedControls"],
            [weakSelf kl_switchWithTitle:@"MuteButton"            key:@"muteButton"],
            [weakSelf kl_switchWithTitle:@"LockButton"            key:@"lockButton"],
            [weakSelf kl_switchWithTitle:@"HideAutoplaySwitch"    key:@"hideAutoplaySwitch"],
            [weakSelf kl_switchWithTitle:@"HideSubtitlesButton"   key:@"hideSubtitlesButton"],
            [weakSelf kl_switchWithTitle:@"HidePrevNextButtons"   key:@"hidePrevNextButtons"],
            [weakSelf kl_switchWithTitle:@"FastForwardRewind"     key:@"fastForwardRewind"],
            [weakSelf kl_switchWithTitle:@"RememberLoopMode"      key:@"rememberLoopMode"],
            [weakSelf kl_switchWithTitle:@"PortraitFullscreen"    key:@"portraitFullscreen"],
            [weakSelf kl_switchWithTitle:@"ClassicVideoQuality"   key:@"classicVideoQuality"],
            [weakSelf kl_switchWithTitle:@"ExtraSpeedOptions"     key:@"extraSpeedOptions"],
            [weakSelf kl_switchWithTitle:@"RemoveDarkBackground"  key:@"removeDarkBackground"],
            [weakSelf kl_switchWithTitle:@"HideEndScreens"        key:@"hideEndScreens"],
            [weakSelf kl_switchWithTitle:@"HideAutoPlayEnd"       key:@"hideAutoPlayEnd"],
            [weakSelf kl_switchWithTitle:@"DisableFullscreenActions" key:@"disableFullscreenActions"],
            [weakSelf kl_switchWithTitle:@"DisableSnackbars"      key:@"disableSnackbars"],
            [weakSelf kl_switchWithTitle:@"PersistentProgressBar" key:@"persistentProgressBar"],
            [weakSelf kl_switchWithTitle:@"StockVolumeHUD"        key:@"stockVolumeHUD"],
            [weakSelf kl_switchWithTitle:@"NoRelatedInOverlay"    key:@"noRelatedInOverlay"],
        ];
    }]];

    // 5. Shorts
    [items addObject:[self kl_navItemWithTitle:@"Shorts" rowsBuilder:^NSArray *{
        return @[
            [weakSelf kl_switchWithTitle:@"ShortsOnlyMode"        key:@"shortsOnlyMode"],
            [weakSelf kl_switchWithTitle:@"LimitShorts"           key:@"limitShorts"],
            [weakSelf kl_switchWithTitle:@"ShortsEnableProgress"  key:@"shortsEnableProgress"],
            [weakSelf kl_switchWithTitle:@"ShortsSpeedUp"         key:@"shortsSpeedUp"],
            [weakSelf kl_switchWithTitle:@"PinchToFullscreen"     key:@"pinchToFullscreen"],
            [weakSelf kl_switchWithTitle:@"ShortsToRegular"       key:@"shortsToRegular"],
            [weakSelf kl_switchWithTitle:@"ShortsRemoveLive"      key:@"shortsRemoveLive"],
            [weakSelf kl_switchWithTitle:@"HideShortsLogo"        key:@"hideShortsLogo"],
            [weakSelf kl_switchWithTitle:@"ShortsHideSearch"      key:@"shortsHideSearch"],
        ];
    }]];

    // 6. Tab bar
    [items addObject:[self kl_navItemWithTitle:@"TabBar" rowsBuilder:^NSArray *{
        return @[
            [weakSelf kl_switchWithTitle:@"TranslucentTabBar"  key:@"translucentTabBar"],
            [weakSelf kl_switchWithTitle:@"RemoveTabLabels"    key:@"removeTabLabels"],
            [weakSelf kl_switchWithTitle:@"RemoveTabIndicators" key:@"removeTabIndicators"],
        ];
    }]];

    // 7. Interface
    [items addObject:[self kl_navItemWithTitle:@"Interface" rowsBuilder:^NSArray *{
        return @[
            [weakSelf kl_switchWithTitle:@"OledTheme"          key:@"oledTheme"],
            [weakSelf kl_switchWithTitle:@"OledKeyboard"       key:@"oledKeyboard"],
            [weakSelf kl_switchWithTitle:@"HideSearchHistory"  key:@"hideSearchHistory"],
            [weakSelf kl_switchWithTitle:@"RemoveGuidelines"   key:@"removeGuidelines"],
            [weakSelf kl_switchWithTitle:@"StickCommentsHeader" key:@"stickCommentsHeader"],
            [weakSelf kl_switchWithTitle:@"HideCommentsHeader" key:@"hideCommentsHeader"],
            [weakSelf kl_switchWithTitle:@"OldPlaylistMinibar" key:@"oldPlaylistMinibar"],
            [weakSelf kl_switchWithTitle:@"DisableRTL"         key:@"disableRTL"],
        ];
    }]];

    // 8. SponsorBlock (fully wired, Phase 1)
    [items addObject:[self kl_navItemWithTitle:@"SponsorBlock" rowsBuilder:^NSArray *{
        NSMutableArray<YTSettingsSectionItem *> *rows = [NSMutableArray array];
        [rows addObject:[weakSelf kl_switchWithTitle:@"Enabled" key:@"sponsorBlock"]];
        for (NSString *cat in KLSponsorCategoriesList()) {
            NSString *titleKey = [@"Cat_" stringByAppendingString:cat];
            NSString *prefKey  = [@"sb_cat_" stringByAppendingString:cat];
            [rows addObject:[weakSelf kl_switchWithTitle:titleKey key:prefKey]];
        }
        return rows;
    }]];

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

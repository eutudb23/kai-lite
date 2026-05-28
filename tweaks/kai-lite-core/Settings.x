#import "Tweak.h"
#import <YouTubeHeader/YTIIcon.h>
#import <YouTubeHeader/YTSettingsGroupData.h>

%hook YTSettingsGroupData

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

%hook YTSettingsSectionItemManager

%new(v@:@)
- (void)updateKaiLiteSectionWithEntry:(id)entry {
    NSMutableArray<YTSettingsSectionItem *> *items = [NSMutableArray array];
    YTSettingsViewController *delegate = [self valueForKey:@"_dataDelegate"];

    YTSettingsSectionItem *enabled = [%c(YTSettingsSectionItem)
        switchItemWithTitle:LOC(@"Enabled")
           titleDescription:LOC(@"EnabledDesc")
    accessibilityIdentifier:nil
                   switchOn:klBool(@"sponsorBlock")
                switchBlock:^BOOL(YTSettingsCell *cell, BOOL on) {
                    klSetBool(on, @"sponsorBlock");
                    return YES;
                }
              settingItemId:0];
    [items addObject:enabled];

    for (NSString *cat in KLSponsorCategoriesList()) {
        NSString *titleKey = [@"Cat_" stringByAppendingString:cat];
        NSString *descKey  = [titleKey stringByAppendingString:@"Desc"];
        NSString *prefKey  = [@"sb_cat_" stringByAppendingString:cat];
        YTSettingsSectionItem *row = [%c(YTSettingsSectionItem)
            switchItemWithTitle:LOC(titleKey)
               titleDescription:LOC(descKey)
        accessibilityIdentifier:nil
                       switchOn:klBool(prefKey)
                    switchBlock:^BOOL(YTSettingsCell *cell, BOOL on) {
                        klSetBool(on, prefKey);
                        return YES;
                    }
                  settingItemId:0];
        [items addObject:row];
    }

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

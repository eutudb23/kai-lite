#import "Tweak.h"
#import <YouTubeHeader/YTIIcon.h>
#import <YouTubeHeader/YTSettingsGroupData.h>

%hook YTSettingsGroupData

// Newer YouTube versions render the "Tweaks" sidebar group from +tweaks.
// YTLitePlus uses this exact pattern; without it, sections only registered
// via setSectionItems:forCategory: may not appear in the Tweaks group.
+ (NSMutableArray<NSNumber *> *)tweaks {
    NSMutableArray<NSNumber *> *originalTweaks = %orig;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (![originalTweaks containsObject:@(KaiLiteSection)]) {
            [originalTweaks addObject:@(KaiLiteSection)];
            KL_LOG("+tweaks: appended kai-lite -> %{public}@", originalTweaks);
        }
    });
    return originalTweaks;
}

- (NSArray<NSNumber *> *)orderedCategories {
    NSArray<NSNumber *> *orig = %orig;
    BOOL hasTweaksMethod = class_getClassMethod(objc_getClass("YTSettingsGroupData"), @selector(tweaks)) != NULL;
    KL_LOG("orderedCategories type=%ld origCount=%lu hasTweaksMethod=%d", (long)self.type, (unsigned long)orig.count, hasTweaksMethod);
    if (self.type != 1 || hasTweaksMethod)
        return orig;
    NSMutableArray *mutableCategories = orig.mutableCopy;
    [mutableCategories insertObject:@(KaiLiteSection) atIndex:0];
    KL_LOG("orderedCategories INSERTED kai-lite at 0 -> %{public}@", mutableCategories);
    return mutableCategories.copy;
}

%end

%hook YTAppSettingsPresentationData

+ (NSArray<NSNumber *> *)settingsCategoryOrder {
    NSArray<NSNumber *> *order = %orig;
    KL_LOG("settingsCategoryOrder orig=%{public}@", order);
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
    KL_LOG("updateKaiLiteSectionWithEntry FIRED");
    NSMutableArray<YTSettingsSectionItem *> *items = [NSMutableArray array];
    YTSettingsViewController *delegate = [self valueForKey:@"_dataDelegate"];
    KL_LOG("delegate=%{public}@ class=%{public}@", delegate, NSStringFromClass([delegate class]));

    // Visible diagnostic — if the user sees this toast when opening Settings,
    // our hook IS firing and the bug is purely in section rendering.
    Class toastCls = %c(YTToastResponderEvent);
    if (toastCls && delegate) {
        NSString *msg = [NSString stringWithFormat:@"kai-lite Settings hook fired (delegate=%@)", NSStringFromClass([delegate class])];
        [[toastCls eventWithMessage:msg firstResponder:delegate] send];
    }

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
        KL_LOG("updateSectionForCategory category=%lu (OURS)", (unsigned long)category);
        [self updateKaiLiteSectionWithEntry:entry];
        return;
    }
    %orig;
}

%end

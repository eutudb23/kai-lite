#import "Tweak.h"
#import <YouTubeHeader/YTSettingsGroupData.h>

// Temporary diagnostic logging — remove once Settings.x section appears.
#define KL_LOG(fmt, ...) NSLog(@"[kai-lite] " fmt, ##__VA_ARGS__)

%hook YTSettingsGroupData
- (NSArray<NSNumber *> *)orderedCategories {
    NSArray *orig = %orig;
    KL_LOG(@"orderedCategories: self.type=%ld orig.count=%lu hasTweaksMethod=%d",
        (long)self.type, (unsigned long)orig.count,
        class_getClassMethod(objc_getClass("YTSettingsGroupData"), @selector(tweaks)) != NULL);
    if (self.type != 1 || class_getClassMethod(objc_getClass("YTSettingsGroupData"), @selector(tweaks)))
        return orig;
    NSMutableArray *mutable = [orig mutableCopy];
    if (![mutable containsObject:@(KaiLiteSection)])
        [mutable addObject:@(KaiLiteSection)];
    KL_LOG(@"orderedCategories: returning %@", mutable);
    return [mutable copy];
}
%end

%hook YTAppSettingsPresentationData
+ (NSArray *)settingsCategoryOrder {
    NSArray *order = %orig;
    KL_LOG(@"settingsCategoryOrder: orig=%@", order);
    NSMutableArray *mutable = [order mutableCopy];
    NSUInteger insertIndex = [order indexOfObject:@(1)];
    if (insertIndex != NSNotFound) {
        [mutable insertObject:@(KaiLiteSection) atIndex:insertIndex + 1];
    } else {
        [mutable addObject:@(KaiLiteSection)];
    }
    return mutable;
}
%end

%hook YTSettingsSectionItemManager

%new
- (YTSettingsSectionItem *)kl_switchWithTitle:(NSString *)title key:(NSString *)key {
    NSString *titleDesc = [NSString stringWithFormat:@"%@Desc", title];
    return [%c(YTSettingsSectionItem)
        switchItemWithTitle:LOC(title)
           titleDescription:LOC(titleDesc)
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
    KL_LOG(@"updateKaiLiteSectionWithEntry FIRED entry=%@", entry);
    NSMutableArray<YTSettingsSectionItem *> *items = [NSMutableArray array];
    // Current YouTube exposes the settings view controller via _dataDelegate.
    // Older builds called it _settingsViewControllerDelegate — fall back if the
    // primary key returns nil so the tweak works across versions.
    YTSettingsViewController *settingsVC = [self valueForKey:@"_dataDelegate"];
    if (!settingsVC) settingsVC = [self valueForKey:@"_settingsViewControllerDelegate"];
    KL_LOG(@"updateKaiLiteSectionWithEntry settingsVC=%@ (class=%@)", settingsVC, NSStringFromClass([settingsVC class]));

    // Top-level: SponsorBlock entry (pushes a picker with the sub-settings).
    YTSettingsSectionItem *sponsor = [%c(YTSettingsSectionItem)
        itemWithTitle:LOC(@"SponsorBlock")
     titleDescription:LOC(@"SponsorBlockDesc")
accessibilityIdentifier:@"KaiLiteSectionItem"
      detailTextBlock:^NSString *() { return klBool(@"sponsorBlock") ? @"On" : @"Off"; }
          selectBlock:^BOOL(YTSettingsCell *cell, NSUInteger arg1) {
              NSMutableArray<YTSettingsSectionItem *> *rows = [NSMutableArray array];

              [rows addObject:[self kl_switchWithTitle:@"Enabled" key:@"sponsorBlock"]];

              // Categories: one switch per SponsorBlock category.
              [rows addObject:[%c(YTSettingsSectionItem)
                  itemWithTitle:LOC(@"Categories")
               titleDescription:LOC(@"CategoriesDesc")
          accessibilityIdentifier:@"KaiLiteSectionItem"
                detailTextBlock:nil
                    selectBlock:^BOOL(YTSettingsCell *cell2, NSUInteger arg2) {
                        NSMutableArray<YTSettingsSectionItem *> *catRows = [NSMutableArray array];
                        for (NSString *cat in KLSponsorCategoriesList()) {
                            NSString *titleKey = [@"Cat_" stringByAppendingString:cat];
                            NSString *prefKey  = [@"sb_cat_" stringByAppendingString:cat];
                            [catRows addObject:[self kl_switchWithTitle:titleKey key:prefKey]];
                        }
                        YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc]
                            initWithNavTitle:LOC(@"Categories")
                          pickerSectionTitle:nil
                                        rows:catRows
                           selectedItemIndex:NSNotFound
                             parentResponder:[self parentResponder]];
                        [settingsVC pushViewController:picker];
                        return YES;
                    }]];

              YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc]
                  initWithNavTitle:LOC(@"SponsorBlock")
                pickerSectionTitle:nil
                              rows:rows
                 selectedItemIndex:NSNotFound
                   parentResponder:[self parentResponder]];
              [settingsVC pushViewController:picker];
              return YES;
          }];

    [items addObject:sponsor];

    // Future kai-lite features land in this section as additional items.

    BOOL isNew = [settingsVC respondsToSelector:@selector(setSectionItems:forCategory:title:icon:titleDescription:headerHidden:)];
    if (isNew) {
        [settingsVC setSectionItems:items forCategory:KaiLiteSection title:LOC(@"KaiLite") icon:nil titleDescription:nil headerHidden:NO];
    } else {
        [settingsVC setSectionItems:items forCategory:KaiLiteSection title:LOC(@"KaiLite") titleDescription:nil headerHidden:NO];
    }
}

- (void)updateSectionForCategory:(NSUInteger)category withEntry:(id)entry {
    if (category == KaiLiteSection) {
        KL_LOG(@"updateSectionForCategory: category=%lu (OURS)", (unsigned long)category);
        [self updateKaiLiteSectionWithEntry:entry];
        return;
    }
    KL_LOG(@"updateSectionForCategory: category=%lu (skipping)", (unsigned long)category);
    %orig;
}

%end

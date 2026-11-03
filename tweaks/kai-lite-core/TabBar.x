#import "Tweak.h"
#import "TabBar.h"
#import <YouTubeHeader/YTIPivotBarRenderer.h>
#import <YouTubeHeader/YTIPivotBarSupportedRenderers.h>
#import <YouTubeHeader/YTIPivotBarItemRenderer.h>
#import <YouTubeHeader/YTIPivotBarIconOnlyItemRenderer.h>
#import <YouTubeHeader/YTIBrowseRequest.h>
#import <YouTubeHeader/YTIcon.h>

@interface KLTabBarRefresher : NSObject
- (void)refreshPivotBar;
@end

static NSString *const KLTabOrderKey = @"tabOrder";

static NSArray<NSString *> *KLKnownTabs(void) {
    return @[@"FEwhat_to_watch", @"FEshorts", @"FEuploads", @"FEsubscriptions", @"FElibrary"];
}

NSArray<NSString *> *KLTabOrder(void) {
    NSArray<NSString *> *saved = [[KLUserDefaults standardUserDefaults] arrayForKey:KLTabOrderKey];
    NSMutableArray<NSString *> *order = [NSMutableArray array];
    for (id identifier in saved) {
        if ([identifier isKindOfClass:[NSString class]] &&
            [KLKnownTabs() containsObject:identifier] && ![order containsObject:identifier]) {
            [order addObject:identifier];
        }
    }
    for (NSString *identifier in KLKnownTabs()) {
        if (![order containsObject:identifier]) [order addObject:identifier];
    }
    return order;
}

static NSString *KLVisibilityKey(NSString *identifier) {
    return [@"tabVisible_" stringByAppendingString:identifier];
}

BOOL KLTabIsVisible(NSString *identifier) {
    if ([identifier isEqualToString:@"FEwhat_to_watch"]) return YES;
    return [[KLUserDefaults standardUserDefaults] objectForKey:KLVisibilityKey(identifier)] == nil ||
           [[KLUserDefaults standardUserDefaults] boolForKey:KLVisibilityKey(identifier)];
}

void KLSetTabVisible(NSString *identifier, BOOL visible) {
    if (![KLKnownTabs() containsObject:identifier] || [identifier isEqualToString:@"FEwhat_to_watch"]) return;
    [[KLUserDefaults standardUserDefaults] setBool:visible forKey:KLVisibilityKey(identifier)];
    KLRefreshTabBar();
}

void KLMoveTab(NSString *identifier, NSInteger offset) {
    NSMutableArray<NSString *> *order = [KLTabOrder() mutableCopy];
    NSUInteger index = [order indexOfObject:identifier];
    if (index == NSNotFound || (offset < 0 && index == 0) ||
        (offset > 0 && index + 1 >= order.count)) return;
    NSUInteger destination = offset < 0 ? index - 1 : index + 1;
    [order exchangeObjectAtIndex:index withObjectAtIndex:destination];
    [[KLUserDefaults standardUserDefaults] setObject:order forKey:KLTabOrderKey];
    KLRefreshTabBar();
}

void KLRefreshTabBar(void) {
    Class headerClass = NSClassFromString(@"YTHeaderContentComboViewController");
    KLTabBarRefresher *controller = [[headerClass alloc] init];
    if ([controller respondsToSelector:@selector(refreshPivotBar)]) {
        [controller refreshPivotBar];
    }
}

static NSString *KLPivotIdentifier(YTIPivotBarSupportedRenderers *item) {
    NSString *identifier = item.pivotBarItemRenderer.pivotIdentifier;
    if (identifier.length == 0) identifier = item.pivotBarIconOnlyItemRenderer.pivotIdentifier;
    return identifier;
}

static void KLApplyTabBarRenderer(YTIPivotBarRenderer *renderer) {
    NSMutableArray<YTIPivotBarSupportedRenderers *> *items = [renderer itemsArray];
    if (![items isKindOfClass:[NSMutableArray class]]) return;

    // YouTube can omit Subscriptions from its server-provided bar. Add it once
    // when enabled, using the same browse-tab factory used by YTLite for Explore.
    BOOL hasSubscriptions = NO;
    for (YTIPivotBarSupportedRenderers *item in items) {
        if ([KLPivotIdentifier(item) isEqualToString:@"FEsubscriptions"]) {
            hasSubscriptions = YES;
            break;
        }
    }
    if (!hasSubscriptions && KLTabIsVisible(@"FEsubscriptions") &&
        [%c(YTIBrowseRequest) respondsToSelector:@selector(browseIDForSubscriptionsTab)] &&
        [%c(YTIPivotBarRenderer) respondsToSelector:@selector(pivotSupportedRenderersWithBrowseId:title:iconType:)]) {
        NSString *browseID = [%c(YTIBrowseRequest) browseIDForSubscriptionsTab];
        if (browseID.length > 0) {
            YTIPivotBarSupportedRenderers *subscriptions =
                [%c(YTIPivotBarRenderer) pivotSupportedRenderersWithBrowseId:browseID
                    title:LOC(@"SubscriptionsTab") iconType:1013];
            if (subscriptions.pivotBarItemRenderer) {
                subscriptions.pivotBarItemRenderer.pivotIdentifier = @"FEsubscriptions";
            }
            if (subscriptions) [items addObject:subscriptions];
        }
    }

    NSIndexSet *hidden = [items indexesOfObjectsPassingTest:^BOOL(YTIPivotBarSupportedRenderers *item, NSUInteger index, BOOL *stop) {
        NSString *identifier = KLPivotIdentifier(item);
        return identifier != nil && !KLTabIsVisible(identifier);
    }];
    if (hidden.count > 0) [items removeObjectsAtIndexes:hidden];

    // Preserve YouTube's ordering until the user explicitly moves a tab.
    if ([[KLUserDefaults standardUserDefaults] objectForKey:KLTabOrderKey] != nil) {
        NSArray<NSString *> *order = KLTabOrder();
        NSMutableArray<YTIPivotBarSupportedRenderers *> *knownItems = [NSMutableArray array];
        NSMutableIndexSet *knownIndexes = [NSMutableIndexSet indexSet];
        [items enumerateObjectsUsingBlock:^(YTIPivotBarSupportedRenderers *item, NSUInteger index, BOOL *stop) {
            if ([order containsObject:KLPivotIdentifier(item)]) {
                [knownItems addObject:item];
                [knownIndexes addIndex:index];
            }
        }];
        [knownItems sortUsingComparator:^NSComparisonResult(YTIPivotBarSupportedRenderers *a, YTIPivotBarSupportedRenderers *b) {
            NSUInteger first = [order indexOfObject:KLPivotIdentifier(a)];
            NSUInteger second = [order indexOfObject:KLPivotIdentifier(b)];
            return first < second ? NSOrderedAscending : (first > second ? NSOrderedDescending : NSOrderedSame);
        }];
        __block NSUInteger knownIndex = 0;
        [knownIndexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
            items[index] = knownItems[knownIndex++];
        }];
    }
}

%hook YTPivotBarView
- (void)setRenderer:(YTIPivotBarRenderer *)renderer {
    KLApplyTabBarRenderer(renderer);
    %orig;
}
%end

%hook YTFloatingPivotBarView
- (void)setRenderer:(YTIPivotBarRenderer *)renderer {
    KLApplyTabBarRenderer(renderer);
    %orig;
}
%end

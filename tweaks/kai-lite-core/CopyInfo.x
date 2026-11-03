#import "Tweak.h"

@interface YTEngagementPanelView : UIView
@end

static id KLSafeValue(id object, NSString *key) {
    if (object == nil) return nil;
    @try { return [object valueForKey:key]; }
    @catch (NSException *exception) { return nil; }
}

static NSString *KLVideoInfoString(id object, NSString *key) {
    id value = KLSafeValue(object, key);
    return [value isKindOfClass:NSString.class] ? value : nil;
}

%hook YTEngagementPanelView

- (void)layoutSubviews {
    %orig;

    UIView *header = KLSafeValue(self, @"headerView");
    if (![header isKindOfClass:UIView.class]) return;
    UIView *existing = [header viewWithTag:923401];
    NSString *identifier = KLVideoInfoString(KLSafeValue(self, @"panelIdentifier"), @"identifierString");
    if (![identifier isEqualToString:@"video-description-ep-identifier"]) {
        [existing removeFromSuperview];
        return;
    }
    if (existing != nil) return;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = 923401;
    button.accessibilityLabel = LOC(@"CopyVideoInfo");
    button.accessibilityIdentifier = @"KaiLiteCopyVideoInfo";
    [button setImage:[UIImage systemImageNamed:@"doc.on.doc"] forState:UIControlStateNormal];
    [button addTarget:self action:@selector(kl_copyVideoInfo:) forControlEvents:UIControlEventTouchUpInside];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:button];
    [NSLayoutConstraint activateConstraints:@[
        [button.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-48],
        [button.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [button.widthAnchor constraintEqualToConstant:40],
        [button.heightAnchor constraintEqualToConstant:40],
    ]];
}

%new(v@:@)
- (void)kl_copyVideoInfo:(UIButton *)sender {
    id resizeDelegate = KLSafeValue(self, @"resizeDelegate");
    id controller = resizeDelegate;
    for (NSUInteger i = 0; i < 3; i++) controller = KLSafeValue(controller, @"parentViewController");
    id player = KLSafeValue(controller, @"playerViewController");
    id videoDetails = KLSafeValue(KLSafeValue(KLSafeValue(player, @"playerResponse"), @"playerData"), @"videoDetails");
    NSString *title = KLVideoInfoString(videoDetails, @"title");
    NSString *description = KLVideoInfoString(videoDetails, @"shortDescription");
    if (title.length == 0 && description.length == 0) return;

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:LOC(@"CopyVideoInfo")
        message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    if (title.length > 0) {
        [sheet addAction:[UIAlertAction actionWithTitle:LOC(@"CopyTitle") style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            UIPasteboard.generalPasteboard.string = title;
        }]];
    }
    if (description.length > 0) {
        [sheet addAction:[UIAlertAction actionWithTitle:LOC(@"CopyDescription") style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            UIPasteboard.generalPasteboard.string = description;
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:LOC(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    UIViewController *presenter = [resizeDelegate isKindOfClass:UIViewController.class] ? resizeDelegate : nil;
    if (presenter == nil) {
        UIResponder *responder = self;
        while (responder != nil && ![responder isKindOfClass:UIViewController.class]) responder = responder.nextResponder;
        presenter = (UIViewController *)responder;
    }
    if (presenter == nil) return;
    sheet.popoverPresentationController.sourceView = sender;
    sheet.popoverPresentationController.sourceRect = sender.bounds;
    [presenter presentViewController:sheet animated:YES completion:nil];
}

%end

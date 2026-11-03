#import "V2Bridge.h"
#import <dlfcn.h>

typedef UIViewController *(*KLMakeV2Page)(NSString *);

@interface KLFeatureNavigationController : UINavigationController
- (void)kl_dismiss;
@end

@implementation KLFeatureNavigationController
- (void)kl_dismiss {
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end

BOOL KLHasV2Features(void) {
    return dlsym(RTLD_DEFAULT, "YTKACEMakeSettingsPage") != NULL;
}

BOOL KLOpenV2Page(NSString *pageID, UIViewController *presenter) {
    KLMakeV2Page makePage = (KLMakeV2Page)dlsym(RTLD_DEFAULT, "YTKACEMakeSettingsPage");
    if (makePage == NULL || presenter == nil) return NO;
    UIViewController *page = makePage(pageID);
    if (page == nil) return NO;
    KLFeatureNavigationController *navigation =
        [[KLFeatureNavigationController alloc] initWithRootViewController:page];
    page.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone
        target:navigation action:@selector(kl_dismiss)];
    [presenter presentViewController:navigation animated:YES completion:nil];
    return YES;
}

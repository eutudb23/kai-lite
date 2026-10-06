#import "NSBundle+KL.h"

@implementation NSBundle (KL)

+ (NSBundle *)kl_defaultBundle {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        NSString *embeddedPath = [[NSBundle mainBundle] pathForResource:@"KaiLiteCore" ofType:@"bundle"];
        NSString *installedPath = ROOT_PATH_NS(@"/Library/Application Support/KaiLiteCore.bundle");
        bundle = [NSBundle bundleWithPath:embeddedPath ?: installedPath];
    });

    return bundle;
}

@end

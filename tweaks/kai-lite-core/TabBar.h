#import <Foundation/Foundation.h>

// Stable pivot identifiers are stored instead of positions so YouTube can add
// tabs without changing the meaning of an existing preference.
NSArray<NSString *> *KLTabOrder(void);
BOOL KLTabIsVisible(NSString *identifier);
void KLSetTabVisible(NSString *identifier, BOOL visible);
void KLMoveTab(NSString *identifier, NSInteger offset);
void KLRefreshTabBar(void);

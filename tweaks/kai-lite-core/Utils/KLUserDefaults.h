#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KLUserDefaults : NSUserDefaults

@property (class, readonly, strong) KLUserDefaults *standardUserDefaults;

@end

NS_ASSUME_NONNULL_END

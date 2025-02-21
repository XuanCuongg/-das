#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface API : NSObject

- (void)paid:(void (^)(void))completion;
// Khai báo phương thức Login để hiển thị cửa sổ nhập key
- (void)Login;
//+ (void)setGameCode:(NSString *)gameCode;
+ (void)setGameCode:(NSString *)newGameCode;

@end

NS_ASSUME_NONNULL_END

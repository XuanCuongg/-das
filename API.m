#import <UIKit/UIKit.h>
#import "API.h"

@interface API()
@property (nonatomic, strong) UIWindow *mainWindow99; // Khai báo biến trong phần interface
@end

@implementation API
static BOOL MenDeal;
static API *extraInfo;
BOOL isKeyEntered = NO;

- (void)paid:(void (^)(void))completion {
    if (completion) {
        completion();
    }
}

- (void)Login {
    NSString *savedKey = [[NSUserDefaults standardUserDefaults] objectForKey:@"savedKey"];
    if(savedKey){
        [self doSomethingWithKey:savedKey];
    } else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(45 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!isKeyEntered) {
                exit(0);
            }
        });
        UIAlertController *alertCtrl = [UIAlertController alertControllerWithTitle:@"Đăng nhập"
                                                                           message:@"Hoàng Nguyễn"
                                                                    preferredStyle:UIAlertControllerStyleAlert];

        [alertCtrl addTextFieldWithConfigurationHandler:^(UITextField *textField) {
            textField.placeholder = @"Nhập Key:";
        }];

        UIAlertAction *loginAction = [UIAlertAction actionWithTitle:@"Xác nhận"
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *action) {
                                                                UITextField *codeString = alertCtrl.textFields.firstObject;
                                                                [self doSomethingWithKey:codeString.text];
                                                            }];

        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Get Key"
                                                               style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction *action) {
                                                                 [self openZaloLink];
                                                             }];

        [alertCtrl addAction:loginAction];
        [alertCtrl addAction:cancelAction];

        UIViewController *rootViewController = [[UIApplication sharedApplication].keyWindow rootViewController];
        [rootViewController presentViewController:alertCtrl animated:YES completion:nil];
    }
}

- (NSString *)getUDID {
    NSString *udid = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    return udid;
}

- (void)doSomethingWithKey:(NSString *)code {
    NSString *udid = [self getUDID];
    NSString *originalString = [NSString stringWithFormat:@"https://server.xuancuong.dev/check_key.php?key=%@&&uuid=%@", code, udid];
    NSData *data = [originalString dataUsingEncoding:NSUTF8StringEncoding];
    NSString *base64String = [data base64EncodedStringWithOptions:0];
    NSLog(@"Encoded string: %@", base64String);

    NSDictionary *postData = @{
        @"code": code,
        @"udid": udid
    };

    NSError *error;
    NSData *postDataJSON = [NSJSONSerialization dataWithJSONObject:postData options:0 error:&error];
    if (error) {
        NSLog(@"Error creating POST data: %@", error.localizedDescription);
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:originalString]];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:postDataJSON];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"Error sending POST request: %@", error.localizedDescription);
            return;
        }

        NSDictionary *responseJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            NSLog(@"Error parsing JSON response: %@", error.localizedDescription);
            return;
        }

        NSDictionary *immutableResponseJSON = [NSDictionary dictionaryWithDictionary:responseJSON];
        NSString *type = immutableResponseJSON[@"type"];
        NSString *signature = immutableResponseJSON[@"signature"];
        NSString *messageText = immutableResponseJSON[@"message"];

        if ([type isEqualToString:@"successful"]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *message = [NSString stringWithFormat:@"Thông tin :   %@ - %@" , signature, messageText];
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Thông báo" message:message preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self startCheckingTimer];
                        [self paid:^{
                            NSLog(@"Key is correct. Executing actions after payment...");
                            isKeyEntered = YES;
                            [[NSUserDefaults standardUserDefaults] setObject:code forKey:@"savedKey"];
                            [[NSUserDefaults standardUserDefaults] synchronize];
                        }];
                    });
                }];

                [alertController addAction:okAction];
                UIViewController *viewController = [[UIApplication sharedApplication].keyWindow rootViewController];
                [viewController presentViewController:alertController animated:YES completion:nil];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *message = [NSString stringWithFormat:@"Thông tin : %@ - %@ - %@", type, signature, messageText];
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Thông báo" message:message preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"Thử Lại" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                    [self Login];
                }];
                [alertController addAction:okAction];
                UIViewController *viewController = [[UIApplication sharedApplication].keyWindow rootViewController];
                [viewController presentViewController:alertController animated:YES completion:nil];
            });
        }
    }];
    [dataTask resume];
}

- (void)checkSavedKey {
    NSString *savedKey = [[NSUserDefaults standardUserDefaults] objectForKey:@"savedKey"];
    if (savedKey) {
        [self doSomethingWithKey:savedKey];
    }
}

- (void)startCheckingTimer {
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:100.0
                                                      target:self
                                                    selector:@selector(checkSavedKey)
                                                    userInfo:nil
                                                     repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

- (void)openZaloLink {
    NSURL *zaloURL = [NSURL URLWithString:@"https://xuancuong.dev"];
    [[UIApplication sharedApplication] openURL:zaloURL options:@{} completionHandler:^(BOOL success) {
        if (success) {
            exit(0);
        }
    }];
}

@end

//
//  AdbCallback.m
//  实现 adb-mobile 要求的状态回调（弱符号覆盖），转发给 Swift 层
//
#import <Foundation/Foundation.h>
#import "adb_public.h"

// adb-mobile 在连接状态变化时调用（serial 如 "192.168.1.5:5555"，status 如 device/offline/connecting/authorizing/unauthorized）
void adb_connect_status_updated(const char *serial, const char *status) {
    NSString *s = serial ? [NSString stringWithUTF8String:serial] : @"";
    NSString *st = status ? [NSString stringWithUTF8String:status] : @"";
    NSDictionary *info = @{ @"serial": s, @"status": st };
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ADBConnectStatusChanged"
                                                            object:nil
                                                          userInfo:info];
    });
}

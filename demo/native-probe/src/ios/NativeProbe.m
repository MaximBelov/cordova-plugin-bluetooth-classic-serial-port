#import <Cordova/CDVPlugin.h>
#import <ExternalAccessory/ExternalAccessory.h>
#import <CoreBluetooth/CoreBluetooth.h>

// Demo only. The system accessory picker asked for straight from Objective-C, with none of the plugin's code: when this shows the
// popup and the plugin's `discoverUnpaired` does not, the fault is in the plugin or in what the app does around it, not in iOS.
@interface NativeProbe : CDVPlugin
- (void)show:(CDVInvokedUrlCommand *)command;
- (void)state:(CDVInvokedUrlCommand *)command;
@end

@implementation NativeProbe

- (void)show:(CDVInvokedUrlCommand *)command {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDate *started = [NSDate date];
        [[EAAccessoryManager sharedAccessoryManager] showBluetoothAccessoryPickerWithNameFilter:nil completion:^(NSError *error) {
            NSDictionary *answer = @{
                @"seconds": @(-[started timeIntervalSinceNow]),
                @"domain": error.domain ?: [NSNull null],
                @"code": error ? @(error.code) : [NSNull null],
                @"description": error.localizedDescription ?: [NSNull null]
            };
            [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:answer] callbackId:command.callbackId];
        }];
    });
}

// Which window the application delegate and the key window are: the picker presents in the delegate's.
- (void)state:(CDVInvokedUrlCommand *)command {
    id<UIApplicationDelegate> delegate = [UIApplication sharedApplication].delegate;
    BOOL hasWindow = [delegate respondsToSelector:@selector(window)];
    NSDictionary *answer = @{
        @"delegate": NSStringFromClass([(NSObject *)delegate class]),
        @"delegateHasWindowProperty": @(hasWindow),
        @"delegateWindow": hasWindow && delegate.window ? NSStringFromClass([delegate.window class]) : [NSNull null],
        @"keyWindow": self.viewController.view.window ? NSStringFromClass([self.viewController.view.window class]) : [NSNull null]
    };
    [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:answer] callbackId:command.callbackId];
}

@end

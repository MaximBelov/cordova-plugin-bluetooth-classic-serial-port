#import <XCTest/XCTest.h>
#import <ExternalAccessory/ExternalAccessory.h>
#import "BluetoothClassicSerial.h"

#pragma mark - Fakes

/// A picker that answers what the test says, as iOS would: nil, or an error with one of the EABluetoothAccessoryPicker codes.
@interface FakeAccessoryPicker : NSObject <BluetoothClassicAccessoryPicker>
@property (nonatomic) NSInteger resultCode; // -1: no error
@property (nonatomic) NSUInteger shown;
@property (nonatomic) BOOL shownOnMainThread;
@end

@implementation FakeAccessoryPicker
- (void)showPickerWithCompletion:(void (^)(NSError *))completion {
    self.shown++;
    self.shownOnMainThread = [NSThread isMainThread];
    completion(self.resultCode < 0 ? nil : [NSError errorWithDomain:EABluetoothAccessoryPickerErrorDomain code:self.resultCode userInfo:nil]);
}
@end

/// Records what the plugin sends to JavaScript.
@interface RecordingCommandDelegate : NSObject <CDVCommandDelegate>
@property (nonatomic, strong) NSMutableArray<CDVPluginResult *> *results;
@property (nonatomic, strong) XCTestExpectation *answered;
@end

@implementation RecordingCommandDelegate
- (instancetype)init {
    if ((self = [super init])) { _results = [NSMutableArray array]; }
    return self;
}
- (void)sendPluginResult:(CDVPluginResult *)result callbackId:(NSString *)callbackId {
    [self.results addObject:result];
    [self.answered fulfill];
}
// Everything else of the protocol is unused by these tests.
- (NSString *)pathForResource:(NSString *)resourcepath { return nil; }
- (id)getCommandInstance:(NSString *)pluginName { return nil; }
- (void)evalJs:(NSString *)js {}
- (void)evalJs:(NSString *)js scheduledOnRunLoop:(BOOL)scheduledOnRunLoop {}
- (void)runInBackground:(void (^)(void))block { block(); }
- (NSString *)userAgent { return @""; }
- (BOOL)URLIsWhitelisted:(NSURL *)url { return YES; }
- (NSDictionary *)settings { return @{}; }
@end

/// An application delegate the way Cordova's CDVAppDelegate is: it has a `window` property, which starts out nil.
@interface DelegateWithWindow : NSObject <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation DelegateWithWindow
@end

/// An application delegate with no `window` property at all.
@interface DelegateWithoutWindow : NSObject <UIApplicationDelegate>
@end
@implementation DelegateWithoutWindow
@end

#pragma mark - Tests

@interface BluetoothClassicSerialTests : XCTestCase
@end

@implementation BluetoothClassicSerialTests

- (NSError *)pickerError:(NSInteger)code {
    return [NSError errorWithDomain:EABluetoothAccessoryPickerErrorDomain code:code userInfo:nil];
}

// MARK: failureMessageForPickerError

- (void)testPickerResultsMapToTheMessagesJavaScriptSees {
    XCTAssertEqualObjects([BluetoothClassicSerial failureMessageForPickerError:[self pickerError:EABluetoothAccessoryPickerResultCancelled]], @"Cancelled");
    XCTAssertEqualObjects([BluetoothClassicSerial failureMessageForPickerError:[self pickerError:EABluetoothAccessoryPickerResultNotFound]], @"Device not found");
    XCTAssertEqualObjects([BluetoothClassicSerial failureMessageForPickerError:[self pickerError:EABluetoothAccessoryPickerResultFailed]], @"Device selection failed");
}

- (void)testASelectionAndAnAlreadyConnectedDeviceAreNoFailure {
    XCTAssertNil([BluetoothClassicSerial failureMessageForPickerError:nil]);
    XCTAssertNil([BluetoothClassicSerial failureMessageForPickerError:[self pickerError:EABluetoothAccessoryPickerAlreadyConnected]]);
}

// MARK: giveDelegate:theWindow:

- (void)testADelegateWithoutAWindowIsGivenOne {
    DelegateWithWindow *delegate = [[DelegateWithWindow alloc] init];
    UIWindow *window = [[UIWindow alloc] init];
    XCTAssertTrue([BluetoothClassicSerial giveDelegate:delegate theWindow:window]);
    XCTAssertEqual(delegate.window, window);
}

- (void)testADelegateThatHasAWindowKeepsIt {
    DelegateWithWindow *delegate = [[DelegateWithWindow alloc] init];
    UIWindow *own = [[UIWindow alloc] init];
    delegate.window = own;
    XCTAssertFalse([BluetoothClassicSerial giveDelegate:delegate theWindow:[[UIWindow alloc] init]]);
    XCTAssertEqual(delegate.window, own);
}

- (void)testADelegateWithNoWindowPropertyIsLeftAlone {
    XCTAssertFalse([BluetoothClassicSerial giveDelegate:[[DelegateWithoutWindow alloc] init] theWindow:[[UIWindow alloc] init]]);
}

- (void)testNothingIsGivenWhenThereIsNoWindowToGive {
    DelegateWithWindow *delegate = [[DelegateWithWindow alloc] init];
    XCTAssertFalse([BluetoothClassicSerial giveDelegate:delegate theWindow:nil]);
    XCTAssertNil(delegate.window);
    XCTAssertFalse([BluetoothClassicSerial giveDelegate:nil theWindow:[[UIWindow alloc] init]]);
}

// MARK: discoverUnpaired

/// Runs discoverUnpaired with a picker that answers `code` (-1 for none) and returns what the plugin sent to JavaScript.
- (RecordingCommandDelegate *)discoverUnpairedAnswering:(NSInteger)code picker:(FakeAccessoryPicker **)pickerOut {
    FakeAccessoryPicker *picker = [[FakeAccessoryPicker alloc] init];
    picker.resultCode = code;
    RecordingCommandDelegate *delegate = [[RecordingCommandDelegate alloc] init];
    delegate.answered = [self expectationWithDescription:@"discoverUnpaired answered"];
    BluetoothClassicSerial *plugin = [[BluetoothClassicSerial alloc] init];
    plugin.accessoryPicker = picker;
    plugin.commandDelegate = delegate;
    CDVInvokedUrlCommand *command = [[CDVInvokedUrlCommand alloc] initWithArguments:@[] callbackId:@"cb" className:@"BluetoothClassicSerial" methodName:@"discoverUnpaired"];
    // The command arrives on a background queue, as Cordova's do.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{ [plugin discoverUnpaired:command]; });
    [self waitForExpectations:@[delegate.answered] timeout:5];
    if (pickerOut) { *pickerOut = picker; }
    return delegate;
}

- (void)assertFailure:(NSString *)message whenThePickerAnswers:(NSInteger)code {
    FakeAccessoryPicker *picker = nil;
    RecordingCommandDelegate *delegate = [self discoverUnpairedAnswering:code picker:&picker];
    XCTAssertEqual(delegate.results.count, 1u);
    XCTAssertEqual(delegate.results.firstObject.status.intValue, CDVCommandStatus_ERROR);
    XCTAssertEqualObjects(delegate.results.firstObject.message, message);
    XCTAssertTrue(picker.shownOnMainThread, @"the picker is a UIKit presentation");
}

- (void)testCancellingAnswersCancelled {
    [self assertFailure:@"Cancelled" whenThePickerAnswers:EABluetoothAccessoryPickerResultCancelled];
}

- (void)testNoDeviceFoundAnswersDeviceNotFound {
    [self assertFailure:@"Device not found" whenThePickerAnswers:EABluetoothAccessoryPickerResultNotFound];
}

- (void)testAFailedSelectionAnswersDeviceSelectionFailed {
    [self assertFailure:@"Device selection failed" whenThePickerAnswers:EABluetoothAccessoryPickerResultFailed];
}

- (void)testASelectionAnswersTheConnectedAccessories {
    FakeAccessoryPicker *picker = nil;
    RecordingCommandDelegate *delegate = [self discoverUnpairedAnswering:-1 picker:&picker];
    XCTAssertEqual(delegate.results.count, 1u);
    XCTAssertEqual(delegate.results.firstObject.status.intValue, CDVCommandStatus_OK);
    XCTAssertTrue([delegate.results.firstObject.message isKindOfClass:[NSArray class]]);
}

// The call that used to hang: Apple reports a device that is connected already as an error and gives no accessory.
- (void)testADeviceThatIsConnectedAlreadyIsAnsweredToo {
    FakeAccessoryPicker *picker = nil;
    RecordingCommandDelegate *delegate = [self discoverUnpairedAnswering:EABluetoothAccessoryPickerAlreadyConnected picker:&picker];
    XCTAssertEqual(delegate.results.count, 1u);
    XCTAssertEqual(delegate.results.firstObject.status.intValue, CDVCommandStatus_OK);
}

@end

#import "CommunicationSession.h"

@implementation CommunicationSession

- (id)init:(EAAccessory *)accessory :(NSString *)protocolString :(id <CDVCommandDelegate>)commandDelegate  {
    self = [super init];
    if (self) {
        self.accessory = accessory;
        self.protocolString = protocolString;
        self.connectionId = accessory.connectionID;
        self.notificationName = [NSString stringWithFormat:@"BTSubscribe_%lu_%@", (unsigned long)self.connectionId, self.protocolString];
        self.commandDelegate = commandDelegate;
        self.connectCallbackId = nil;
        self.writeBuffer = nil;
        self.readBuffer = nil;
        self.subscribeCallbackId = nil;
        self.readDelimiter = nil;
        self.subscribeRawDataCallbackId = nil;
        self.inputBufferSize = 128;
    }
    return self;
}

- (void)removeSubscribeObserver {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:self.notificationName object:nil];
}

- (void)addSubscribeCallbackAndObserver:(NSString *)subscribeCallbackId withDelimiter:(NSString *)delimiter {
    [self removeSubscribeObserver];
    self.subscribeCallbackId = subscribeCallbackId;
    self.readDelimiter = delimiter;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sendSubscribeData:) name:self.notificationName object:nil];
}

- (void)sendSubscribeData:(NSNotification *)notification {
    if (self.subscribeCallbackId != nil && self.readDelimiter != nil) {
        NSString *message = [self readUntilDelimiter:self.readDelimiter];
        if ([message length] > 0) {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:message];
            [pluginResult setKeepCallbackAsBool:TRUE];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:self.subscribeCallbackId];

            // Fire again to consume any remaining delimited data
            [self sendSubscribeData:nil];
        }
    }
}

- (void)unsubscribe {
    if (self.subscribeCallbackId != nil) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.subscribeCallbackId];
    }
    self.subscribeCallbackId = nil;
    self.readDelimiter = nil;
    [self removeSubscribeObserver];
}

- (void)unsubscribeRaw {
    if (self.subscribeRawDataCallbackId != nil) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.subscribeRawDataCallbackId];
    }
    self.subscribeRawDataCallbackId = nil;
}

- (void)subscribeRaw:(NSString *)callbackId {
    self.subscribeRawDataCallbackId = callbackId;
}

- (bool)open {
    self.session = [[EASession alloc] initWithAccessory:self.accessory forProtocol:self.protocolString];
    if (self.session) {
        [[self.session inputStream] setDelegate:self];
        [[self.session inputStream] scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [[self.session inputStream] open];

        [[self.session outputStream] setDelegate:self];
        [[self.session outputStream] scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [[self.session outputStream] open];
        return true;
    } else {
        return false;
    }
}

- (void)close {
    if (self.session != nil) {
        [[self.session inputStream] removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [[self.session inputStream] setDelegate:nil];
        [[self.session inputStream] close];

        [[self.session outputStream] removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [[self.session outputStream] setDelegate:nil];
        [[self.session outputStream] close];

        self.session = nil;
    }

    self.readBuffer = nil;
    self.writeBuffer = nil;

    if (self.connectCallbackId != nil) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Device was manually disconnected"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.connectCallbackId];
        self.connectCallbackId = nil;
    }

    [self unsubscribe];
    [self unsubscribeRaw];
}

- (bool)isOpen {
    return (self.session != nil);
}

- (void)appendToWriteBuffer:(NSData *)data {
    if (self.writeBuffer == nil) {
        self.writeBuffer = [[NSMutableData alloc] init];
    }
    [self.writeBuffer appendData:data];
}

- (bool)writeData {
    while (([[self.session outputStream] hasSpaceAvailable]) && ([self.writeBuffer length] > 0)) {
        NSInteger bytesWritten = [[self.session outputStream] write:[self.writeBuffer bytes] maxLength:[self.writeBuffer length]];
        if (bytesWritten == -1) {
            return false;
        } else if (bytesWritten > 0) {
            [self.writeBuffer replaceBytesInRange:NSMakeRange(0, bytesWritten) withBytes:NULL length:0];
        }
    }
    return true;
}

- (NSData *)readBytesFromBuffer:(NSUInteger)bytesToRead {
    NSData *data = nil;
    if ([self.readBuffer length] >= bytesToRead) {
        NSRange range = NSMakeRange(0, bytesToRead);
        data = [self.readBuffer subdataWithRange:range];
        [self.readBuffer replaceBytesInRange:range withBytes:NULL length:0];
    }
    return data;
}

- (NSMutableString *)read {
    NSUInteger bytesAvailable = 0;
    NSMutableString *dataOutput = [[NSMutableString alloc] init];

    while ((bytesAvailable = [self.readBuffer length]) > 0) {
        NSData *data = [self readBytesFromBuffer:bytesAvailable];
        if (data) {
            NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (dataString != nil) {
                [dataOutput appendString:dataString];
            }
        }
    }
    return dataOutput;
}

- (NSString *)readUntilDelimiter:(NSString *)delimiter {
    NSString *dataString = [[NSString alloc] initWithData:self.readBuffer encoding:NSUTF8StringEncoding];
    NSRange range = [dataString rangeOfString:delimiter];
    NSString *message = @"";

    if (range.location != NSNotFound) {
        NSUInteger end = range.location + range.length;
        message = [dataString substringToIndex:end];
        NSRange truncate = NSMakeRange(0, end);
        [self.readBuffer replaceBytesInRange:truncate withBytes:NULL length:0];
    }
    return message;
}

- (void)readStreamData {
    NSMutableData *rawDataRead = nil;
    if (self.subscribeRawDataCallbackId != nil) {
        rawDataRead = [[NSMutableData alloc] init];
    }

    uint8_t buf[self.inputBufferSize];
    while ([[self.session inputStream] hasBytesAvailable]) {
        NSInteger bytesRead = [[self.session inputStream] read:buf maxLength:self.inputBufferSize];
        if (self.readBuffer == nil) {
            self.readBuffer = [[NSMutableData alloc] init];
        }
        [self.readBuffer appendBytes:buf length:bytesRead];

        if (self.subscribeRawDataCallbackId != nil) {
            [rawDataRead appendBytes:buf length:bytesRead];
        }
    }

    if (self.subscribeRawDataCallbackId != nil && rawDataRead != nil) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArrayBuffer:rawDataRead];
        [pluginResult setKeepCallbackAsBool:true];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.subscribeRawDataCallbackId];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:self.notificationName object:self userInfo:nil];
}

- (void)clear {
    if (self.session != nil) {
        uint8_t buf[self.inputBufferSize];
        while ([[self.session inputStream] hasBytesAvailable]) {
            [[self.session inputStream] read:buf maxLength:self.inputBufferSize];
        }
    }
    self.readBuffer = nil;
}

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode {
    switch (eventCode) {
        case NSStreamEventErrorOccurred:
        case NSStreamEventEndEncountered: {
            [stream close];
            [stream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
            self.session = nil;
            break;
        }
        case NSStreamEventHasBytesAvailable: {
            [self readStreamData];
            break;
        }
        case NSStreamEventHasSpaceAvailable: {
            [self writeData];
            break;
        }
        default:
            break;
    }
}

@end

#import "BluetoothClassicSerial.h"

@implementation BluetoothClassicSerial

- (void)pluginInitialize {

    // Initialise properties
    self.deviceDiscoveredCallbackId = nil;

    // Initialise base bluetooth settings
    self.bluetoothEnabled = false;

    // State the core bluetooth central manager
    self.bluetoothManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:nil];

    // Initialise array to hold communication sessions
    self.communicationSessions = [[NSMutableArray alloc] init];


    // Register for accessory manager notifications
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(accessoryConnected:) name:EAAccessoryDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(accessoryDisconnected:) name:EAAccessoryDidDisconnectNotification object:nil];
    [[EAAccessoryManager sharedAccessoryManager] registerForLocalNotifications];

}

#pragma mark - Cordova Plugin Methods

- (void)clearDeviceDiscoveredListener:(CDVInvokedUrlCommand *)command {
    self.deviceDiscoveredCallbackId = nil;
}

- (void)setDeviceDiscoveredListener:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
    [pluginResult setKeepCallbackAsBool:true];
    self.deviceDiscoveredCallbackId = command.callbackId;
}

- (void)subscribe:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult;
    NSUInteger connectionId = (NSUInteger)[[command.arguments objectAtIndex:0] integerValue];
    NSString *protocolString = [command.arguments objectAtIndex:1];
    NSString *delimiter = [command.arguments objectAtIndex:2];

    if (delimiter != nil && protocolString != nil) {
        CommunicationSession *session = [self getCommunicationSession:connectionId protocolString:protocolString];
        if (session != nil) {
            [session addSubscribeCallbackAndObserver:command.callbackId withDelimiter:delimiter];
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
            [pluginResult setKeepCallbackAsBool:true];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No matching session found."];
        }
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Subscribe requires parameters: connectionId, protocolString and delimiter."];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}


- (void)unsubscribe:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult;
    NSUInteger connectionId = (NSUInteger)[[command.arguments objectAtIndex:0] integerValue];
    NSString *protocolString = [command.arguments objectAtIndex:1];

    CommunicationSession *session = [self getCommunicationSession:connectionId protocolString:protocolString];
    if(session != nil){
        [session unsubscribe];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)subscribeRaw:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult;
    NSUInteger connectionId = (NSUInteger)[[command.arguments objectAtIndex:0] integerValue];
    NSString *protocolString = [command.arguments objectAtIndex:1];

    if (protocolString != nil) {
        CommunicationSession *session = [self getCommunicationSession:connectionId protocolString:protocolString];
        if (session != nil) {
            [session subscribeRaw:command.callbackId];
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
            [pluginResult setKeepCallbackAsBool:true];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No matching session found."];
        }
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Subscribe raw requires parameters: connectionId and protocolString."];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)unsubscribeRaw:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult;
    NSUInteger connectionId = (NSUInteger)[[command.arguments objectAtIndex:0] integerValue];
    NSString *protocolString = [command.arguments objectAtIndex:1];

    CommunicationSession *session = [self getCommunicationSession:connectionId protocolString:protocolString];
    if(session != nil){
        [session unsubscribeRaw];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)clear:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult;
    NSUInteger connectionId = (NSUInteger)[[command.arguments objectAtIndex:0] integerValue];
    NSString *protocolString = [command.arguments objectAtIndex:1];

    CommunicationSession *session = [self getCommunicationSession:connectionId protocolString:protocolString];
    if(session != nil){
        [session clear];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}


- (void)isEnabled: (CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult;
    [self centralManagerDidUpdateState:self.bluetoothManager];

    if (self.bluetoothEnabled) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:true];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsBool:false];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)isConnected:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult;
    NSUInteger connectionId = (NSUInteger)[[command.arguments objectAtIndex:0] integerValue];
    NSString *protocolString = [command.arguments objectAtIndex:1];

    CommunicationSession *session = [self getCommunicationSession:connectionId protocolString:protocolString];
    EAAccessory *connectionSessionAccessory = [session accessory];

    if (session != nil && [connectionSessionAccessory isConnected]) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:true];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsBool:false];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)disconnect:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult;
    NSUInteger connectionId = (NSUInteger)[[command.arguments objectAtIndex:0] integerValue];
    NSString *protocolString = [command.arguments objectAtIndex:1];

    @try {
        // Close the session with the device
        [self closeCommunicationSession:connectionId protocolString:protocolString];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:true];

    }
    @catch (NSException *e) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsBool:false];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)disconnectAll:(CDVInvokedUrlCommand *)command {

    CDVPluginResult *pluginResult;
    @try {
        for (CommunicationSession *session in self.communicationSessions) {
            [self closeCommunicationSession:[session connectionId] protocolString:[session protocolString]];
        }
        self.communicationSessions = [[NSMutableArray alloc] init];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:true];
    }
    @catch (NSException *e) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsBool:false];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

}

- (void)connect:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult;
    bool inError = false;
    NSMutableDictionary *connectionResult = [[NSMutableDictionary alloc] init];
    NSMutableArray *connectionError = [[NSMutableArray alloc] init];
    NSUInteger connectionId = (NSUInteger)[[command.arguments objectAtIndex:0] integerValue];
    NSArray *protocolStrings = [command.arguments objectAtIndex:1];

    @try {
        connectionResult = [self openCommunicationSession:command];
        NSNumber *status = connectionResult[@"status"];
        if (![status boolValue]) {
            inError = true;
        }
    }
    @catch (NSException *e) {
        // Any errors here then throw the reason
        inError = true;
        [connectionResult setValue:e.reason forKey:@"error"];
    }

    if (inError) {

        // If we're in error just make sure to close any communications sessions that might have opened
        [self closeCommunicationSessions:connectionId protocolStrings:protocolStrings];

        if (connectionId > 0) {
            [connectionResult setValue:[NSNumber numberWithLong:connectionId] forKeyPath:@"id"];
        }
        [connectionResult setValue:protocolStrings forKey:@"protocolStrings"];
        [connectionError insertObject:connectionResult atIndex:0];

        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsArray:connectionError];

    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:true];
        [pluginResult setKeepCallbackAsBool:true];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

}

- (void)discoverUnpaired:(CDVInvokedUrlCommand *)command {

    [[EAAccessoryManager sharedAccessoryManager] showBluetoothAccessoryPickerWithNameFilter:nil completion:^(NSError *error){

        // If the user hits the cancel button on the prompt then return fail.
        if(error != nil &&
           (
            [error code] == EABluetoothAccessoryPickerResultCancelled
            || [error code] == EABluetoothAccessoryPickerResultNotFound
            || [error code] == EABluetoothAccessoryPickerResultFailed
            )
           ) {

            NSString *errorMessage;
            if ([error code] == EABluetoothAccessoryPickerResultCancelled) {
                errorMessage = @"Cancelled";
            } else if ([error code] == EABluetoothAccessoryPickerResultNotFound) {
                errorMessage = @"Device not found";
            } else {
                errorMessage = @"Device selection failed";
            }

            CDVPluginResult *pluginResult;
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMessage];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

        } else {

            bool sendBackList = false;

            // If the device was already connected send back the currently selected accessory.
            if (error != nil && [error code] == EABluetoothAccessoryPickerAlreadyConnected) {

                EAAccessory *accessory;

                for (NSString *protocolString in accessory.protocolStrings ){
                    CommunicationSession *session = [self getCommunicationSession:accessory.connectionID protocolString:protocolString];
                    EAAccessory *connectionSessionAccessory = [session accessory];

                    if (session != nil && [connectionSessionAccessory isConnected]) {
                        NSMutableArray *dictArray = [[NSMutableArray alloc] init];
                        [dictArray insertObject:accessory atIndex:0];
                        NSArray *accessoryDetailsArray = [NSArray arrayWithArray:dictArray];
                        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:accessoryDetailsArray];
                        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                        break;
                    } else {
                        sendBackList = true;
                    }
                }

            }

            if (sendBackList) {
                // Return a list of all devices
                [self list:command];
            }

        }
    }];

}

- (void)list:(CDVInvokedUrlCommand *)command {
    NSMutableArray *accessoriesList = [[NSMutableArray alloc] initWithArray:[[EAAccessoryManager sharedAccessoryManager] connectedAccessories]];
    NSMutableArray *dictArray = [[NSMutableArray alloc] init];

    for(int i = 0; i < [accessoriesList count]; i++){
        EAAccessory *accessory = [accessoriesList objectAtIndex:i];
        [dictArray insertObject:[self accessoryDetails:accessory] atIndex:i];
    }

    NSArray *array = [NSArray arrayWithArray:dictArray];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:array];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}


- (void)write:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult;
    NSUInteger connectionId = (NSUInteger)[[command.arguments objectAtIndex:0] integerValue];
    NSString *protocolString = [command.arguments objectAtIndex:1];
    NSData *data = [command.arguments objectAtIndex:2];

    NSString *writeError = nil;

    CommunicationSession *session = [self getCommunicationSession:connectionId protocolString:protocolString];
    if (session != nil && [session isOpen]) {
        [session appendToWriteBuffer:data];
        if (![session writeData]) {
            writeError = @"An error occurred writing the session data.";
        }
    } else {
        writeError = @"The communication session for this protocol is not open on the device.";
    }

    if (writeError) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:writeError];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

}


- (void)read:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *pluginResult;
    NSUInteger connectionId = (NSUInteger)[[command.arguments objectAtIndex:0] integerValue];
    NSString *protocolString = [command.arguments objectAtIndex:1];
    NSMutableString *dataOutput = nil;
    CommunicationSession *session = [self getCommunicationSession:connectionId protocolString:protocolString];

    if (session != nil && [session isOpen]) {
        dataOutput = [session read];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:dataOutput];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"The communication session for this protocol is not open on the device."];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}


- (void)readUntil:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult;
    NSUInteger connectionId = (NSUInteger)[[command.arguments objectAtIndex:0] integerValue];
    NSString *protocolString = [command.arguments objectAtIndex:1];
    NSString *delimiter = [command.arguments objectAtIndex:2];

    CommunicationSession *session = [self getCommunicationSession:connectionId protocolString:protocolString];
    if (session != nil && [session isOpen]) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[session readUntilDelimiter:delimiter]];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"The communication session for this protocol is not open on the device."];

    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

#pragma mark - Сommunication session methods

- (void)closeCommunicationSession:(NSUInteger)connectionId protocolString:(NSString*)protocolString {
    for (int i=0; i<[self.communicationSessions  count]; i++) {
        CommunicationSession *session = [self.communicationSessions objectAtIndex:i];
        if ([session.protocolString isEqualToString:protocolString] && session.connectionId == connectionId) {
            [session close];
            [self.communicationSessions removeObject:session];
            i--;
        }
    }
}

- (void)closeCommunicationSessions:(NSUInteger)connectionId protocolStrings:(NSArray *)protocolStrings {
    for (NSString *protocolString in protocolStrings) {
        [self closeCommunicationSession:connectionId protocolString:protocolString];
    }
}

- (NSMutableDictionary*)openCommunicationSession:(CDVInvokedUrlCommand *)command {
    NSUInteger connectionId = (NSUInteger)[[command.arguments objectAtIndex:0] integerValue];
    NSArray *protocolStrings = [command.arguments objectAtIndex:1];
    NSMutableDictionary *openSessionResult = [[NSMutableDictionary alloc] init];
    NSArray *accessories = [[EAAccessoryManager sharedAccessoryManager]
                            connectedAccessories];

    // Find an accessory that supports all of the protocol strings supplied
    EAAccessory *accessory = nil;
    for (EAAccessory *obj in accessories) {
        if ([obj connectionID] == connectionId) {
            bool hasAllProtocolStrings = true;
            for (NSString *protocolString in protocolStrings) {
                if (![[obj protocolStrings] containsObject:protocolString]) {
                    hasAllProtocolStrings = false;
                }
            }

            if (hasAllProtocolStrings) {
                accessory = obj;
                break;
            }
        }
    }

    // If we have an accessory then open up a communication session with the accessory for any protocols supplied
    if (accessory != nil) {
        [accessory setDelegate:self];
        bool allSessionsOpened = true;
        for (NSString *protocolString in protocolStrings) {
            CommunicationSession *session = [[CommunicationSession alloc] init:accessory:protocolString:self.commandDelegate];
            session.connectCallbackId = command.callbackId;
            if ([session open]) {
                [self.communicationSessions addObject:session];
            } else {
                allSessionsOpened = false;
                break;
            }
        }

        if (!allSessionsOpened) {
            [self closeCommunicationSessions:connectionId protocolStrings:protocolStrings];
            [openSessionResult setValue:@"Could not open a communication session for all the protocols supplied." forKey:@"error"];
            [openSessionResult setObject:[NSNumber numberWithBool:FALSE] forKey:@"status"];

        } else {
            [openSessionResult setObject:[NSNumber numberWithBool:YES] forKey:@"status"];
        }

    } else {
        [openSessionResult setObject:[NSNumber numberWithBool:FALSE] forKey:@"status"];
        [openSessionResult setValue:@"Could not find accessory with matching connectionID and protocol string" forKey:@"error"];
    }

    return openSessionResult;
}


- (NSMutableDictionary*)accessoryDetails:(EAAccessory *)accessory {
    NSMutableDictionary *accessoryDict = [[NSMutableDictionary alloc] init];

    [accessoryDict setValue:[NSNumber numberWithLong:accessory.connectionID] forKeyPath:@"id"];
    [accessoryDict setValue:[NSNumber numberWithLong:accessory.connectionID] forKeyPath:@"address"];
    [accessoryDict setValue:@"" forKeyPath:@"class"];
    [accessoryDict setValue:accessory.manufacturer forKeyPath:@"manufacturer"];
    [accessoryDict setValue:accessory.name forKey:@"name"];
    [accessoryDict setValue:accessory.modelNumber forKey:@"modelNumber"];
    [accessoryDict setValue:accessory.serialNumber forKey:@"serialNumber"];
    [accessoryDict setValue:accessory.firmwareRevision forKey:@"firmwareRevision"];
    [accessoryDict setValue:accessory.hardwareRevision forKey:@"hardwareRevision"];
    [accessoryDict setValue:accessory.protocolStrings forKeyPath:@"protocols"];

    return accessoryDict;
}


- (CommunicationSession *)getCommunicationSession:(NSUInteger)connectionId protocolString:(NSString*)protocolString {
    return [self.communicationSessions filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(CommunicationSession *session, NSDictionary *bindings) {
        return [session.protocolString isEqualToString:protocolString] && session.connectionId == connectionId;
    }]].firstObject;
}

#pragma mark - Internal implementation methods

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state == CBManagerStatePoweredOn) {
        self.bluetoothEnabled = YES;
    } else {
        self.bluetoothEnabled = NO;
    }
}

- (void)accessoryConnected:(NSNotification *)notification {
    EAAccessory *accessory = [[notification userInfo] objectForKey:EAAccessoryKey];
    for (NSString *protocolString in accessory.protocolStrings ){
        CommunicationSession *session = [self getCommunicationSession:accessory.connectionID protocolString:protocolString];
        EAAccessory *connectionSessionAccessory = [session accessory];
        if (session == nil || ![connectionSessionAccessory isConnected]) {
            // If there's a device discovered listener then send back the device details
            if (self.deviceDiscoveredCallbackId != nil) {
                [self fireDeviceDiscoveredListener:accessory];
            }
        }
    }
}

-(void)fireDeviceDiscoveredListener:(EAAccessory *)accessory {
    NSArray *accessoryDetailsArray = [self accessoryDetails:accessory].copy;
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:accessoryDetailsArray];
    [pluginResult setKeepCallbackAsBool:true];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.deviceDiscoveredCallbackId];
}

- (void)accessoryDisconnected:(NSNotification *)notification {
    EAAccessory *accessory = [[notification userInfo] objectForKey:EAAccessoryKey];
    for (NSString *protocolString in accessory.protocolStrings ){
        CommunicationSession *session = [self getCommunicationSession:accessory.connectionID protocolString:protocolString];
        if (session != nil && [session connectCallbackId] != nil) {
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Device connection was lost"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:[session connectCallbackId]];
        }
    }
    [self closeCommunicationSessions:accessory.connectionID protocolStrings:accessory.protocolStrings];
}

@end

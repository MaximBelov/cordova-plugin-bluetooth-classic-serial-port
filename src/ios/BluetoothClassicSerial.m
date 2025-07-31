#import "BluetoothClassicSerial.h"

@implementation BluetoothClassicSerial

- (void)pluginInitialize {

    // Initialise properties
    self.deviceDiscoveredCallbackID = nil;
    self.sessionDataReadCallbackID = nil;

    // Initialise base bluetooth settings
    self.bluetoothEnabled = false;

    // State the core bluetooth central manager
    self.bluetoothManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:nil];

    // Initialise array to hold communication sessions
    self.communicationSessions = [[NSMutableArray alloc] init];

    // Initialise array to hold subscribe callback ids for protocol strings
    self.subscribeCallbackIds = [[NSMutableArray alloc] init];
    self.subscribeRawCallbackIds = [[NSMutableArray alloc] init];



    // Register for accessory manager notifications
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(accessoryConnected:) name:EAAccessoryDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(accessoryDisconnected:) name:EAAccessoryDidDisconnectNotification object:nil];
    [[EAAccessoryManager sharedAccessoryManager] registerForLocalNotifications];

}

#pragma mark - Cordova Plugin Methods

- (void)clearDeviceDiscoveredListener:(CDVInvokedUrlCommand *)command {
    self.deviceDiscoveredCallbackID = nil;
}

- (void)setDeviceDiscoveredListener:(CDVInvokedUrlCommand *)command {
    self.deviceDiscoveredCallbackID = command.callbackId;
}

- (void)subscribe:(CDVInvokedUrlCommand *)command {

    CDVPluginResult *pluginResult;
    NSUInteger connectionId = (NSUInteger)[[command.arguments objectAtIndex:0] integerValue];
    NSString *protocolString = [command.arguments objectAtIndex:1];
    NSString *delimiter = [command.arguments objectAtIndex:2];

    bool callbackExists = false;

    if (delimiter != nil && protocolString != nil) {

        // If we've already got some subscribe callback defined,
        // check if we have one with a matching protocol string and replace the callback id with the new one.
        for (NSMutableDictionary *callback in self.subscribeCallbackIds) {
            if (callback[@"protocolString"] != nil && [protocolString isEqualToString:callback[@"protocolString"]]
                && connectionId == [callback[@"connectionId"] unsignedIntegerValue]
                ) {
                [callback setValue:command.callbackId forKey:@"id"];
                [callback setValue:delimiter forKey:@"delimiter"];
                callbackExists = true;
            }
        }

        // If we didn't already have a callback for the protocol string then create one
        if (!callbackExists) {
            NSMutableDictionary *newCallback = [[NSMutableDictionary alloc] init];
            [newCallback setValue:command.callbackId forKey:@"id"];
            [newCallback setValue:protocolString forKey:@"protocolString"];
            [newCallback setValue:@(connectionId) forKey:@"connectionId"];
            [newCallback setValue:delimiter forKey:@"delimiter"];
            [self.subscribeCallbackIds addObject:newCallback];
        }

        // Add the subscribe callback to the communication sessions.
        [self addSubscribeCallbacksToCommunicationSessions];

    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Subscribe requires three parameters. The connection id, the protocol string and delimiter."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }

}

- (void)unsubscribe:(CDVInvokedUrlCommand *)command {

    // Grab the connectionId and protocol string
    NSUInteger connectionId = (NSUInteger)[[command.arguments objectAtIndex:0] integerValue];
    NSString *protocolString = [command.arguments objectAtIndex:1];
    [self unsubscribeCommunicationSession:connectionId protocolString:protocolString];

    // Fire the success callback
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

}

- (void)subscribeRaw:(CDVInvokedUrlCommand *)command {

    CDVPluginResult *pluginResult;
    NSUInteger connectionId = (NSUInteger)[[command.arguments objectAtIndex:0] integerValue];
    NSString *protocolString = [command.arguments objectAtIndex:1];

    bool callbackExists = false;
    if (protocolString != nil) {

        // If we've already got some subscribe callback defined, check if we have one with a matching protocol string and replace the callback id with the new one.
        for (NSMutableDictionary *callback in self.subscribeRawCallbackIds) {
            if (callback[@"protocolString"] != nil && [protocolString isEqualToString:callback[@"protocolString"]]
                && connectionId == [callback[@"connectionId"] unsignedIntegerValue]) {
                [callback setValue:command.callbackId forKey:@"id"];
                callbackExists = true;
            }
        }

        // If we didn't already have a callback for the protocol string then create one
        if (!callbackExists) {
            NSMutableDictionary *newCallback = [[NSMutableDictionary alloc] init];
            [newCallback setValue:command.callbackId forKey:@"id"];
            [newCallback setValue:protocolString forKey:@"protocolString"];
            [newCallback setValue:@(connectionId) forKey:@"connectionId"];
            [self.subscribeRawCallbackIds addObject:newCallback];
        }

        // Add the subscribe callback to the communication sessions.
        [self addSubscribeCallbacksToCommunicationSessions];

    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Subscribe raw requires two parameters: connection id and protocol string."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }

}

- (void)unsubscribeRaw:(CDVInvokedUrlCommand *)command {

    CDVPluginResult *pluginResult;
    NSUInteger connectionId = (NSUInteger)[[command.arguments objectAtIndex:0] integerValue];
    NSString *protocolString = [command.arguments objectAtIndex:1];

    if (protocolString != nil) {
        [self unsubscribeCommunicationSessionFromRawData:connectionId protocolString:protocolString];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Unsubscribe raw requires two parameters: connection id and protocol string."];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }

}

- (void)clear:(CDVInvokedUrlCommand *)command {

    CDVPluginResult *pluginResult;
    NSUInteger connectionId = (NSUInteger)[[command.arguments objectAtIndex:0] integerValue];
    NSString *protocolString = [command.arguments objectAtIndex:1];

    for (CommunicationSession *session in self.communicationSessions) {
        if ([session.protocolString isEqualToString:protocolString] && session.connectionId == connectionId) {
            [session clear];
        }
    }

    // Fire the callback
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

}


- (void)isEnabled: (CDVInvokedUrlCommand *)command {

    // Check if the Bluetooth state has been updated
    [self centralManagerDidUpdateState: self.bluetoothManager];

    // Fire the appropriate callback based on the state
    CDVPluginResult *pluginResult;
    if (self.bluetoothEnabled) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:true];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsBool:false];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

}


- (void)isConnected:(CDVInvokedUrlCommand*)command {

    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsBool:false];
    NSUInteger connectionId = (NSUInteger)[[command.arguments objectAtIndex:0] integerValue];
    NSString *protocolString = [command.arguments objectAtIndex:1];

    if(protocolString != nil) {
        CommunicationSession *session = [self getCommunicationSession:connectionId protocolString:protocolString];
        EAAccessory *connectionSessionAccessory = [session accessory];

        if (session != nil && [connectionSessionAccessory isConnected]) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:true];
        }
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
            [session close];
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


    // Make sure we don't have a null for connection id
    if ([command.arguments objectAtIndex:0] != (id)[NSNull null]) {
        @try {
            connectionId = (NSUInteger)[[command.arguments objectAtIndex:0] integerValue];
            connectionResult = [self openSessionForConnectionIdAndProtocolStrings:command];

            NSNumber *status = connectionResult[@"status"];
            if (![status boolValue]) {
                inError = true;
            } else {
                // If we've connected, attach any subscribe callbacks to the connected communication sessions.
                [self addSubscribeCallbacksToCommunicationSessions];
            }

        }
        @catch (NSException *e) {
            // Any errors here then throw the reason
            inError = true;
            [connectionResult setValue:e.reason forKey:@"error"];

        }
    } else {
        inError = true;
        connectionId = 0;
        [connectionResult setValue:@"The connection ID was null" forKey:@"error"];
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

    CommunicationSession *session = [self getCommunicationSession:connectionId protocolString:protocolString];
    if (session != nil && [session isOpen]) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[session readUntilDelimiter:[command.arguments objectAtIndex:1]]];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"The communication session for this protocol is not open on the device."];

    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

}

#pragma mark - Internal implementation methods


- (void)closeCommunicationSession:(NSUInteger)connectionId protocolString:(NSString*)protocolString {

    for (int i=0; i<[self.communicationSessions  count]; i++) {
        CommunicationSession *session = [self.communicationSessions  objectAtIndex:i];
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

- (NSMutableDictionary*)openSessionForConnectionIdAndProtocolStrings:(CDVInvokedUrlCommand *)command {

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
    for (CommunicationSession *session in self.communicationSessions) {
        if ([session.protocolString isEqualToString:protocolString] && session.connectionId == connectionId) {
            return session;
        }
    }
    return nil;
}


- (void)centralManagerDidUpdateState:(CBCentralManager *)central {

    if([central state] == CBCentralManagerStatePoweredOn) {
        self.bluetoothEnabled = true;
    } else {
        self.bluetoothEnabled = false;
    }
}

- (void)accessoryConnected:(NSNotification *)notification {

    EAAccessory *accessory = [[notification userInfo] objectForKey:EAAccessoryKey];

    for (NSString *protocolString in accessory.protocolStrings ){
        CommunicationSession *session = [self getCommunicationSession:accessory.connectionID protocolString:protocolString];
        EAAccessory *connectionSessionAccessory = [session accessory];

        if (session == nil || ![connectionSessionAccessory isConnected]) {
            // If there's a device discovered listener then send back the device details
            if (self.deviceDiscoveredCallbackID != nil) {
                [self fireDeviceDiscoveredListener:accessory];
            }
        }

    }

}

- (void)addSubscribeCallbacksToCommunicationSessions {

    for (NSMutableDictionary *callback in self.subscribeCallbackIds) {
        for (CommunicationSession *session in self.communicationSessions) {
            if ([session.protocolString isEqualToString:callback[@"protocolString"]] && session.connectionId == [callback[@"connectionId"] unsignedIntegerValue]) {
                session.readDelimiter = callback[@"delimiter"];
                [session addSubscribeCallbackAndObserver:callback[@"id"]];
            }
        }
    }

    for (NSMutableDictionary *callback in self.subscribeRawCallbackIds) {
        for (CommunicationSession *session in self.communicationSessions) {
            if ([session.protocolString isEqualToString:callback[@"protocolString"]] && session.connectionId == [callback[@"connectionId"] unsignedIntegerValue]) {
                [session subscribeRaw:callback[@"id"]];
            }
        }
    }

}

- (void)unsubscribeCommunicationSession: (NSUInteger)connectionId protocolString:(NSString*)protocolString {
    for (CommunicationSession *session in self.communicationSessions) {
        if ([session.protocolString isEqualToString:protocolString] && session.connectionId == connectionId) {
            [session unsubscribe];
        }
    }
}


- (void)unsubscribeCommunicationSessionFromRawData:(NSUInteger)connectionId protocolString:(NSString*)protocolString {
    for (CommunicationSession *session in self.communicationSessions) {
        if ([session.protocolString isEqualToString:protocolString] && session.connectionId == connectionId) {
            [session unsubscribeRaw];
        }
    }
}

-(void)fireDeviceDiscoveredListener:(EAAccessory *)accessory {

    // Copy the connected accessory details into an array and return it to the device discovered callback.
    NSArray *accessoryDetailsArray = [self accessoryDetails:accessory].copy;
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:accessoryDetailsArray];
    [pluginResult setKeepCallbackAsBool:true];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.deviceDiscoveredCallbackID];

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

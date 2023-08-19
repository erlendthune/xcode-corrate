//
//  HRMViewController.m
//  HeartMonitor
//
// http://useyourloaf.com/blog/2014/01/08/synthesized-speech-from-text.html
//<a href="http://cliparts.co">Clipart.co</a>   http://cliparts.co/clipart/2450470
//<a href="http://cliparts.co/clipart/97319">Clip art image by Cliparts.co</a>
//https://developer.bluetooth.org/gatt/characteristics/Pages/CharacteristicViewer.aspx?u=org.bluetooth.characteristic.heart_rate_measurement.xml

#import "HRMViewController.h"
#import "HRMAPHelper.h"
#import "ETAlertView.h"
#import <StoreKit/StoreKit.h>

//#define EMULATOR

@interface HRMViewController ()
@end

@implementation HRMViewController

-(void) connectionToStrapDisabled
{
//    _deleteDeviceButton.enabled = NO;
//    _deleteDeviceButton.hidden = YES;
//    _deviceUuidTextField.text = @"";
    _heartRateTextField.text = @"...";
    _firstHeartBeat=true;
    [_pulseTimer invalidate];
}

- (void)centralManager:(CBCentralManager *)central
didDisconnectPeripheral:(CBPeripheral *)peripheral
                 error:(NSError *)error

{
    NSLog(@"didDisconnectPeripheral: %@", error.description);
    _deviceInformation.text = @"Disconnected";
    _deviceConnected = false;
    [self connectionToStrapDisabled];
//    [self informAboutDisconnect];
    if(_deletedDeviceOnPurpose)
    {
        _identifier = nil;
        self.deviceUuidTextField.text = @"";
        [self connectToNewDevice];
    }
    else
    {
        self.deviceInformation.text = @"Reconnecting to the following device:";
        self.deviceUuidTextField.text = _identifier;
        [self connectToTheDeviceWeUsedLastTime];
    }
}
- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer
  didPauseSpeechUtterance:(AVSpeechUtterance *)utterance
{
    NSLog(@"didPauseSpeechUtterance");
    [_synth continueSpeaking];
//    _interruptedOnPlayback = YES;
}
- (void)audioSessionInterrupted:(NSNotification*)notification {
    NSDictionary *interruptionDictionary = [notification userInfo];
    NSNumber *interruptionType = (NSNumber *)[interruptionDictionary valueForKey:AVAudioSessionInterruptionTypeKey];
    if ([interruptionType intValue] == AVAudioSessionInterruptionTypeBegan) {
        NSLog(@"Interruption started");
        _interruptedOnPlayback = YES;
    } else if ([interruptionType intValue] == AVAudioSessionInterruptionTypeEnded){
        NSLog(@"Interruption ended");
    } else {
        NSLog(@"Something else happened");
    }
}

// method called whenever you have successfully connected to the BLE peripheral
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    _polarH7HRMPeripheral = peripheral;
    [peripheral setDelegate:self];
    [peripheral discoverServices:nil];
    
    _deviceConnected = true;
    _deletedDeviceOnPurpose = false;

    _identifier = peripheral.identifier.UUIDString;
    self.deviceUuidTextField.text = _identifier;
    [self save];

    _deleteDeviceButton.enabled = YES;
    _deleteDeviceButton.hidden = NO;
    
    self.connected = [NSString stringWithFormat:@"Connected: %@", peripheral.state == CBPeripheralStateConnected ? @"YES" : @"NO"];
    
//    [self informAboutConnect];
    
    NSLog(@"%@", self.connected);
}

// CBCentralManagerDelegate - This is called with the CBPeripheral class as its main input parameter. This contains most of the information there is to know about a BLE peripheral.
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSString *localName = [advertisementData objectForKey:CBAdvertisementDataLocalNameKey];
    NSArray* sids = [advertisementData objectForKey:CBAdvertisementDataServiceUUIDsKey];
    
    if(sids)
    {
        for (CBUUID* s in sids)
        {
//            CBUUID* u = [CBUUID UUIDWithData:s];
            if([s isEqual:[CBUUID UUIDWithString:POLARH7_HRM_HEART_RATE_SERVICE_UUID]])    // 1
            {
                if ([localName length] > 0)
                {
                    NSLog(@"Found the heart rate monitor: %@", localName);
                }
                [self.centralManager stopScan];
                [self connectToPeripheral:peripheral];
            }
            else
            {
                NSLog(@"Discovered UUID different from heart rate service:%@", s);
            }
        }
    }
}

//en-GB is a male voice...
- (void) nag
{
    AVSpeechSynthesisVoice* voice = [AVSpeechSynthesisVoice voiceWithLanguage:@"en-GB"];

    [self talk:@"If you enjoy using the app; please buy it so my wife can buy herself new shoes." voice:voice passive:false];
}
/*
- (void)informAboutDisconnect
{
    AVSpeechSynthesisVoice* voice = [AVSpeechSynthesisVoice voiceWithLanguage:@"en-GB"];
    
    [self talk:@"Lost connection to device. Trying to reconnect." voice:voice passive:false];
}

- (void)informAboutConnect
{
    AVSpeechSynthesisVoice* voice = [AVSpeechSynthesisVoice voiceWithLanguage:@"en-GB"];
    
    [self talk:@"Connected to device." voice:voice passive:false];
}
*/

- (void)centralManager:(CBCentralManager *)central
didFailToConnectPeripheral:(CBPeripheral *)peripheral
                 error:(NSError *)error
{
    NSString *s = [[NSString alloc] initWithFormat:@"Connection failed: %ld",(long)error.code];
    _deviceInformation.text = s;
    NSLog(@"didFailToConnectPeripheral: %@", error.description);
}

#pragma mark - CBPeripheralDelegate

// CBPeripheralDelegate - Invoked when you discover the peripheral's available services.
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    for (CBService *service in peripheral.services) {
        NSString *uuidString = [service.UUID UUIDString];
        NSLog(@"Discovered service: %@", service.UUID);
        [peripheral discoverCharacteristics:nil forService:service];
    }
}



// Invoked when you discover the characteristics of a specified service.
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    NSString *uuidString = [service.UUID UUIDString];
    NSLog(@"====================");
    NSLog(@"Service UUID:%@", uuidString);
    for (CBCharacteristic *aChar in service.characteristics)
    {
        NSString *uuidCharacteristicsString = [aChar.UUID UUIDString];
        NSLog(@"Service characteristic UUID:%@", uuidCharacteristicsString);
    }
    NSLog(@"====================");
    if ([service.UUID isEqual:[CBUUID UUIDWithString:POLARH7_HRM_HEART_RATE_SERVICE_UUID]])  {  // 1
        for (CBCharacteristic *aChar in service.characteristics)
        {
            // Request heart rate notifications
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:POLARH7_HRM_MEASUREMENT_CHARACTERISTIC_UUID]]) { // 2
                [self.polarH7HRMPeripheral setNotifyValue:YES forCharacteristic:aChar];
                NSLog(@"Found heart rate measurement characteristic");
            }
            // Request body sensor location
            else if ([aChar.UUID isEqual:[CBUUID UUIDWithString:POLARH7_HRM_BODY_LOCATION_CHARACTERISTIC_UUID]]) { // 3
                [self.polarH7HRMPeripheral readValueForCharacteristic:aChar];
                NSLog(@"Found body sensor location characteristic");
            }
        }
    }
    // Retrieve Device Information Services for the Manufacturer Name
    if ([service.UUID isEqual:[CBUUID UUIDWithString:POLARH7_HRM_DEVICE_INFO_SERVICE_UUID]])  { // 4
        for (CBCharacteristic *aChar in service.characteristics)
        {
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:POLARH7_HRM_MANUFACTURER_NAME_CHARACTERISTIC_UUID]]) {
                [self.polarH7HRMPeripheral readValueForCharacteristic:aChar];
                NSLog(@"Found a device manufacturer name characteristic");
            }
        }
    }
}
// Invoked when you retrieve a specified characteristic's value, or when the peripheral device notifies your app that the characteristic's value has changed.
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if(error)
    {
        NSLog(@"didUpdateValueForCharacteristic:%@", error.description);
        //        _deviceInformation.text = error.description;
        return;
    }
    // Updated value for heart rate measurement received
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:POLARH7_HRM_MEASUREMENT_CHARACTERISTIC_UUID]]) { // 1
        // Get the Heart Rate Monitor BPM
        NSLog(@"Get heart rate bpm data");
        [self getHeartBPMData:characteristic];
    }
    // Retrieve the characteristic value for manufacturer name received
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:POLARH7_HRM_MANUFACTURER_NAME_CHARACTERISTIC_UUID]]) {  // 2
        NSLog(@"Get manufacturer name");
        [self getManufacturerName:characteristic];
    }
    // Retrieve the characteristic value for the body sensor location received
    else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:POLARH7_HRM_BODY_LOCATION_CHARACTERISTIC_UUID]]) {  // 3
        NSLog(@"Get body location");
        [self getBodyLocation:characteristic];
    }
    
    self.deviceInformation.text = _manufacturer;
    
    // Add your constructed device information to your UITextView
    /*    self.deviceInfo.text = [NSString stringWithFormat:@"%@\n%@\n%@\n", self.connected, self.bodyData, self.manufacturer];  // 4
     */
}

- (void)connectToPeripheral:(CBPeripheral *)peripheral
{
    self.polarH7HRMPeripheral = peripheral;
    peripheral.delegate = self;
    [self.centralManager connectPeripheral:peripheral options:nil];
}

- (BOOL)connectToTheDeviceWeUsedLastTime
{
    if(_identifier)
    {
        _deleteDeviceButton.enabled = YES;
        _deleteDeviceButton.hidden = NO;
        NSUUID *uuid = [[NSUUID alloc]initWithUUIDString:_identifier];
        NSArray *identifiers =  @[uuid];
        NSArray *connper = [self.centralManager retrievePeripheralsWithIdentifiers:identifiers];
        if([connper count])
        {
            _polarH7HRMPeripheral = [connper objectAtIndex:0];
            [self connectToPeripheral:_polarH7HRMPeripheral];
            return true;
        }
    }
    return false;
}

// Scan for all available CoreBluetooth LE devices
- (BOOL) connectToAlreadyConnectedDevice
{
//    NSArray *services = @[[CBUUID UUIDWithString:POLARH7_HRM_HEART_RATE_SERVICE_UUID], [CBUUID UUIDWithString:POLARH7_HRM_DEVICE_INFO_SERVICE_UUID]];
    NSArray *services = @[[CBUUID UUIDWithString:POLARH7_HRM_HEART_RATE_SERVICE_UUID]];

    NSArray *connper = [self.centralManager retrieveConnectedPeripheralsWithServices:services];
    if([connper count])
    {
        [self connectToPeripheral:[connper objectAtIndex:0]];
        return true;
    }
    return false;
}

- (void) connectToNewDevice
{
    self.deviceInformation.text = @"Searching for available device...";
    self.deviceUuidTextField.text = @"";
    _deleteDeviceButton.enabled = NO;
    _deleteDeviceButton.hidden = YES;
    bool connected = [self connectToAlreadyConnectedDevice];
    
    if(!connected)
    {
 //       NSArray *services = @[[CBUUID UUIDWithString:POLARH7_HRM_HEART_RATE_SERVICE_UUID], [CBUUID UUIDWithString:POLARH7_HRM_DEVICE_INFO_SERVICE_UUID]];
        NSArray *services = @[[CBUUID UUIDWithString:POLARH7_HRM_HEART_RATE_SERVICE_UUID]];
        
        [self.centralManager scanForPeripheralsWithServices:services options:nil];
    }
}
// method called whenever the device state changes.
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    // Determine the state of the peripheral
    if ([central state] == CBManagerStatePoweredOff) {
        _deviceInformation.text = @"Please turn bluetooth on";
        _deleteDeviceButton.enabled = NO;
        _deleteDeviceButton.hidden = YES;
        _deviceUuidTextField.text = @"";
        [self connectionToStrapDisabled];
        NSLog(@"CoreBluetooth BLE hardware is powered off");
    }
    else if ([central state] == CBManagerStatePoweredOn)
    {
        NSLog(@"CoreBluetooth BLE hardware is powered on and ready");

        if(_identifier)
        {
            self.deviceInformation.text = @"Connecting to the following device:";
            self.deviceUuidTextField.text = _identifier;
            [self connectToTheDeviceWeUsedLastTime];
        }
        else
        {
            [self connectToNewDevice];
        }
    }
    else if ([central state] == CBManagerStateUnauthorized) {
        _deviceInformation.text = @"Not authorized to used bluetooth";
        [self connectionToStrapDisabled];
        NSLog(@"CoreBluetooth BLE state is unauthorized");
    }
    else if ([central state] == CBManagerStateUnknown) {
        _deviceInformation.text = @"Please check bluetooth settings";
        [self connectionToStrapDisabled];
        NSLog(@"CoreBluetooth BLE state is unknown");
    }
    else if ([central state] == CBManagerStateUnsupported) {
        _deviceInformation.text = @"This platform does not support bluetooth";
        [self connectionToStrapDisabled];
        NSLog(@"CoreBluetooth BLE hardware is unsupported on this platform");
    }
}

-(void)alertMessage:(NSString*)t s:(NSString*)s
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:t
                                                    message:s
                                                   delegate:nil
                                          cancelButtonTitle:@"Ok"
                                          otherButtonTitles:nil];
    alert.tag = 1;
    [alert show];
}

- (void)getPrice
{
    _price = nil;
    [[HRMAPHelper sharedInstance] requestProductsWithCompletionHandler:^(BOOL success, NSArray *products) {
        if (success)
        {
            if([products count])
            {
                SKProduct* p = [products objectAtIndex:0]; //We only have one product.
                if(p)
                {
                    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
                    [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
                    [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
                    [numberFormatter setLocale:p.priceLocale];
                    _price = [numberFormatter stringFromNumber:p.price];
                }
                else
                {
                    NSLog(@"getPrice no product at position 0.");
                }
            }
            else
            {
                NSLog(@"getPrice no products.");
            }
        }
        else
        {
            NSLog(@"getPrice failed to get products.");
        }
        dispatch_async(dispatch_get_main_queue(),^ {
            [self DisplayNagScreen];
        } );

    }];
}

- (void)purchase
{
    [_activityIndicator startAnimating];
    [[HRMAPHelper sharedInstance] requestProductsWithCompletionHandler:^(BOOL success, NSArray *products) {
        if (success)
        {
            if([products count])
            {
                SKProduct* p = [products objectAtIndex:0]; //We only have one product.
                if(p)
                {
                    [[HRMAPHelper sharedInstance] buyProduct:p];
                }
                else
                {
                    [self alertMessage:@"Purchase" s:@"Purchase failed."];
                    [_activityIndicator stopAnimating];
                }
            }
            else
            {
                [self alertMessage:@"Purchase" s:@"Purchase failed."];
                [_activityIndicator stopAnimating];
            }
        }
        else
        {
            [self alertMessage:@"Purchase" s:@"Unable to connect to App store."];
            [_activityIndicator stopAnimating];
        }
    }];
}

- (void)restorePurchase
{
    [_activityIndicator startAnimating];
    [[HRMAPHelper sharedInstance] restoreCompletedTransactions];
}

- (IBAction)deleteDeviceClicked:(id)sender
{
    [_centralManager cancelPeripheralConnection:(_polarH7HRMPeripheral)];
    _deletedDeviceOnPurpose = true;
}

-(void) UpdateRecoveryCounterText
{
    [_startRecoveryButton setTitle:[NSString stringWithFormat:@"%i", _counter] forState:UIControlStateNormal];
}

-(void) recoveryFinished
{
    _recoveryStopHeartRate = _heartRate;
    [self.timer invalidate];
    _startRecoveryButton.titleLabel.font = [UIFont systemFontOfSize:_startRecoveryButtonPreviousFont];
    [_startRecoveryButton setTitle:@"Start recovery" forState:UIControlStateNormal];
    _recoveryStarted = false;
    [self save];
}


-(void) updateCountdown
{
    self.counter--;
    
    _recoveryHeartRateTextfield.text = [NSString stringWithFormat:@"%i", _recoveryStartHeartRate-_heartRate];

    [self UpdateRecoveryCounterText];

    if(self.counter == 0)
    {
        [self recoveryFinished];
    }
}

- (int)getFontSize
{
    if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
    {
        return 98; /* Device is iPad */
    }
    int maxWidth = [[UIScreen mainScreen ]bounds].size.width;
    int fontSize = maxWidth/10;
    return fontSize;
}

- (IBAction)startRecoveryButtonClicked:(id)sender {
    if(_recoveryStarted)
    {
        [self recoveryFinished];
    }
    else
    {
        _counter = _recoveryTimeTextField.text.intValue;
        if(_counter)
        {
            _recoveryStarted = true;
            _startRecoveryButtonPreviousFont = _startRecoveryButton.titleLabel.font.pointSize;
            _startRecoveryButton.titleLabel.font = [UIFont systemFontOfSize:[self getFontSize]];
            _recoveryStartHeartRate = _heartRate;
            [_startRecoveryButton setTitle:_recoveryTimeTextField.text forState:UIControlStateNormal];
            //Start 1 second repeat timer
            self.timer = [NSTimer scheduledTimerWithTimeInterval: 1 target:self selector:@selector(updateCountdown) userInfo:nil repeats: YES];
            [self UpdateRecoveryCounterText];
        }
    }
}

- (void)updateHeartRateReserveTextField
{
    if((_heartRateMax == UNSET_HR_MAX) || (_heartRateMin == UNSET_HR_REST))
    {
        return;
    }
    int hrReserve = _heartRateMax - _heartRateMin;
    _reserveHeartRateTextField.text = [NSString stringWithFormat:@"%i", hrReserve];
}
- (IBAction)speedIndicatorChanged:(id)sender {
    [self save];
}
 
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSCharacterSet *numbersOnly = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
    NSCharacterSet *characterSetFromTextField = [NSCharacterSet characterSetWithCharactersInString:string];
    
    BOOL stringIsValid = [numbersOnly isSupersetOfSet:characterSetFromTextField];
    
    if(stringIsValid)
    {
        NSString *newString = [textField.text stringByReplacingCharactersInRange:range withString:string];
        if([newString length] > 1)
        {
            stringIsValid = ![newString hasPrefix:@"0"];
        }
        if(stringIsValid)
        {
            double d = [newString doubleValue];
            stringIsValid = (d < 1000);
        }
    }
    return stringIsValid;
}

- (int) getIntValueFromString:(NSString*)s
{
    if([s length])
    {
        return [s intValue];
    }
    return 0;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if(textField.tag == 1) // HRrest
    {
        _heartRateMin = [self getIntValueFromString:_minHeartRateTextField.text];
        if(!_heartRateMin)
        {
            _minHeartRateTextField.text = @"0";
        }
        [self updateHeartRateReserveTextField];
    }
    else if(textField.tag == 2) // HRmax
    {
        _heartRateMax = [self getIntValueFromString:_maxHeartRateTextField.text];
        if(!_heartRateMax)
        {
            _maxHeartRateTextField.text = @"0";
        }
        [self updateHeartRateReserveTextField];
    }
    else if(textField.tag == 3) // Recovery time
    {
        int i =[self getIntValueFromString:_recoveryTimeTextField.text];
        if(!i)
        {
            _recoveryTimeTextField.text = @"0";
        }
    }
    else if(textField.tag == 4) // Audio interval
    {
        _audioInterval = [self getIntValueFromString:_audioCueInterval.text];
        if(!_audioInterval)
        {
            _audioCueInterval.text = @"0";
        }
    }
    [self save];
}
- (IBAction)firstRowPushed:(id)sender {
    [self.view endEditing:YES];
}
- (IBAction)secondRowPushed:(id)sender {
    [self.view endEditing:YES];
}
- (IBAction)thirdRowPushed:(id)sender {
    [self.view endEditing:YES];
}
- (IBAction)fourthRowPushed:(id)sender {
    [self.view endEditing:YES];
}
- (IBAction)fifthRowPushed:(id)sender {
    [self.view endEditing:YES];
}
- (BOOL)textFieldShouldReturn:(UITextField*)aTextField
{
    [aTextField resignFirstResponder];
    return YES;
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField{
    return TRUE;
}


-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.view endEditing:YES];
}

- (void)viewWillAppear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(productPurchased:) name:IAPHelperProductPurchasedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(restorePurchaseFailed:) name:IAPHelperProductRestorePurchaseError object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(purchaseFailed:) name:IAPHelperProductPurchasedError object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(transactionFinished:) name:IAPHelperTransactionFinished object:nil];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(audioSessionInterrupted:)
                                                 name: AVAudioSessionInterruptionNotification
                                               object: [AVAudioSession sharedInstance]];
}

- (void)viewWillDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)productPurchased:(NSNotification *)notification {
    NSLog(@"Product purchased. Remove buy buttons");
    _purchased = true;
    [_activityIndicator stopAnimating];
    [self alertMessage:@"Purchase" s:@"Thank you. The app is now unlocked."];
}

- (void)restorePurchaseFailed:(NSNotification *)notification
{
    [self alertMessage:@"Restore purchase" s:@"Unable to connect to App store."];
    [_activityIndicator stopAnimating];
}

- (void)purchaseFailed:(NSNotification *)notification
{
    [self alertMessage:@"Purchase" s:@"Unable to connect to App store."];
    [_activityIndicator stopAnimating];
}
- (void)transactionFinished:(NSNotification *)notification
{
    if(!_purchased)
    {
        [self alertMessage:@"Purchase" s:@"Product is not purchased."];
    }
    [_activityIndicator stopAnimating];
}

- (void) startCentralManager
{
    CBCentralManager *centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    self.centralManager = centralManager;
}
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _hrmDisplay = HRM_BPM;
    _heartRateMax = UNSET_HR_MAX;
    _heartRateMin = UNSET_HR_REST;
    _audioOn = true;
    _heartRate = 0;
    _identifier = nil;
    _purchased = false;
    _recoveryStarted = false;
    _firstHeartBeat = true;
    _nagscreenOnDisplay = false;
    _deletedDeviceOnPurpose = false;
    _deviceConnected = false;
    _interruptedOnPlayback = false;
    _recoveryStartHeartRate = -1;
    _recoveryStopHeartRate = -1;
    _counter = 120;

//    _synthArray = [[NSMutableArray alloc] init];
    _synth = [[AVSpeechSynthesizer alloc] init];
    _synth.delegate = self;

    
    [_deleteDeviceButton setImage:[UIImage imageNamed:@"delete.png"] forState:UIControlStateNormal];
    
    [_audioButton setImage:[UIImage imageNamed:@"audioon.png"] forState:UIControlStateNormal];
    [self load]; //Loads user defaults
    
    _recoveryTimeTextField.text = [NSString stringWithFormat:@"%d", _counter];

    [self updateHeartRateReserveTextField];
    
    [self updateAudioButton];
    
    _deviceUuidTextField.text = @"";
    
    //Voice speed
    _speedIndicator.minimumValue = AVSpeechUtteranceMinimumSpeechRate;
    _speedIndicator.maximumValue = AVSpeechUtteranceMaximumSpeechRate;
    
    NSString* langCode = [AVSpeechSynthesisVoice currentLanguageCode];
    NSLog(@"Language code:%@", langCode);
    _voice = [AVSpeechSynthesisVoice voiceWithLanguage:[AVSpeechSynthesisVoice currentLanguageCode]];
    
    _relativeTiming = -1.0; //Indicate first time read with negative number.
    
    _nextNagTime = -1.0; //Indicate first time with negative number.
    

    // Do any additional setup after loading the view, typically from a nib.
    self.polarH7DeviceData = nil;
//    [self.view setBackgroundColor:[UIColor groupTableViewBackgroundColor]];
    [self.heartImage setImage:[UIImage imageNamed:@"HeartImage"]];
    
    [self startCentralManager];

    _purchased = [[HRMAPHelper sharedInstance] productPurchased:@"com.erlendthune.Heart_Rate_Training"];

    if(!_purchased)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(DisplayNagScreen) name:UIApplicationWillEnterForegroundNotification object:nil];
        [self getPrice];
    }
#ifdef EMULATOR
    [self emulate];
#endif
}

#ifdef EMULATOR
-(void) emulate
{
    _heartRate = 61;
    _minHeartRateTextField.text = @"45";
    _maxHeartRateTextField.text = @"195";
    _heartRateMax = 195;
    _reserveHeartRateTextField.text = @"150";
    _recoveryHeartRateTextfield.text = @"20";
    [self updateHeartRateTextField];
}
#endif


-(void) UpdateHeartRateMode
{
    if(_hrmDisplay == HRM_PERCENT)
    {
        [self.bpmButton setTitle:@"%" forState:UIControlStateNormal];
    }
    else
    {
        [self.bpmButton setTitle:@"bpm" forState:UIControlStateNormal];
    }
    [self updateHeartRateTextField];
}

- (IBAction)bpmButtonClicked:(id)sender {
    NSLog(@"bpmButtonClicked");
    if(_hrmDisplay == HRM_BPM)
    {
        _hrmDisplay = HRM_PERCENT;
    }
    else
    {
        _hrmDisplay = HRM_BPM;
    }
    [self UpdateHeartRateMode];
    [self save];
}

- (void) updateAudioButton
{
    if(_audioOn)
    {
        _audioButton.alpha = 1.0;
//        [_audioButton setImage:[UIImage imageNamed:@"audioon.png"] forState:UIControlStateNormal];
    }
    else
    {
//        [_audioButton setImage:[UIImage imageNamed:@"audiomute.png"] forState:UIControlStateNormal];
        _audioButton.alpha = 0.1;

    }
}

-(void)LockRestHeartRate:(BOOL)locked
{
    if(locked)
    {
        [_restPadlock setImage:[UIImage imageNamed:@"Locked"] forState:UIControlStateNormal];
        _minHeartRateTextField.enabled = NO;
        _minHeartRateTextField.backgroundColor = [UIColor lightGrayColor];
    }
    else
    {
        [_restPadlock setImage:[UIImage imageNamed:@"Unlocked"] forState:UIControlStateNormal];
        _minHeartRateTextField.enabled = YES;
        _minHeartRateTextField.backgroundColor = [UIColor whiteColor];
    }
    
}
-(void)LockMaxHeartRate:(BOOL)locked
{
    if(locked)
    {
        [_maxPadlock setImage:[UIImage imageNamed:@"Locked"] forState:UIControlStateNormal];
        _maxHeartRateTextField.enabled = NO;
        _maxHeartRateTextField.backgroundColor = [UIColor lightGrayColor];
    }
    else
    {
        [_maxPadlock setImage:[UIImage imageNamed:@"Unlocked"] forState:UIControlStateNormal];
        _maxHeartRateTextField.enabled = YES;
        _maxHeartRateTextField.backgroundColor = [UIColor whiteColor];
    }
    
}
- (IBAction)HRmaxPadlockClicked:(id)sender {
    if(_maxHeartRateTextField.enabled)
    {
        [self LockMaxHeartRate:YES];
    }
    else
    {
        [self LockMaxHeartRate:NO];
    }
    [self save];
}
- (IBAction)HRrestPadlockClicked:(id)sender {
    if(_minHeartRateTextField.enabled)
    {
        [self LockRestHeartRate:YES];
    }
    else
    {
        [self LockRestHeartRate:NO];
    }
    [self save];
}

- (IBAction)audioButtonClicked:(id)sender {
    if(_audioOn)
    {
        _audioOn = false;
    }
    else
    {
        _audioOn = true;
        if(_deviceConnected)
        {
            [self SpeakHeartRate];
        }
        [self ResetRelativeTiming];
    }
    [self updateAudioButton];
    [self save];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


-(void)DisplayNagScreen
{
    if(_purchased)
    {
        return;
    }
    if(self.nagscreenOnDisplay)
    {
        return;
    }

    if(self.noOfTimesUsed > NAG_TIMES_USED)
    {
        dispatch_async(dispatch_get_main_queue(),^ {
            [self DisplayAlertView:self.noOfTimesUsed];
        } );
    }
    
}
- (void) DisplayAlertView:(int)noOfTimesUsed
{
    // Create the view
    
    int maxWidth = [[UIScreen mainScreen ]applicationFrame].size.width;
    int maxHeight = [[UIScreen mainScreen ]applicationFrame].size.height;
    int imgWidth = maxWidth-20;
    int imgHeight = maxHeight/1.5;
    
    self.alertView = [[ETAlertView alloc] init:imgWidth imgHeight:imgHeight noOfTimesUsed:noOfTimesUsed mvc:self];
    
    CGRect f = self.alertView.frame;
    f.origin.x = 10;
    f.origin.y = 100;
    self.alertView.frame = f;
    
    //    self.view.userInteractionEnabled=NO;
    [self.view addSubview:self.alertView];
}
#pragma mark - CBCharacteristic helpers
- (void) talk:(NSString *)s voice:(AVSpeechSynthesisVoice*)voice passive:(bool)passive
{
    if(!_audioOn)
    {
        return;
    }
    bool speak = true;

    //If what we're going to say has the passive flag set and something else is being said, don't say it.

    if(passive && _synth.isSpeaking)
    {
        speak = false;
    }
    
    if(speak)
    {
        NSLog(@"Talk added: %@", s);
        if(_interruptedOnPlayback)
        {
            _interruptedOnPlayback = NO;
//            [_synthArray addObject:_synth];
            _synth = [[AVSpeechSynthesizer alloc] init];
            _synth.delegate = self;
        }
        NSLog(@"Talk synth: %@", _synth);
        
        AVSpeechUtterance* utterance = [AVSpeechUtterance speechUtteranceWithString:s];
        utterance.voice = voice;
        
        //Voice speed
        utterance.rate = _speedIndicator.value;
        
        [_synth speakUtterance:utterance];
    }

}

- (void) updateHeartRateTextField
{
#ifndef EMULATOR
    if((_heartRate > 0) && _deviceConnected)
#endif
    {
        if(_hrmDisplay == HRM_BPM)
        {
            _heartRateTextField.text = [NSString stringWithFormat:@"%i", _heartRate];
        }
        else
        {
            int hrmPercent = [self calculateHrmPercent];
            if(hrmPercent > 0)
            {
                _heartRateTextField.text = [NSString stringWithFormat:@"%d", hrmPercent];
            }
            else
            {
                _heartRateTextField.text = @"...";
            }
        }
    }
}

- (int) calculateHrmPercent
{
    int hrmPercent = -1;
    if(_heartRateMax && (_heartRateMax != UNSET_HR_MAX))
    {
        float dom = _heartRate;
        float denom = _heartRateMax;
        float value = dom*100.0/denom;
        hrmPercent = (int)roundf(value);
        NSLog(@"HR percent %d/%d = %f = %d", _heartRate, _heartRateMax, value, hrmPercent);
    }
    else
    {
        NSLog(@"Cannot calculate hrmpercent");
    }
    return hrmPercent;
}
-(void)byteAsBinary:(uint8_t)theNumber
{
    NSMutableString *str = [NSMutableString string];
    NSInteger numberCopy = (NSInteger)theNumber; // so you won't change your original value
    for(NSInteger i = 0; i < 8 ; i++) {
        // Prepend "0" or "1", depending on the bit
        [str insertString:((numberCopy & 1) ? @"1" : @"0") atIndex:0];
        numberCopy >>= 1;
    }
    NSLog(@"%d: %@",(int)theNumber, str);
}
/*
 0	Sensor Contact feature is not supported in the current connection
 1	Sensor Contact feature is not supported in the current connection
 2	Sensor Contact feature is supported, but contact is not detected
 3	Sensor Contact feature is supported and contact is detected
 
 But these values seem to be swapped, i.e.
 0	Sensor Contact feature is not supported in the current connection
 1  Sensor Contact feature is supported, but contact is not detected
 2	Sensor Contact feature is not supported in the current connection
 3	Sensor Contact feature is supported and contact is detected
*/
-(void)LogDeviceConnectionStatus:(uint8_t)b
{
    int i = [self GetConnectionStatus:b];
    switch (i) {
        case 0:
            NSLog(@"LogDeviceConnectionStatus:Sensor Contact feature is not supported in the current connection");
            break;
        case 1:
            NSLog(@"LogDeviceConnectionStatus:Sensor Contact feature is not supported in the current connection");
            break;
        case 2:
            NSLog(@"LogDeviceConnectionStatus:Sensor Contact feature is supported, but contact is not detected");
            break;
        case 3:
            NSLog(@"LogDeviceConnectionStatus:Sensor Contact feature is supported and contact is detected");
            break;
        default:
            NSLog(@"LogDeviceConnectionStatus:Invalid argument");
            break;
    }
}

-(int) GetConnectionStatus:(uint8_t)b
{
    return (b & 0x06)>>1;
}

-(void)TimedSpeaking
{
    if(!_audioOn)
    {
        return;
    }
    bool timeToSpeak = true;
    double newTime = CACurrentMediaTime();
    if(_relativeTiming < 0.0)
    {
        _relativeTiming = newTime;
    }
    else
    {
        if((newTime - _relativeTiming) < _audioInterval)
        {
            timeToSpeak = false;
        }
        else
        {
            _relativeTiming = newTime;
        }
    }
    if(_nextNagTime < 0.0)
    {
        [self updateNextNagTime:newTime];
    }
    
    if((!_purchased) && (newTime > _nextNagTime) && (_noOfTimesUsed > NAG_TIMES_USED))
    {
        [self nag];
        [self updateNextNagTime:newTime];
    }
    else if(timeToSpeak) //Don't nag and give the heart rate at the same time.
    {
        [self SpeakHeartRate];
    }
}

-(void) ResetRelativeTiming
{
    _relativeTiming = CACurrentMediaTime();
}

-(void) SpeakHeartRate
{
    NSString *hr = nil;
    if(_hrmDisplay == HRM_BPM)
    {
        hr = [NSString stringWithFormat:@"%i", _heartRate];
    }
    else
    {
        int hrmPercent = [self calculateHrmPercent];
        if(hrmPercent > -1)
        {
            hr = [NSString stringWithFormat:@"%d",hrmPercent];
        }
    }
    NSLog(@"HR:%@", hr);
    if(hr && [hr length])
    {
        [self talk:hr voice:_voice passive:true];
    }
}

-(void) ProcessHeartRate
{
    if((_heartRateMin == UNSET_HR_REST) || (_heartRate < _heartRateMin))
    {
        if(_minHeartRateTextField.enabled)
        {
            _heartRateMin = _heartRate;
            [self updateMinHeartRateTextField];
            [self updateHeartRateReserveTextField];
            [self save];
        }
    }
    if((_heartRateMax == UNSET_HR_MAX) || (_heartRate > _heartRateMax))
    {
        if(_maxHeartRateTextField.enabled)
        {
            _heartRateMax = _heartRate;
            [self updateMaxHeartRateTextField];
            [self updateHeartRateReserveTextField];
            [self save];
        }
    }
    
    if(_firstHeartBeat)
    {
        _firstHeartBeat = false;
        [self doHeartBeat];
    }

    [self calculateHrmPercent];
    [self updateHeartRateTextField];
    [self TimedSpeaking];
}

-(BOOL)IsPolarDevice
{
    NSRange range = [[_deviceInformation.text lowercaseString] rangeOfString:@"polar"];
    return range.length != 0;
}
/*
 0	Sensor Contact feature is not supported in the current connection
 1	Sensor Contact feature is not supported in the current connection
 2	Sensor Contact feature is supported, but contact is not detected
 3	Sensor Contact feature is supported and contact is detected
 */
// Instance method to get the heart rate BPM information
- (void) getHeartBPMData:(CBCharacteristic *)characteristic
{
    
    // Get the Heart Rate Monitor BPM
    NSData *data = [characteristic value];      // 1
    if(!data)
    {
        NSLog(@"getHeartBPMData:data is nil");
        return;
    }
    
    const uint8_t *reportData = [data bytes];
    uint16_t bpm = 0;
    [self byteAsBinary:reportData[0]];

    [self LogDeviceConnectionStatus:reportData[0]];
    
    //Wahoo Blue HR does not seem to support contact status, but Polar does.
    if([self IsPolarDevice])
    {
        if([self GetConnectionStatus:reportData[0]] == 2)
        {
            [self connectionToStrapDisabled];
            return;
        }
    }

    if ((reportData[0] & 0x01) == 0) {          // 2
        // Retrieve the BPM value for the Heart Rate Monitor
        bpm = reportData[1];
        NSLog(@"bpm1:%d", bpm);
    }
    else {
        bpm = CFSwapInt16LittleToHost(*(uint16_t *)(&reportData[1]));  // 3
        NSLog(@"bpm2:%d", bpm);
    }
    
    //If bmp is 0 just return.
    if(!bpm)
    {
        return;
    }
    self.heartRate = bpm;

    [self ProcessHeartRate];
}

- (void)updateNextNagTime:(double)newTime
{
/*    uint16_t i = NAG_CONSTANT / _noOfTimesUsed;
    if(i < NAG_MINIMUM)
    {
        i = NAG_MINIMUM;
    }
 */
    _nextNagTime = newTime + NAG_CONSTANT;
}

// Instance method to get the manufacturer name of the device
// Instance method to get the manufacturer name of the device
- (void) getManufacturerName:(CBCharacteristic *)characteristic
{
    NSString *manufacturerName = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];  // 1
    self.manufacturer = [NSString stringWithFormat:@"%@", manufacturerName];    // 2
    return;
}
- (void) getBodyLocation:(CBCharacteristic *)characteristic
{
    NSData *sensorData = [characteristic value];         // 1
    uint8_t *bodyData = (uint8_t *)[sensorData bytes];
    if (bodyData ) {
        uint8_t bodyLocation = bodyData[0];  // 2
        self.bodyData = [NSString stringWithFormat:@"Body Location: %@", bodyLocation == 1 ? @"Chest" : @"Undefined"]; // 3
    }
    else {  // 4
        self.bodyData = [NSString stringWithFormat:@"Body Location: N/A"];
    }
    return;
}
// Helper method to perform a heartbeat animation
- (void) doHeartBeat
{
    NSLog(@"Animating heart");
    CALayer *layer = [self heartImage].layer;
    CABasicAnimation *pulseAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    pulseAnimation.toValue = [NSNumber numberWithFloat:1.5];
    pulseAnimation.fromValue = [NSNumber numberWithFloat:1.0];
    
//    pulseAnimation.duration = 60. / self.heartRate / 2.;
    pulseAnimation.duration = 0.1;
    pulseAnimation.repeatCount = 1;
    pulseAnimation.autoreverses = YES;
    pulseAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    [layer addAnimation:pulseAnimation forKey:@"scale"];

    if(_heartRate != _previousHeartRate)
    {
        [_pulseTimer invalidate];
        _pulseTimer = [NSTimer scheduledTimerWithTimeInterval:60. / self.heartRate target:self selector:@selector(doHeartBeat) userInfo:nil repeats:YES];
    }
}

- (void) updateAudioIntervalTextField
{
    NSString *s = [NSString stringWithFormat:@"%ld", _audioInterval];
    _audioCueInterval.text = s;
}
- (void) updateMinHeartRateTextField
{
    if(_heartRateMin == UNSET_HR_REST)
    {
        _minHeartRateTextField.text = @"";
    }
    else
    {
        _minHeartRateTextField.text = [NSString stringWithFormat:@"%d", _heartRateMin];
    }
}
- (void) updateMaxHeartRateTextField
{
    if(_heartRateMax == UNSET_HR_MAX)
    {
        _maxHeartRateTextField.text = @"";
    }
    else
    {
        _maxHeartRateTextField.text = [NSString stringWithFormat:@"%d", _heartRateMax];
    }
}

- (IBAction)incAudioIntervalButtonPushed:(id)sender {
    if(_audioInterval < 999)
    {
        _audioInterval++;
        [self updateAudioIntervalTextField];
        [self save];
    }
}

- (IBAction)decAudioIntervalButtonPushed:(id)sender {
    if(_audioInterval > 0)
    {
        _audioInterval--;
        [self updateAudioIntervalTextField];
        [self save];
    }
}

- (void) save
{
    // Store the data
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if(_identifier)
    {
        [defaults setObject:_identifier forKey:@"identifier"];
    }
    else
    {
        [defaults removeObjectForKey:@"identifier"];
        

    }
    [defaults setInteger:_audioInterval forKey:@"audioInterval"];
    [defaults setInteger:_noOfTimesUsed forKey:@"noOfTimesUsed"];
    [defaults setInteger:_heartRateMin forKey:@"heartRateMin"];
    [defaults setInteger:_heartRateMax forKey:@"heartRateMax"];
    [defaults setInteger:_hrmDisplay forKey:@"displayMode"];
    int i = _recoveryTimeTextField.text.intValue;
    [defaults setInteger:i forKey:@"recoveryCounter"];

    if((_recoveryStartHeartRate != -1) && (_recoveryStopHeartRate != -1))
    {
        int i = _recoveryStartHeartRate-_recoveryStopHeartRate;
        [defaults setInteger:i forKey:@"heartRateRecovery"];
    }
    
    [defaults setObject:[NSNumber numberWithFloat:_speedIndicator.value] forKey:@"speedIndicator"];
    
    
    if(_audioOn)
    {
        [defaults setInteger:AUDIO_ON forKey:@"audioOn"];
    }
    else
    {
        [defaults setInteger:AUDIO_OFF forKey:@"audioOn"];
    }
    NSInteger locked = !_minHeartRateTextField.enabled;
    [defaults setInteger:locked forKey:@"restLocked"];

    locked = !_maxHeartRateTextField.enabled;
    [defaults setInteger:locked forKey:@"maxLocked"];

    [defaults synchronize];
    
    NSLog(@"Data saved");
}

- (void)load
{
    // Get the stored data before the view loads
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    _identifier = [defaults objectForKey:@"identifier"];
    
    if ([defaults objectForKey:@"audioInterval"] != nil)
    {
        NSInteger tempInt = [defaults integerForKey:@"audioInterval"];
        _audioInterval = tempInt;
    }
    else
    {
        _audioInterval = DEFAULT_AUDIO_INTERVAL;
    }
    [self updateAudioIntervalTextField];

    if ([defaults objectForKey:@"noOfTimesUsed"] != nil)
    {
        NSInteger tempInt = [defaults integerForKey:@"noOfTimesUsed"];
        _noOfTimesUsed = tempInt + 1;
    }
    else
    {
        _noOfTimesUsed = 1;
    }
    
    if ([defaults objectForKey:@"heartRateMin"] != nil)
    {
        NSInteger tempInt = [defaults integerForKey:@"heartRateMin"];
        _heartRateMin = tempInt;
        [self updateMinHeartRateTextField];
        
    }
    if ([defaults objectForKey:@"heartRateMax"] != nil)
    {
        NSInteger tempInt = [defaults integerForKey:@"heartRateMax"];
        _heartRateMax = tempInt;
        [self updateMaxHeartRateTextField];
    }
    if ([defaults objectForKey:@"displayMode"] != nil)
    {
        NSInteger tempInt = [defaults integerForKey:@"displayMode"];
        _hrmDisplay = tempInt;
        [self UpdateHeartRateMode];
    }
    
    if ([defaults objectForKey:@"recoveryCounter"] != nil)
    {
        NSInteger tempInt = [defaults integerForKey:@"recoveryCounter"];
        _counter = tempInt;
    }
    
    
    if ([defaults objectForKey:@"heartRateRecovery"] != nil)
    {
        NSInteger tempInt = [defaults integerForKey:@"heartRateRecovery"];
        _recoveryHeartRateTextfield.text = [NSString stringWithFormat:@"%i", (int)tempInt];
    }
        
    if ([defaults objectForKey:@"speedIndicator"] != nil) {
        self.speedIndicator.value = [[defaults objectForKey:@"speedIndicator"] floatValue];
    }
    
    if ([defaults objectForKey:@"audioOn"] != nil)
    {
        NSInteger tempInt = [defaults integerForKey:@"audioOn"];
        if(tempInt == AUDIO_ON)
        {
            _audioOn = true;
        }
        else if (tempInt == AUDIO_OFF)
        {
            _audioOn = false;
            [self updateAudioButton];
        }
    }
    if ([defaults objectForKey:@"restLocked"] != nil)
    {
        NSInteger locked = [defaults integerForKey:@"restLocked"];
        [self LockRestHeartRate:locked];
    }
    if ([defaults objectForKey:@"maxLocked"] != nil)
    {
        NSInteger locked = [defaults integerForKey:@"maxLocked"];
        [self LockMaxHeartRate:locked];
    }
    
}


@end

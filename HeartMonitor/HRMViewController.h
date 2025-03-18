#import <UIKit/UIKit.h>
@import CoreBluetooth;
@import QuartzCore;
@import AVFoundation;
@class ETAlertView;
#define POLARH7_HRM_DEVICE_INFO_SERVICE_UUID @"180A"
#define POLARH7_HRM_HEART_RATE_SERVICE_UUID @"180D"
#define DEFAULT_AUDIO_INTERVAL 10
#define POLARH7_HRM_MEASUREMENT_CHARACTERISTIC_UUID @"2A37"
#define POLARH7_HRM_BODY_LOCATION_CHARACTERISTIC_UUID @"2A38"
#define POLARH7_HRM_MANUFACTURER_NAME_CHARACTERISTIC_UUID @"2A29"

//Number of seconds when first nag should occur
//It will be divided by noOfTimesUsed so if it is 3600 the first nag will occur each hour the first
//time the app is used.
//The second time it will appear each half  hour.
//The third time each 15 minutes and so on. A minimum of NAG_MINIMUM seconds will be kept.
#define NAG_CONSTANT 600
#define NAG_TIMES_USED 10
//#define MAX_AUDIO_INTERVAL 999
#define HRM_BPM      1
#define HRM_PERCENT  2
#define UNSET_HR_REST 9999
#define UNSET_HR_MAX 9999

#define AUDIO_ON 1
#define AUDIO_OFF 2

typedef NS_ENUM(NSUInteger, HRMFartlekState) {
    HRMFartlekStateStarted,
    HRMFartlekStateWarmup,
    HRMFartlekStateWarmupFinished,
    HRMFartlekStateSlowdown,
    HRMFartlekStateSpeedup,
    HRMFartlekStateFinished
};

@class HRMFartlekViewController;
@interface HRMViewController : UIViewController <
UITextFieldDelegate, 
AVSpeechSynthesizerDelegate,
CBCentralManagerDelegate,
CBPeripheralDelegate>
@property (atomic, strong) CBCentralManager *centralManager;
@property (atomic, strong) CBPeripheral     *polarH7HRMPeripheral;
@property (atomic, strong) NSDictionary     *languages;
@property (strong, atomic) AVAudioPlayer* avSilentSound;

- (void) connectToNewDevice;
- (void) showDisclaimer;
- (BOOL)connectToTheDeviceWeUsedLastTime;
- (void)purchase;
- (void)restorePurchase;
- (void)startFartlek:(HRMFartlekViewController*)hrmFartlekViewController
                        warmupMinutes:(uint16_t)warmupMinutes
                        repetitions:(uint16_t)repetitions
                        lowHeartRate:(uint16_t)lowHeartRate
                       highHeartRate:(uint16_t)highHeartRate;
- (void)stopFartlek:(BOOL)forced;
- (void) save;
- (void)connectToPeripheral:(CBPeripheral *)peripheral;
- (void) talk:(NSString *)s voice:(AVSpeechSynthesisVoice*)voice passive:(bool)passive;
- (void) DisplayAlertView:(int)noOfTimesUsed nag:(bool)nag;

@property (nonatomic, strong) NSMutableArray<CBPeripheral*> *discoveredPeripherals;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *advertisedData;
@property (nonatomic, strong) UIAlertController *deviceListAlert;

@property (atomic, strong) IBOutlet UIImageView *heartImage;
@property (weak, atomic) IBOutlet UITextField *audioCueInterval;
@property (weak, atomic) IBOutlet UIButton *incAudioCueIntervalButton;
- (IBAction)incAudioIntervalButtonPushed:(id)sender;
@property (weak, atomic) IBOutlet UIButton *startRecoveryButton;
@property (weak, atomic) IBOutlet UILabel *recoveryHeartRateTextfield;
@property (weak, atomic) IBOutlet UILabel *reserveHeartRateTextField;
@property (weak, nonatomic) IBOutlet UIButton *firstRow;
@property (weak, nonatomic) IBOutlet UIButton *secondRow;
@property (weak, nonatomic) IBOutlet UIButton *thirdRow;
@property (weak, nonatomic) IBOutlet UIButton *fourthRow;
@property (weak, nonatomic) IBOutlet UIButton *fifthRow;
@property (weak, nonatomic) IBOutlet UIButton *sixthRow;

- (IBAction)decAudioIntervalButtonPushed:(id)sender;
@property (weak, atomic) IBOutlet UITextField *recoveryTimeTextField;
@property (weak, atomic) IBOutlet UILabel *heartRateTextField;
@property (weak, atomic) IBOutlet UILabel *deviceUuidTextField;
@property (weak, atomic) IBOutlet UITextField *maxHeartRateTextField;
@property (weak, atomic) IBOutlet UITextField *minHeartRateTextField;
@property (weak, atomic) IBOutlet UIButton *bpmButton;
@property (weak, atomic) IBOutlet UIButton *audioButton;
@property ushort hrmDisplay;
@property (weak, atomic) IBOutlet UILabel *deviceInformation;
@property (weak, nonatomic) IBOutlet UILabel *deviceName;
@property (weak, atomic) IBOutlet UIButton *deleteDeviceButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UISlider *speedIndicator;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *menuButton;

@property (strong, nonatomic) IBOutlet ETAlertView *alertView;

//@property (strong, atomic) AVSpeechSynthesizer *synth;
@property (strong, atomic) AVSpeechSynthesisVoice *voice;

// Properties to hold data characteristics for the peripheral device
@property (nonatomic, strong) NSString   *connected;
@property (nonatomic, strong) NSString   *bodyData;
@property (nonatomic, strong) NSString   *manufacturer;
@property (nonatomic, strong) NSString   *price;
@property (nonatomic, strong) NSString   *polarH7DeviceData;
@property (strong, atomic) NSString *identifier;

@property (strong, atomic) UIImage *deleteImage;
@property (strong, atomic) UIImage *audioOnImage;
@property (strong, atomic) UIImage *audioOffImage;

@property (nonatomic, assign) uint16_t fartlekRepetitions;
@property (nonatomic, assign) uint16_t fartlekWarmupMinutes;
@property (nonatomic, assign) uint16_t fartlekLowHeartRate;
@property (nonatomic, assign) uint16_t fartlekHighHeartRate;
@property (nonatomic, assign) uint16_t fartlekCurrentIteration;
@property (assign) BOOL newFartlekMessage;
@property (assign) int lastSpokenMinute;
@property (assign) double warmupStartedTime;
@property (assign) HRMFartlekState fartlekState;
@property (assign) double lastBeatTime;
@property (weak, nonatomic) IBOutlet UILabel *timeSinceLastBeat;

@property (assign) uint16_t heartRate;
@property (assign) uint16_t heartRatePercent;
@property (assign) uint16_t previousHeartRate;
@property (assign) uint16_t heartRateMin;
@property (assign) uint16_t heartRateMax;
@property (assign) BOOL disclaimerPresented;

@property (assign) int recoveryStartHeartRate;
@property (assign) int recoveryStopHeartRate;
@property (assign) uint16_t recoveryHeartRate;
@property (weak, nonatomic) IBOutlet UIButton *restPadlock;
@property (weak, nonatomic) IBOutlet UIButton *maxPadlock;

@property (assign) double relativeTiming;
@property (assign) long audioInterval;
@property (assign) double nextNagTime;
@property CGFloat startRecoveryButtonPreviousFont;
@property (assign) uint16_t noOfTimesUsed;
@property (strong, atomic) NSMutableArray *synthArray;
@property (strong, atomic) AVSpeechSynthesizer *synth;
@property (nonatomic) int usageCounter;
@property bool purchased;
@property bool audioOn;
@property (nonatomic, strong) HRMFartlekViewController *hrmFartlekViewController;
@property (nonatomic, assign) BOOL fartlek;
@property bool deletedDeviceOnPurpose;
@property bool deviceConnected;
@property bool recoveryStarted;
@property bool firstHeartBeat;
@property bool interruptedOnPlayback;
@property (weak, atomic) NSTimer * timer;
@property (assign) uint16_t counter;
@property (nonatomic) bool nagscreenOnDisplay;

// Properties to handle storing the BPM and heart beat
//@property (nonatomic, strong) UILabel    *heartRateBPM;
@property (nonatomic, retain) NSTimer    *pulseTimer;

// Instance method to perform heart beat animations
- (void) doHeartBeat;
@end

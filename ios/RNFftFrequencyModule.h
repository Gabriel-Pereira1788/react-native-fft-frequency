#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>
#import <React/RCTEventEmitter.h>
#import "generated/RNFftFrequencyModule/RNFftFrequencyModule.h"

@interface RNFftFrequencyModule : RCTEventEmitter<NativeFftFrequencyModuleSpec>
 @property (nonatomic, strong) AVAudioEngine *audioEngine;
  @property (nonatomic, strong) AVAudioUnitEQ *eqFilter;
  @property (nonatomic, assign) FFTSetup fftSetup;
  @property (nonatomic, assign) BOOL isCapturing;
  @property (nonatomic,assign) AVAudioSession *session;
  @property (nonatomic,assign) bool permissionGranted;
  @property (nonatomic, assign) float calibrationOffset;
  //JSI_VARIABLES
  @property (nonatomic,assign) UInt32  fftSize;
  @property (nonatomic,assign) double  highPassHz;
  @property (nonatomic,assign) double  lowPassHz;
@end

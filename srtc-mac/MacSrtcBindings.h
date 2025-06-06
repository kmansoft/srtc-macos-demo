//
//  MacSrtcBindings.h
//  srtc-macos-demo
//
//  Created by Kostya Vasilyev on 4/25/25.
//

#pragma once

#ifndef MacSrtcBindings_h
#define MacSrtcBindings_h

#include <Foundation/Foundation.h>

// Codecs

extern const NSInteger Codec_H264;
extern const NSInteger Codec_Opus;

extern const NSInteger H264_Profile_Default;
extern const NSInteger H264_Profile_ConstrainedBaseline;
extern const NSInteger H264_Profile_Main;

// Simulcast Layer

@interface MacSimulcastLayer : NSObject

- (id) initWithName:(NSString*) name
              width:(NSInteger) width
              height:(NSInteger) height
     framesPerSecond:(NSInteger) framesPerSecond
    kilobitPerSecond:(NSInteger) kilobitPerSecond;

- (NSString*) getName;
- (NSInteger) getWidth;
- (NSInteger) getHeight;
- (NSInteger) getFramesPerSecond;
- (NSInteger) getKilobitsPerSecond;

@end

// Offer configuration

@interface MacOfferConfig : NSObject

- (id) initWithCName:(NSString*) cname;

@end

@interface MacPubVideoCodec : NSObject

- (id) initWithCodec:(NSInteger) codec
      profileLevelId:(NSInteger) profileLevelId;

@end

@interface MacPubVideoConfig : NSObject

- (id) initWithCodecList:(NSArray<MacPubVideoCodec*>*) codecList
      simulcastLayerList:(NSArray<MacSimulcastLayer*>*) simulcastLayerList;

@end

@interface MacPubAudioCodec : NSObject

- (id) initWithCodec:(NSInteger) codec
            minptime:(NSInteger) minptime
              stereo:(Boolean) stereo;

@end

@interface MacPubAudioConfig : NSObject

- (id) initWithCodecList:(NSArray<MacPubAudioCodec*>*) codecList;

@end

// Codec options

@interface MacCodecOptions : NSObject

- (id) initWithProfileLeveId:(NSInteger) profileLevelId
                    minptime:(NSInteger) minptime
                      stereo:(Boolean) stereo;

- (NSInteger) getProfileLevelId;
- (NSInteger) getMinPTime;
- (Boolean) getStereo;

@end

// Track

@interface MacTrack : NSObject

- (id) initWithLayer:(MacSimulcastLayer*) simulcastLayer
               codec:(NSInteger) codec
        codecOptions:(MacCodecOptions*) codecOptions;

- (MacSimulcastLayer*) getSimulcastLayer;
- (NSInteger) getCodec;
- (MacCodecOptions*) getCodecOptions;

@end

// Peer connection callback

@protocol MacPeerConnectionStateCallback <NSObject>

- (void) onPeerConnectionStateChanged:(NSInteger) status;

@end

// Peer connection stats

@interface MacPublishConnectionStats : NSObject

@property Float32 packetLossPercent;
@property Float32 rttMs;
@property Float32 bandwidthActualKbitSec;
@property Float32 bandwidthSuggestedKbitSec;

@end

// Peer connection stats callback

@protocol MacPublishConnectionStatsCallback <NSObject>

- (void) onPublishConnectionStats:(MacPublishConnectionStats*) stats;

@end

// Peer connection

extern const NSInteger PeerConnectionState_Inactive;
extern const NSInteger PeerConnectionState_Connecting;
extern const NSInteger PeerConnectionState_Connected;
extern const NSInteger PeerConnectionState_Failed;
extern const NSInteger PeerConnectionState_Closed;

@interface MacPeerConnection : NSObject

- (id)init;
- (void)dealloc;

- (void) setStateCallback:(id<MacPeerConnectionStateCallback>) callback;
- (void) setStatsCallback:(id<MacPublishConnectionStatsCallback>) callback;

- (NSString*) createOffer:(MacOfferConfig*) config
              videoConfig:(MacPubVideoConfig*) videoConfig
              audioConfig:(MacPubAudioConfig*) audioConfig
                 outError:(NSError**) outError;
- (void) setAnswer:(NSString*) answer
          outError:(NSError**) outError;

- (MacTrack*) getVideoSingleTrack;
- (NSArray<MacTrack*>*) getVideoSimulcastTrackList;

- (MacTrack*) getAudioTrack;

- (void) setVideoSingleCodecSpecificData:(NSArray<NSData*>*) csd;
- (void) publishVideoSingleFrame:(NSData*) data;

- (void) setVideoSimulcastCodecSpecificData:(NSString*) layerName
                                        csd:(NSArray<NSData*>*) csd;
- (void) publishVideoSimulcastFrame:(NSString*) layerName
                               data:(NSData*) data;

- (void) publishAudioFrame:(NSData*) data;

- (void)close;

@end

#endif /* MacSrtcBindings_h */

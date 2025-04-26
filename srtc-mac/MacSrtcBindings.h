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

// Offer configuration

@interface MacOfferConfig : NSObject

- (id)initWithCName:(NSString*) cname;

@end

@interface MacPubVideoCodec : NSObject

- (id)initWithCodec:(NSInteger) codec
     profileLevelId:(NSInteger) profileLevelId;

@end

@interface MacPubVideoConfig : NSObject

- (id)initWithCodecList:(NSArray<MacPubVideoCodec*>*) codecList;

@end

// Peer connection callback

@protocol MacPeerConnectionStateCallback <NSObject>

- (void)onPeerConnectionStateChanged:(NSInteger) status;

@end

// Track

@interface MacTrack : NSObject

- (id) initWithCodec:(NSInteger) codec
      profileLevelId:(NSInteger) profileLevelId;

- (NSInteger) getCodec;
- (NSInteger) getProfileLevelId;

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

- (void)setStateCallback:(id<MacPeerConnectionStateCallback>) callback;
- (NSString*)createOffer:(MacOfferConfig*) config
             videoConfig:(MacPubVideoConfig*) videoConfig
                outError:(NSError**) outError;
- (void)setAnswer:(NSString*) answer
         outError:(NSError**) outError;

- (void)setVideoSingleCodecSpecificData:(NSArray<NSData*>*) csd;
- (void)publishVideoSingleFrame:(NSData*) data;

- (void)close;

@end

#endif /* MacSrtcBindings_h */

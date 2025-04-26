//
//  MacPeerConnection.h
//  srtc-macos-demo
//
//  Created by Kostya Vasilyev on 4/25/25.
//

#pragma once

#ifndef MacPeerConnection_h
#define MacPeerConnection_h

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

// Peer connection

@interface MacPeerConnection : NSObject

- (id)init;
- (void)dealloc;

- (NSString*)createOffer:(MacOfferConfig*) config
             videoConfig:(MacPubVideoConfig*) videoConfig
                outError:(NSError**) outError;

@end

#endif /* MacPeerConnection_h */

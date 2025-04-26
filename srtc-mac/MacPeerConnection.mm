//
//  MacPeerConnection.m
//  srtc-macos-demo
//
//  Created by Kostya Vasilyev on 4/25/25.
//

#import <Foundation/Foundation.h>

#include "MacPeerConnection.h"

#include "srtc/sdp_offer.h"
#include "srtc/sdp_answer.h"
#include "srtc/peer_connection.h"

#include <vector>
#include <memory>
#include <mutex>

namespace {

NSError* createNSError(const srtc::Error& error)
{
    NSDictionary *userInfo = @{
        NSLocalizedDescriptionKey: [[NSString alloc] initWithUTF8String:error.mMessage.c_str()]
    };

    NSError *ns = [NSError errorWithDomain:@"srtc"
                                      code:static_cast<NSInteger>(error.mCode)
                                  userInfo:userInfo];

    return ns;
}

}

// Codecs

const NSInteger Codec_H264 = 1;
const NSInteger Codec_Opus = 100;

const NSInteger H264_Profile_Default = 0x42001f;
const NSInteger H264_Profile_ConstrainedBaseline = 0x42e01f;
const NSInteger H264_Profile_Main = 0x4d001f;

// Offer configuration

@implementation MacOfferConfig

{
    std::string mCName;
}

- (id)initWithCName:(NSString*) cname
{
    self = [super init];
    if (self) {
        mCName = [cname UTF8String];
    }

    return self;
}

- (std::string)getCName
{
    return mCName;
}

@end

@implementation MacPubVideoCodec

{
    srtc::Codec mCodec;
    uint32_t mProfileLevelId;
}


- (id)initWithCodec:(NSInteger) codec
     profileLevelId:(NSInteger) profileLevelId
{
    self = [super init];
    if (self) {
        mCodec = static_cast<srtc::Codec>(codec);
        mProfileLevelId = static_cast<uint32_t>(profileLevelId);
    }

    return self;
}

- (srtc::Codec)getCodec
{
    return mCodec;
}

- (uint32)getProfileLevelId
{
    return mProfileLevelId;
}

@end

@implementation MacPubVideoConfig

{
    std::vector<srtc::PubVideoCodec> mCodecList;
}

- (id)initWithCodecList:(NSArray<MacPubVideoCodec*>*) codecList
{
    self = [super init];
    if (self) {
        if (codecList) {
            for (NSUInteger i = 0; i < [codecList count]; i += 1) {
                const auto codec = [codecList objectAtIndex:i];
                mCodecList.push_back({
                    .codec = [codec getCodec],
                    .profileLevelId = [codec getProfileLevelId]
                });
            }
        }
    }

    return self;
}

- (std::vector<srtc::PubVideoCodec>)getCodecList
{
    return mCodecList;
}

@end

// Peer connection

@implementation MacPeerConnection

{
    std::mutex mMutex;
    std::unique_ptr<srtc::PeerConnection> mConn;
    std::shared_ptr<srtc::SdpOffer> mOffer;
}

- (id)init
{
    NSLog(@"MacPeerConnection init");

    self = [super init];
    if (self) {
        mConn = std::make_unique<srtc::PeerConnection>();

        mConn->setConnectionStateListener([](const srtc::PeerConnection::ConnectionState& state) {
            const char* label = "unknown";
            switch (state) {
                case srtc::PeerConnection::ConnectionState::Inactive:
                    label = "inactive";
                    break;
                case srtc::PeerConnection::ConnectionState::Connecting:
                    label = "connecting";
                    break;
                case srtc::PeerConnection::ConnectionState::Connected:
                    label = "connected";
                    break;
                case srtc::PeerConnection::ConnectionState::Failed:
                    label = "failed";
                    break;
                case srtc::PeerConnection::ConnectionState::Closed:
                    label = "closed";
                    break;
            }
            NSLog(@"PeerConnection state = %s", label);
        });
    }
    
    return self;
}

- (void)dealloc
{
    NSLog(@"MacPeerConnection dealloc");

    std::lock_guard lock(mMutex);
    mConn.reset();
}

- (NSString*)createOffer:(MacOfferConfig*) config
             videoConfig:(MacPubVideoConfig*) videoConfig
                outError:(NSError**) outError
{
    std::lock_guard lock(mMutex);

    srtc::OfferConfig srtcOfferConfig {
        .cname = [config getCName]
    };
    srtc::optional<srtc::PubVideoConfig> srtcVideoConfig;
    if (videoConfig) {
        srtcVideoConfig = srtc::PubVideoConfig {
            .codecList = [videoConfig getCodecList]
        };
    }

    mOffer = std::make_shared<srtc::SdpOffer>(srtcOfferConfig, srtcVideoConfig, srtc::nullopt);

    const auto [sdp, error1] = mOffer->generate();
    if (error1.isError()) {
        *outError = createNSError(error1);
        return nil;
    }

    const auto error2 = mConn->setSdpOffer(mOffer);
    if (error2.isError()) {
        *outError = createNSError(error2);
        return nil;
    }

    return [[NSString alloc] initWithUTF8String:sdp.c_str()];

}

- (void)setAnswer:(NSString*) answer
         outError:(NSError**) outError
{
    std::lock_guard lock(mMutex);

    const auto answerStr = [answer UTF8String];
    const auto [sdp, error1] = srtc::SdpAnswer::parse(mOffer, answerStr, nullptr);
    if (error1.isError()) {
        *outError = createNSError(error1);
        return;
    }

    const auto error2 = mConn->setSdpAnswer(sdp);
    if (error2.isError()) {
        *outError = createNSError(error2);
        return;
    }
}

@end

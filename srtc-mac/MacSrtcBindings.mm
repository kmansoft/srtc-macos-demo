//
//  MacSrtcBindings.mm
//  srtc-macos-demo
//
//  Created by Kostya Vasilyev on 4/25/25.
//

#import <Foundation/Foundation.h>

#include "MacSrtcBindings.h"

#include "srtc/sdp_offer.h"
#include "srtc/sdp_answer.h"
#include "srtc/peer_connection.h"
#include "srtc/track.h"

#include <vector>
#include <memory>
#include <mutex>

namespace {

const uint8_t kAnnexBPrefix[4] = { 0, 0, 0, 1 };

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

class HighestProfileSelector : public srtc::SdpAnswer::TrackSelector {
public:
    ~HighestProfileSelector() override = default;

    [[nodiscard]] std::shared_ptr<srtc::Track> selectTrack(srtc::MediaType type,
                                                           const std::vector<std::shared_ptr<srtc::Track>>& list) const override;

};

bool isBetter(const std::shared_ptr<srtc::Track>& best,
              const std::shared_ptr<srtc::Track>& curr)
{
    if (!best) {
        return true;
    }

    if (best->getCodec() != curr->getCodec()) {
        return best->getCodec() < curr->getCodec();
    }

    return best->getProfileLevelId() < curr->getProfileLevelId();
}

std::shared_ptr<srtc::Track> HighestProfileSelector::selectTrack(srtc::MediaType type,
                                                                 const std::vector<std::shared_ptr<srtc::Track>>& list) const
{
    if (list.empty()) {
        return nullptr;
    }

    if (type == srtc::MediaType::Audio) {
        return list[0];
    } else if (type == srtc::MediaType::Video) {
        std::shared_ptr<srtc::Track> best;
        for (const auto& curr : list) {
            if (isBetter(best, curr)) {
                best = curr;
            }
        }
        return best;
    } else {
        return nullptr;
    }
}

}

// Codecs

const NSInteger Codec_H264 = static_cast<NSInteger>(srtc::Codec::H264);
const NSInteger Codec_Opus = static_cast<NSInteger>(srtc::Codec::Opus);

const NSInteger H264_Profile_Default = 0x42001f;
const NSInteger H264_Profile_ConstrainedBaseline = 0x42e01f;
const NSInteger H264_Profile_Main = 0x4d001f;

// Simulcast Layer

@implementation MacSimulcastLayer

{
    NSString* mName;
    NSInteger mWidth;
    NSInteger mHeight;
    NSInteger mFramesPerSecond;
    NSInteger mKilobitPerSecond;
}

- (id) initWithName:(NSString*) name
              width:(NSInteger) width
              height:(NSInteger) height
     framesPerSecond:(NSInteger) framesPerSecond
    kilobitPerSecond:(NSInteger) kilobitPerSecond
{
    self = [super init];
    if (self) {
        self->mName = name;
        self->mWidth = width;
        self->mHeight = height;
        self->mFramesPerSecond = framesPerSecond;
        self->mKilobitPerSecond = kilobitPerSecond;
    }

    return self;
}

- (NSString*) getName
{
    return mName;
}

- (NSInteger) getWidth
{
    return mWidth;
}

- (NSInteger) getHeight
{
    return mHeight;
}

- (NSInteger) getFramesPerSecond
{
    return mFramesPerSecond;
}

- (NSInteger) getKilobitsPerSecond
{
    return mKilobitPerSecond;
}

@end

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
    std::vector<srtc::SimulcastLayer> mSimulcastLayerList;
}

- (id)initWithCodecList:(NSArray<MacPubVideoCodec*>*) codecList
     simulcastLayerList:(NSArray<MacSimulcastLayer*>*) simulcastLayerList;
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
        if (simulcastLayerList) {
            for (NSUInteger i = 0; i < [simulcastLayerList count]; i += 1) {
                const auto layer = [simulcastLayerList objectAtIndex:i];
                mSimulcastLayerList.push_back({
                    .name = [[layer getName] UTF8String],
                    .width = static_cast<uint16_t>([layer getWidth]),
                    .height = static_cast<uint16_t>([layer getHeight]),
                    .framesPerSecond = static_cast<uint16_t>([layer getFramesPerSecond]),
                    .kilobitPerSecond = static_cast<uint32_t>([layer getKilobitsPerSecond])
                });
            }
        }
    }

    return self;
}

- (std::vector<srtc::PubVideoCodec>) getCodecList
{
    return mCodecList;
}

- (std::vector<srtc::SimulcastLayer>) getSimulcastLayerList
{
    return mSimulcastLayerList;
}

@end

// Track

@implementation MacTrack

{
    MacSimulcastLayer* mSimulcastLayer;
    NSInteger mCodec;
    NSInteger mProfileLevelId;
}

- (id) initWithLayer:(MacSimulcastLayer*) simulcastLayer
               codec:(NSInteger) codec
      profileLevelId:(NSInteger) profileLevelId;
{
    self = [super init];
    if (self) {
        self->mSimulcastLayer = simulcastLayer;
        self->mCodec = codec;
        self->mProfileLevelId = profileLevelId;
    }

    return self;
}

- (MacSimulcastLayer*) getSimulcastLayer
{
    return mSimulcastLayer;
}

- (NSInteger) getCodec
{
    return mCodec;
}

- (NSInteger) getProfileLevelId
{
    return mProfileLevelId;
}

@end

// Peer connection

const NSInteger PeerConnectionState_Inactive = static_cast<NSInteger>(srtc::PeerConnection::ConnectionState::Inactive);
const NSInteger PeerConnectionState_Connecting = static_cast<NSInteger>(srtc::PeerConnection::ConnectionState::Connecting);
const NSInteger PeerConnectionState_Connected = static_cast<NSInteger>(srtc::PeerConnection::ConnectionState::Connected);
const NSInteger PeerConnectionState_Failed = static_cast<NSInteger>(srtc::PeerConnection::ConnectionState::Failed);
const NSInteger PeerConnectionState_Closed = static_cast<NSInteger>(srtc::PeerConnection::ConnectionState::Closed);

@implementation MacPeerConnection

{
    std::mutex mMutex;
    std::unique_ptr<srtc::PeerConnection> mConn;
    std::shared_ptr<srtc::SdpOffer> mOffer;

    id<MacPeerConnectionStateCallback> mStateCallback;

    MacTrack* mVideoSingleTrack;
    NSArray<MacTrack*>* mVideoSimulcastTrackList;
}

- (id)init
{
    NSLog(@"MacPeerConnection init");

    self = [super init];
    if (self) {
        mConn = std::make_unique<srtc::PeerConnection>();

        __weak typeof(self) weakSelf = self;

        mConn->setConnectionStateListener([weakSelf](const srtc::PeerConnection::ConnectionState& state) {
            __strong typeof(self) strongSelf = weakSelf;
            if (strongSelf) {
                [strongSelf onPeerConnectionState:state];
            }
        });
    }
    
    return self;
}

- (void)setStateCallback:(id<MacPeerConnectionStateCallback>) callback
{
    mStateCallback = callback;
}

- (void)dealloc
{
    NSLog(@"MacPeerConnection dealloc");

    std::unique_ptr<srtc::PeerConnection> conn = {};

    {
        std::lock_guard lock(mMutex);
        conn = std::move(mConn);
    }

    conn.reset();
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
            .codecList = [videoConfig getCodecList],
            .simulcastLayerList = [videoConfig getSimulcastLayerList]
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

    const auto selector = std::make_shared<HighestProfileSelector>();

    const auto answerStr = [answer UTF8String];
    const auto [sdp, error1] = srtc::SdpAnswer::parse(mOffer, answerStr, selector);
    if (error1.isError()) {
        *outError = createNSError(error1);
        return;
    }

    const auto error2 = mConn->setSdpAnswer(sdp);
    if (error2.isError()) {
        *outError = createNSError(error2);
        return;
    }

    if (const auto videoSingleTrack = mConn->getVideoSingleTrack()) {
        const auto codec = static_cast<NSInteger>(videoSingleTrack->getCodec());
        const auto profileLevelId = static_cast<NSInteger>(videoSingleTrack->getProfileLevelId());

        const auto track = [[MacTrack alloc] initWithLayer:nil codec:codec profileLevelId:profileLevelId];
        mVideoSingleTrack = track;
    } else if (const auto videoSimulcastTrackList = mConn->getVideoSimulcastTrackList(); !videoSimulcastTrackList.empty()) {
        const auto list = [[NSMutableArray<MacTrack*> alloc] init];

        for (const auto& videoSimulcastTrack : videoSimulcastTrackList) {
            const auto trackLayer = videoSimulcastTrack->getSimulcastLayer();
            const auto layer = [[MacSimulcastLayer alloc] initWithName:[[NSString alloc] initWithUTF8String:trackLayer.name.c_str()]
                                                                 width:static_cast<NSInteger>(trackLayer.width)
                                                                height:static_cast<NSInteger>(trackLayer.height)
                                                       framesPerSecond:static_cast<NSInteger>(trackLayer.framesPerSecond)
                                                      kilobitPerSecond:static_cast<NSInteger>(trackLayer.kilobitPerSecond)];

            const auto codec = static_cast<NSInteger>(videoSimulcastTrack->getCodec());
            const auto profileLevelId = static_cast<NSInteger>(videoSimulcastTrack->getProfileLevelId());

            const auto track = [[MacTrack alloc] initWithLayer:layer codec:codec profileLevelId:profileLevelId];
            [list addObject: track];
        }

        mVideoSimulcastTrackList = [[NSArray alloc] initWithArray: list];
    }
}

- (MacTrack*) getVideoSingleTrack
{
    return mVideoSingleTrack;
}

- (NSArray<MacTrack*>*) getVideoSimulcastTrackList
{
    return mVideoSimulcastTrackList;
}

- (void)onPeerConnectionState:(srtc::PeerConnection::ConnectionState) state
{
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

    std::lock_guard lock(mMutex);
    if (mStateCallback) {
        const auto nsState = static_cast<NSInteger>(state);
        [mStateCallback onPeerConnectionStateChanged: nsState];
    }
}

- (void)setVideoSingleCodecSpecificData:(NSArray<NSData*>*) csd
{
    std::lock_guard lock(mMutex);
    if (const auto& conn = mConn) {
        std::vector<srtc::ByteBuffer> list;

        for (NSUInteger i = 0; i < [csd count]; i += 1) {
            const auto data = [csd objectAtIndex:i];
            srtc::ByteBuffer buf;
            buf.append(kAnnexBPrefix, sizeof(kAnnexBPrefix));
            buf.append(static_cast<const uint8_t*>(data.bytes), static_cast<size_t>(data.length));
            list.push_back(std::move(buf));
        }

        conn->setVideoSingleCodecSpecificData(std::move(list));
    }
}

- (void)publishVideoSingleFrame:(NSData*) data
{
    std::lock_guard lock(mMutex);
    if (const auto& conn = mConn) {
        srtc::ByteBuffer buf;

        buf.append(kAnnexBPrefix, sizeof(kAnnexBPrefix));
        buf.append(static_cast<const uint8_t*>(data.bytes), static_cast<size_t>(data.length));

        conn->publishVideoSingleFrame(std::move(buf));
    }
}

- (void) setVideoSimulcastCodecSpecificData:(NSString*) layerName
                                        csd:(NSArray<NSData*>*) csd
{
    std::lock_guard lock(mMutex);
    if (const auto& conn = mConn) {
        std::vector<srtc::ByteBuffer> list;

        for (NSUInteger i = 0; i < [csd count]; i += 1) {
            const auto data = [csd objectAtIndex:i];
            srtc::ByteBuffer buf;
            buf.append(kAnnexBPrefix, sizeof(kAnnexBPrefix));
            buf.append(static_cast<const uint8_t*>(data.bytes), static_cast<size_t>(data.length));
            list.push_back(std::move(buf));
        }

        conn->setVideoSimulcastCodecSpecificData([layerName UTF8String], std::move(list));
    }

}

- (void) publishVideoSimulcastFrame:(NSString*) layerName
                               data:(NSData*) data
{
    std::lock_guard lock(mMutex);
    if (const auto& conn = mConn) {
        srtc::ByteBuffer buf;

        buf.append(kAnnexBPrefix, sizeof(kAnnexBPrefix));
        buf.append(static_cast<const uint8_t*>(data.bytes), static_cast<size_t>(data.length));

        conn->publishVideoSimulcastFrame([layerName UTF8String], std::move(buf));
    }
}

- (void)close
{
    NSLog(@"MacPeerConnection close");

    std::unique_ptr<srtc::PeerConnection> conn = {};

    {
        std::lock_guard lock(mMutex);
        conn = std::move(mConn);
    }

    conn.reset();
}

@end

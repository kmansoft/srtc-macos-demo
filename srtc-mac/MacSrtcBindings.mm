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
#include "srtc/logging.h"

#include "opus.h"
#include "opus_defines.h"

#include <vector>
#include <memory>
#include <mutex>

namespace {

const uint8_t kAnnexBPrefix[4] = { 0, 0, 0, 1 };

NSError* createNSError(const srtc::Error& error)
{
    NSDictionary *userInfo = @{
        NSLocalizedDescriptionKey: [[NSString alloc] initWithUTF8String:error.message.c_str()]
    };

    NSError *ns = [NSError errorWithDomain:@"srtc"
                                      code:static_cast<NSInteger>(error.code)
                                  userInfo:userInfo];

    return ns;
}

MacCodecOptions* newCodecOptions(const std::shared_ptr<srtc::Track::CodecOptions>& codecOptions)
{
    if (!codecOptions) {
        return nil;
    }

    return [[MacCodecOptions alloc] initWithProfileLeveId:codecOptions->profileLevelId
                                                 minptime:codecOptions->minptime
                                                   stereo:codecOptions->stereo];
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
                    .profile_level_id = [codec getProfileLevelId]
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
                    .frames_per_second = static_cast<uint16_t>([layer getFramesPerSecond]),
                    .kilobits_per_second = static_cast<uint32_t>([layer getKilobitsPerSecond])
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

@implementation MacPubAudioCodec

{
    srtc::Codec mCodec;
    uint32_t mMinPTime;
    bool mStereo;
}


- (id) initWithCodec:(NSInteger) codec
            minptime:(NSInteger) minptime
              stereo:(Boolean) stereo
{
    self = [super init];
    if (self) {
        mCodec = static_cast<srtc::Codec>(codec);
        mMinPTime = static_cast<uint32_t>(minptime);
        mStereo = static_cast<bool>(stereo);
    }

    return self;
}

- (srtc::Codec) getCodec
{
    return mCodec;
}

- (uint32) getMinPTime
{
    return mMinPTime;
}

- (bool) getStereo
{
    return mStereo;
}

@end

@implementation MacPubAudioConfig

{
    std::vector<srtc::PubAudioCodec> mCodecList;
}

- (id) initWithCodecList:(NSArray<MacPubAudioCodec*>*) codecList
{
    self = [super init];
    if (self) {
        if (codecList) {
            for (NSUInteger i = 0; i < [codecList count]; i += 1) {
                const auto codec = [codecList objectAtIndex:i];
                mCodecList.push_back({
                    .codec = [codec getCodec],
                    .minptime = [codec getMinPTime],
                    .stereo = [codec getStereo]
                });
            }
        }
    }

    return self;
}

- (std::vector<srtc::PubAudioCodec>) getCodecList
{
    return mCodecList;
}


@end

// Codec options

@implementation MacCodecOptions

{
    NSInteger mProfileLevelId;
    NSInteger mMinPTime;
    Boolean mStereo;
}

- (id) initWithProfileLeveId:(NSInteger) profileLevelId
                    minptime:(NSInteger) minptime
                      stereo:(Boolean) stereo
{
    self = [super init];
    if (self) {
        mProfileLevelId = profileLevelId;
        mMinPTime = minptime;
        mStereo = stereo;
    }

    return self;
}

- (NSInteger) getProfileLevelId
{
    return mProfileLevelId;
}

- (NSInteger) getMinPTime
{
    return mMinPTime;
}

- (Boolean) getStereo
{
    return mStereo;
}

@end

// Track

@implementation MacTrack

{
    MacSimulcastLayer* mSimulcastLayer;
    NSInteger mCodec;
    MacCodecOptions* mCodecOptions;
}

- (id) initWithLayer:(MacSimulcastLayer*) simulcastLayer
               codec:(NSInteger) codec
        codecOptions:(MacCodecOptions*) codecOptions;
{
    self = [super init];
    if (self) {
        self->mSimulcastLayer = simulcastLayer;
        self->mCodec = codec;
        self->mCodecOptions = codecOptions;
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

- (MacCodecOptions*) getCodecOptions
{
    return mCodecOptions;
}

@end

// Publish connection stats

@implementation MacPublishConnectionStats

- (id)initWithStats:(const srtc::PublishConnectionStats&) stats
{
    self = [super init];
    if (self) {
        self.packetLossPercent = stats.packets_lost_percent;
        self.rttMs = stats.rtt_ms;
        self.bandwidthActualKbitSec = stats.bandwidth_actual_kbit_per_second;
        self.bandwidthSuggestedKbitSec = stats.bandwidth_suggested_kbit_per_second;
    }

    return self;
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
    std::atomic<bool> mIsClosing;

    std::mutex mMutex;
    std::unique_ptr<srtc::PeerConnection> mConn;

    id<MacPeerConnectionStateCallback> mStateCallback;
    id<MacPublishConnectionStatsCallback> mStatsCallback;

    MacTrack* mVideoSingleTrack;
    NSArray<MacTrack*>* mVideoSimulcastTrackList;
    MacTrack* mAudioTrack;

    dispatch_queue_t mOpusQueue;
    std::mutex mOpusMutex;
    std::vector<uint8_t> mOpusInputBuffer;
    OpusEncoder* mOpusEncoder;
    int64_t mOpusPts;
}

- (id)init
{
    NSLog(@"MacPeerConnection init");

    srtc::setLogLevel(SRTC_LOG_W);

    self = [super init];
    if (self) {
        mIsClosing = false;
        mConn = std::make_unique<srtc::PeerConnection>(srtc::Direction::Publish);
        mOpusQueue = dispatch_queue_create("srtc.opus", DISPATCH_QUEUE_SERIAL);
        mOpusEncoder = nullptr;
        mOpusPts = 0;

        __weak typeof(self) weakSelf = self;

        mConn->setConnectionStateListener([weakSelf](const srtc::PeerConnection::ConnectionState& state) {
            __strong typeof(self) strongSelf = weakSelf;
            if (strongSelf) {
                [strongSelf onPeerConnectionState:state];
            }
        });
        mConn->setPublishConnectionStatsListener([weakSelf](const srtc::PublishConnectionStats& stats) {
            __strong typeof(self) strongSelf = weakSelf;
            if (strongSelf) {
                [strongSelf onPublishConnectionStats:stats];
            }
        });
    }
    
    return self;
}

- (void)setStateCallback:(id<MacPeerConnectionStateCallback>) callback
{
    mStateCallback = callback;
}

- (void) setStatsCallback:(id<MacPublishConnectionStatsCallback>) callback
{
    mStatsCallback = callback;
}

- (void)dealloc
{
    NSLog(@"MacPeerConnection dealloc");
    [self close];
}

- (NSString*) createOffer:(MacOfferConfig*) config
              videoConfig:(MacPubVideoConfig*) videoConfig
              audioConfig:(MacPubAudioConfig*) audioConfig
                 outError:(NSError**) outError
{
    std::lock_guard lock(mMutex);

    srtc::PubOfferConfig srtcOfferConfig {
        .cname = [config getCName],
        .enable_bwe = true
    };
    std::optional<srtc::PubVideoConfig> srtcVideoConfig;
    if (videoConfig) {
        srtcVideoConfig = srtc::PubVideoConfig {
            .codec_list = [videoConfig getCodecList],
            .simulcast_layer_list = [videoConfig getSimulcastLayerList]
        };
    }
    std::optional<srtc::PubAudioConfig> srtcAudioConfig;
    if (audioConfig) {
        srtcAudioConfig = srtc::PubAudioConfig {
            .codec_list = [audioConfig getCodecList]
        };
    }

    const auto [offer, error1] = mConn->createPublishOffer(srtcOfferConfig, srtcVideoConfig, srtcAudioConfig);
    if (error1.isError()) {
        *outError = createNSError(error1);
        return nil;
    }

    const auto [sdp, error2] = offer->generate();
    if (error2.isError()) {
        *outError = createNSError(error2);
        return nil;
    }

    const auto error3 = mConn->setOffer(offer);
    if (error3.isError()) {
        *outError = createNSError(error3);
        return nil;
    }

    return [[NSString alloc] initWithUTF8String:sdp.c_str()];

}

- (void)setAnswer:(NSString*) answer
         outError:(NSError**) outError
{
    std::lock_guard lock(mMutex);

    const auto offer = mConn->getOffer();
    const auto selector = std::make_shared<srtc::HighestTrackSelector>();

    const auto answerStr = [answer UTF8String];
    const auto [sdp, error1] = mConn->parsePublishAnswer(offer, answerStr, selector);
    if (error1.isError()) {
        *outError = createNSError(error1);
        return;
    }

    const auto error2 = mConn->setAnswer(sdp);
    if (error2.isError()) {
        *outError = createNSError(error2);
        return;
    }

    if (const auto videoSingleTrack = mConn->getVideoSingleTrack()) {
        const auto codec = static_cast<NSInteger>(videoSingleTrack->getCodec());
        const auto codecOptions = videoSingleTrack->getCodecOptions();

        const auto track = [[MacTrack alloc] initWithLayer:nil
                                                     codec:codec
                                              codecOptions:newCodecOptions(codecOptions)];
        mVideoSingleTrack = track;
    } else if (const auto videoSimulcastTrackList = mConn->getVideoSimulcastTrackList(); !videoSimulcastTrackList.empty()) {
        const auto list = [[NSMutableArray<MacTrack*> alloc] init];

        for (const auto& videoSimulcastTrack : videoSimulcastTrackList) {
            const auto trackLayer = videoSimulcastTrack->getSimulcastLayer();
            const auto layer = [[MacSimulcastLayer alloc] initWithName:[[NSString alloc]initWithUTF8String:trackLayer->name.c_str()]
                                                                 width:static_cast<NSInteger>(trackLayer->width)
                                                                height:static_cast<NSInteger>(trackLayer->height)
                                                       framesPerSecond:static_cast<NSInteger>(trackLayer->frames_per_second)
                                                      kilobitPerSecond:static_cast<NSInteger>(trackLayer->kilobits_per_second)];

            const auto codec = static_cast<NSInteger>(videoSimulcastTrack->getCodec());
            const auto codecOptions = videoSimulcastTrack->getCodecOptions();

            const auto track = [[MacTrack alloc] initWithLayer:layer
                                                         codec:codec
                                                  codecOptions:newCodecOptions(codecOptions)];
            [list addObject: track];
        }

        mVideoSimulcastTrackList = [[NSArray alloc] initWithArray: list];
    }

    if (const auto audioTrack = mConn->getAudioTrack()) {
        const auto codec = static_cast<NSInteger>(audioTrack->getCodec());
        const auto codecOptions = audioTrack->getCodecOptions();
        const auto track = [[MacTrack alloc] initWithLayer:nil
                                                     codec:codec
                                              codecOptions:newCodecOptions(codecOptions)];
        mAudioTrack = track;
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

- (MacTrack*) getAudioTrack
{
    return mAudioTrack;
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

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(self) strongSelf = weakSelf;
        if (strongSelf) {
            std::lock_guard lock(strongSelf->mMutex);
            if (strongSelf->mStateCallback) {
                const auto nsState = static_cast<NSInteger>(state);
                [strongSelf->mStateCallback onPeerConnectionStateChanged: nsState];
            }
        }
    });
}

- (void)onPublishConnectionStats:(const srtc::PublishConnectionStats&)  stats
{
    const auto macStats = [[MacPublishConnectionStats alloc] initWithStats: stats];

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(self) strongSelf = weakSelf;
        if (strongSelf) {
            std::lock_guard lock(strongSelf->mMutex);
            if (strongSelf->mStatsCallback) {
                [strongSelf->mStatsCallback onPublishConnectionStats: macStats];
            }
        }
    });
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

        const auto pts_usec = srtc::getStableTimeMicros();
        conn->publishVideoSingleFrame(pts_usec, std::move(buf));
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

        const auto pts_usec = srtc::getStableTimeMicros();
        conn->publishVideoSimulcastFrame(pts_usec, [layerName UTF8String], std::move(buf));
    }
}

- (void) publishAudioFrame:(NSData*) data
{
    {
        std::lock_guard lock(mOpusMutex);

        const auto ptr = static_cast<const uint8_t*>([data bytes]);
        const auto size = static_cast<size_t>([data length]);

        mOpusInputBuffer.insert(mOpusInputBuffer.end(), ptr, ptr + size);
    }

    __weak typeof(self) weakSelf = self;
    dispatch_async(mOpusQueue, ^ {
        __strong typeof(self) strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf flushOpusQueue];
        }
    });
}

- (void)close
{
    NSLog(@"MacPeerConnection close");

    // We are closing
    mIsClosing = true;

    // Peer connection
    std::unique_ptr<srtc::PeerConnection> conn = {};
    {
        std::lock_guard lock(mMutex);
        conn = std::move(mConn);
    }
    conn.reset();

    // Opus
    {
        std::lock_guard lock(mOpusMutex);
        free(mOpusEncoder);
        mOpusEncoder = nullptr;
    }
}

struct OpusFrame {
    int64_t pts_usec;
    srtc::ByteBuffer buf;
};

- (void) flushOpusQueue
{
    if (mIsClosing) {
        return;
    }

    int minptime = 10;
    int channels = 1;

    {
        std::lock_guard lock(mMutex);
        if (mConn) {
            const auto answer = mConn->getAnswer();
            if (answer) {
                const auto track = answer->getAudioTrack();
                if (track) {
                    const auto options = track->getCodecOptions();
                    if (options) {
                        minptime = options->minptime;
                        if (options->stereo) {
                            channels = 2;
                        }
                    }
                }
            }
        }
    }

    std::list<OpusFrame> outputList;

    {
        constexpr auto kOpusSampleRate = 48000;

        std::lock_guard lock(mOpusMutex);

        // This is thread safe because we are inside a mutex
        if (mOpusEncoder == nullptr) {
            const auto encoderSize = opus_encoder_get_size(channels);
            mOpusEncoder = static_cast<OpusEncoder*>(malloc(encoderSize));
            std::memset(mOpusEncoder, 0, encoderSize);

            if (opus_encoder_init(mOpusEncoder, kOpusSampleRate, channels, OPUS_APPLICATION_VOIP) != 0) {
                free(mOpusEncoder);
                mOpusEncoder = nullptr;
            } else {
                opus_encoder_ctl(mOpusEncoder, OPUS_SET_BITRATE(96 * 1024));
                opus_encoder_ctl(mOpusEncoder, OPUS_SET_INBAND_FEC(1));
                opus_encoder_ctl(mOpusEncoder, OPUS_SET_PACKET_LOSS_PERC(20));
            }
        }

        if (mOpusEncoder) {
            const auto samples = (kOpusSampleRate * minptime) / 1000;
            const auto size = channels * sizeof(uint16_t) * samples;

            const auto now = srtc::getStableTimeMicros();
            if (mOpusPts == 0 || now - mOpusPts >= 100 * 1000) {
                mOpusPts = now;
            }

            while (mOpusInputBuffer.size() >= size) {
                srtc::ByteBuffer output { 4000 };
                const auto encodedSize = opus_encode(mOpusEncoder,
                                                     reinterpret_cast<const opus_int16*>(mOpusInputBuffer.data()),
                                                     static_cast<int>(samples),
                                                     output.data(),
                                                     static_cast<opus_int32>(output.capacity()));

                if (encodedSize > 0) {
                    output.resize(static_cast<size_t>(encodedSize));
                    outputList.push_back({ mOpusPts, std::move(output) });

                    NSLog(@"Encoded %zu bytes into %d Opus bytes", size, encodedSize);
                }

                mOpusInputBuffer.erase(mOpusInputBuffer.begin(), mOpusInputBuffer.begin() + size);
                mOpusPts += minptime * 1000;
            }
        }
    }

    if (!outputList.empty()) {
        std::lock_guard lock(mMutex);

        if (mConn) {
            while (!outputList.empty()) {
                auto front = std::move(outputList.front());
                outputList.erase(outputList.begin());

                mConn->publishAudioFrame(front.pts_usec, std::move(front.buf));
            }
        }
    }
}

@end

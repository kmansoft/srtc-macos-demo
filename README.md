### A demo for the srtc WebRTC library

This is a demo for "srtc" a [simple WebRTC library](https://github.com/kmansoft/srtc).

It is an Mac app which captures the camera and publishes it to a WebRTC stream negotiated via WHIP.

Tested with Pion and Amazon IVS (Interactive Video Service).

Video is published using H264 using the highest profile that can be negotiated (default, baseline, or main).

Audio is published using Opus.

Should work with other WHIP implementations too.

#### Checking out and building

Please clone this repository with `--recurse-submodules` to bring in the srtc library and the Opus audio encoder.

Build those two first by running `build-srtc.sh` and `build-opus.sh`, then open the project in XCode and build it.

#### Testing with Pion

Run pion by changing the directory into `./srtc/pion-webrtc-examples-whip-whep` and runnig `run.sh`.

Open your browser to `http://localhost:8080` and click "Subscribe", you should see Peer Connection State = "connected"
and a black video view with a spinning progress wheel.

In the Mac app, set Server to `http://localhost:8080/whip` and Token to `None`. Do not enable Simulcast.
Click "Connect" and you should see your camera's video feed in the web browser and hear the audio.

#### Testing with Amazon IVS

You will need an AWS account. Note that IVS Realtime is not included in the free trial of AWS.

Install AWS CLI and configure it for your account.

Use the AWS Console or CLI to create an IVS Realtime Stage.

Edit `new_ivs_token.sh` to use your Stage's ARN, and run the file to generate a new token. In the Mac app, set Server to
`https://global.whip.live-video.net` and Token to the value printed by the script. Click "Connect" and you should be
able to open the Stage in the AWS Console and subscribe to its video feed.

When publishing to IVS, you can enable Simulcast.

#/bin/bash

set -e

TEXT=$(aws ivs-realtime create-participant-token --duration 4320 --stage-arn arn:aws:ivs:us-west-2:422437114350:stage/R0uaOh27PasU --output json)
if [ -z "$TEXT" ]
then
	echo "Failed to create token"
	exit 1
fi

TOKEN=$(echo "$TEXT" | jq -r ".participantToken.token")
if [ -z "$TOKEN" ]
then
	echo "Failed to extract token"
	exit 1
fi

echo "Server: " "https://global.whip.live-video.net"
echo "Token:  " $TOKEN




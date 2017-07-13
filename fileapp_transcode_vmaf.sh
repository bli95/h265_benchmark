#!/usr/bin/env bash
# See usage below for description

if [ "$#" -ne 5 ]; then
  echo "Usage: "$0" <input_file.ts> <kbps_br> <format> <width> <height>

    Decodes input_file into its YUV format ('source'), then transcodes it in kbps_br via fileapp and decodes 
    that into another YUV ('output'). Compares 'source' and 'output' via VMAF, and generates XML result.
    *note: VMAF must be in this or its children directories; ffmpeg & fileapp (igolgi,inc.) must be installed

	<input_file.ts>		video stream file to be VMAF-ed in specified br
	<kbps_br>		bitrate to transcode input at via fileapp
	<format>		one of yuv420p, yuv422p, yuv444p, yuv420p10le, yuv422p10le, yuv444p10le
	<width, height>		dimensions of input file as args for vmaf"
  exit 0
fi

# retrieve sudo pwd (if not already) at start to use for fileapp during script runtime
if [ -z ${SUDOPWD+x} ];
then
	read -p "[sudo] password for $USER: " -s SUDOPWD
	echo "$SUDOPWD" | sudo -S true 2>/dev/null
	if [ $? -ne 0 ]; then
		echo -e "\nSorry, that's the wrong answer."
		exit 1
	else
		echo
	fi
fi

FILEPATH="$1"
MUX_KBPS=$2
FILE_FMT=$3
FILENAME="${FILEPATH##*/}"
BASENAME="${FILENAME%.*}"
FILENAME="${MUX_KBPS}kbps"

LOGPATH="intermediate/$BASENAME/transcode_speed.txt"
TIME_FMT="Fileapp time for $FILENAME...\nreal %e\nuser %U\nsys  %S\n%%cpu %P\n"

# Used for obtaining original bitrate of input
#which mediainfo
#if [ $? -eq 1 ]; then
#  apt install -y mediainfo
#fi
#MUX_KBPS=$(( (`mediainfo --inform="General;%OverallBitRate%" $FILEPATH`+999)/1000 ))

# create source raw if DNE
if [ ! -f "source/$BASENAME.yuv" ]; then
    mkdir -pv source/
			ffmpeg -i "$FILEPATH" -y -c:v rawvideo -pix_fmt $FILE_FMT "source/$BASENAME.yuv"
fi

# transcode input file and log s peed
mkdir -pv intermediate/$BASENAME/
echo "$SUDOPWD" | /usr/bin/time -o "$LOGPATH" -a -f "$TIME_FMT" sudo -S fileapp -o SAME -m $MUX_KBPS "$FILEPATH" "intermediate/$BASENAME/$FILENAME.ts"

# decode trancoded file
mkdir -pv output/$BASENAME/
ffmpeg -i "intermediate/$BASENAME/$FILENAME.ts" -y -c:v rawvideo -pix_fmt $FILE_FMT "output/$BASENAME/$FILENAME.yuv"

# run single vmaf on source and output raw vids if script is called by itself (vs by batch)
if [ -z ${BATCH_FPATH+x} ];
then
	unset $SUDOPWD

	VMAF_PATH=$(find $PWD -name run_vmaf)
	mkdir -pv results_vmaf/
	"$VMAF_PATH" $FILE_FMT $4 $5 "$PWD/source/$BASENAME.yuv" "$PWD/output/$BASENAME/$FILENAME.yuv" --out-fmt xml > "$PWD/results_vmaf/${BASENAME}_$FILENAME.xml"
fi
#!/bin/bash
# =============================================
# call2folder.sh - Asterisk → Yandex SpeechSense
# =============================================
LOGFILE="/var/log/speechsense/test_postcall.log"
UPLOAD_SCRIPT="/usr/local/bin/cloudapi/upload_data/upload_grpc.py"
# Параметры от FreePBX
FILENAME="$1"           # ^{MIXMONITOR_FILENAME}
CALLER="$2"             # ^{CALLERID(num)}
EXTEN="$3"              # ^{EXTEN}
UNIQUEID="$4"           # ^{UNIQUEID}
CALL_START="$5"         # ^{CDR(start)}
# Путь к записи
YEAR=$(date +%Y)
MONTH=$(date +%m)
DAY=$(date +%d)
if [[ "$FILENAME" = /* ]]; then
    AUDIO_FILE="$FILENAME"
else
    AUDIO_FILE="/var/spool/asterisk/monitor/${YEAR}/${MONTH}/${DAY}/${FILENAME}"
fi


# sox /var/spool/asterisk/monitor/2026/05/21/internal-1000-1002-20260521-082959-1779352199.12.wav   -r 16000 -c 1 -b 16 /tmp/converted_audio.wav
#DIR_RECORDINGS="/var/spool/asterisk/speechsense/recordings"
#FILENAME_REC="${DIR_RECORDINGS}/${FILENAME}"
#sox $AUDIO_FILE -r 16000 -c 1 -b 16 $FILENAME_REC


# Метаданные
METADATA_DIR="/usr/local/bin/cloudapi/upload_data"
METADATA_FILE="${METADATA_DIR}/${UNIQUEID}.json"
# =============================================
API_DIR="/var/spool/asterisk/speechsense"
API_FILE="speechsense.key"
API_KEY=$(cat "${API_DIR}/${API_FILE}")
{
    echo "=== $(date '+%Y-%m-%d %H:%M:%S') ==="
    echo "Filename     : $FILENAME"
    echo "Audio path   : $FILENAME_REC"
    echo "Caller       : $CALLER"
    echo "Exten        : $EXTEN"
    echo "UniqueID     : $UNIQUEID"
    # Проверка файла
    if [ ! -f "$FILENAME_REC" ]; then
        echo "ERROR: File not found: $FILENAME_REC"
        FOUND=$(find /var/spool/asterisk/monitor -name "*${UNIQUEID}*" -type f | head -n 1)
        if [ -n "$FOUND" ]; then
            FILENAME_REC="$FOUND"
            echo "Found alternative: $FILENAME_REC"
        else
            echo "CRITICAL ERROR: Recording not found!"
            exit 1
        fi
    fi
#    mkdir -p "$METADATA_DIR"
    # === Метаданные по вашей структуре ===
#    cat > "$METADATA_FILE" << EOF
#{
#  "operator_name": "",
#  "operator_id": "${EXTEN}",
#  "client_name": "",
#  "client_id": "${CALLER}",
#  "date": "${CALL_START}",
#  "direction_outgoing": false,
#  "language": "ru-RU"
#}
#EOF
    echo "Metadata created: $METADATA_FILE"
    # Загрузка
    if [ -f "$UPLOAD_SCRIPT" ]; then
        echo "Starting upload to SpeechSense..."
        python3 "$UPLOAD_SCRIPT" \
            --audio-path "$FILENAME_REC" \
            --meta-path "$METADATA_FILE" \
            --connection-id "acn70nbcvapki8ga9hqn" \
            --key "$API_KEY"
        if [ $? -eq 0 ]; then
            echo "SUCCESS: Uploaded to SpeechSense"
            # rm -f "$FILENAME_REC"    # Раскомментировать при необходимости
        else
            echo "ERROR: Upload failed"
        fi
    else
        echo "ERROR: upload_grpc.py not found!"
    fi
    echo "=== End ==="
    echo ""
} >> "$LOGFILE" 2>&1

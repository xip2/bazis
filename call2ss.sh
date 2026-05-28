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



# Метаданные
METADATA_FILE="/usr/local/bin/cloudapi/upload_data/metadata.json"

# =============================================
API_DIR="/var/spool/asterisk/speechsense"
API_FILE="speechsense.key"
API_KEY=$(cat "${API_DIR}/${API_FILE}")
{
    echo "=== $(date '+%Y-%m-%d %H:%M:%S') ==="
    echo "Filename     : $FILENAME"
    echo "Audio path   : $AUDIO_FILE"
    echo "Caller       : $CALLER"
    echo "Exten        : $EXTEN"
    echo "UniqueID     : $UNIQUEID"
    # Проверка файла
    if [ ! -f "$AUDIO_FILE" ]; then
        echo "ERROR: File not found: $AUDIO_FILE"
        FOUND=$(find /var/spool/asterisk/monitor -name "*${UNIQUEID}*" -type f | head -n 1)
        if [ -n "$FOUND" ]; then
            AUDIO_FILE="$FOUND"
            echo "Found alternative: $AUDIO_FILE"
        else
            echo "CRITICAL ERROR: Recording not found!"
            exit 1
        fi
    fi
	
	
	
# === Генерация метаданных под каждый звонок ===
CALL_START_ISO=$(date -d "$CALL_START" '+%Y-%m-%dT%H:%M:%S+00:00' 2>/dev/null || echo "$CALL_START")

cat > "$METADATA_FILE" << EOF
{
  "call_id": "${UNIQUEID}",
  "date": "${CALL_START_ISO}",
  "direction_outgoing": "false",
  "language": "ru-RU",
  "operator_name": "${EXTEN}",
  "operator_id": "${EXTEN}",
  "client_name": "${CALLER}",
  "client_id": "${CALLER}"
}
EOF

#=============конверт==========================

# Директория для конвертированных файлов
CONVERTED_DIR="/var/spool/asterisk/speechsense/recordings"
# Создаём директорию, если её нет
mkdir -p "$CONVERTED_DIR"

# Извлекаем только имя файла (без пути)
BASE_FILENAME=$(basename "$FILENAME")
# Путь к конвертированному файлу — только имя файла в целевой директории
CONVERTED_FILE="${CONVERTED_DIR}/${BASE_FILENAME}"


# Конвертация в отдельную директорию с тем же именем файла
    echo "Converting audio to $CONVERTED_FILE..."
    sox "$AUDIO_FILE" -r 16000 -c 1 -b 16 "$CONVERTED_FILE"
    SOX_EXIT=$?



#=======================================


    echo "Metadata created: $METADATA_FILE"
    # Загрузка
    if [ -f "$UPLOAD_SCRIPT" ]; then
        echo "Starting upload to SpeechSense..."
        python3 "$UPLOAD_SCRIPT" \
            --audio-path "$CONVERTED_FILE" \
            --meta-path "$METADATA_FILE" \
            --connection-id "acn70nbcvapki8ga9hqn" \
            --key "$API_KEY"
        if [ $? -eq 0 ]; then
            echo "SUCCESS: Uploaded to SpeechSense"
            # rm -f "$CONVERTED_FILE"    # Раскомментировать при необходимости
        else
            echo "ERROR: Upload failed"
        fi
    else
        echo "ERROR: upload_grpc.py not found!"
    fi
    echo "=== End ==="
    echo ""
} >> "$LOGFILE" 2>&1
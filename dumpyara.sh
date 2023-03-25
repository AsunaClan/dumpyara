#!/usr/bin/env bash

set -euo pipefail

if [ $# -eq 0 ]; then
    echo "No input"
    exit 1
fi

# Determine operating system
case $(uname -s) in
    Darwin*)
        export LC_CTYPE=C
        ;;
esac

# Determine project directory
PROJECT_DIR="$PWD"
mkdir -p "$PROJECT_DIR/input" "$PROJECT_DIR/working"

# Determine which command to use for privilege escalation
if command -v sudo > /dev/null 2>&1; then
    sudo_cmd="sudo"
elif command -v doas > /dev/null 2>&1; then
    sudo_cmd="doas"
else
    echo "Neither sudo nor doas found. Please install one of them."
    exit 1
fi

# Activate virtual environment
VENV_NAME=".venv"
if [ ! -d "$PROJECT_DIR/$VENV_NAME" ]; then
    python -m venv "$PROJECT_DIR/$VENV_NAME" --prompt "$(basename "$PROJECT_DIR")"
fi
source "$PROJECT_DIR/$VENV_NAME/bin/activate"

# Download GitHub token
if [ -n "${2:-}" ]; then
    GIT_OAUTH_TOKEN="$2"
elif token=$(curl -sSL "https://api.github.com/repos/$1/actions/secrets/GITHUB_TOKEN"); then
    GIT_OAUTH_TOKEN=$(echo "$token" | jq -r .value)
else
    echo "GitHub token not found. Dumping just locally..."
fi

# Use $GIT_OAUTH_TOKEN here...

# Download or copy from local?
if [[ "$1" =~ ^(https?|ftp)://.*$ ]]; then
    # 1DRV URL DIRECT LINK IMPLEMENTATION
    if [[ "$1" =~ 1drv.ms ]]; then
        URL=$(curl -I "$1" -s | sed -n 's/^location: //ip;T;q' | sed 's/redir/download/')
    else
        URL=$1
    fi
    cd "$PROJECT_DIR/input" || exit
    if command -v aria2c > /dev/null 2>&1; then
        printf "Downloading File...\n"
        aria2c -x16 -j "$(nproc)" "${URL}"
    else
        printf "Downloading File...\n"
        curl -L -C - --progress-bar --output "$(basename "${URL}")" "${URL}"
    fi
    if [[ ! -f "$(basename "${URL}")" ]]; then
        URL=$(curl -sI "${URL}" | sed -n 's/^content-disposition:.*filename=//ip;T;q' | tr -d "'\"")
    fi
    detox "$(basename "${URL}")"
else
    URL=$(printf "%s\n" "$1")
    [[ -e "$URL" ]] || { echo "Invalid Input" && exit 1; }
fi

ORG=AsunaClan # Your GitHub org name
FILE=$(basename "${URL}")
EXTENSION="${FILE##*.}"
UNZIP_DIR="${FILE/.$EXTENSION/}"
PARTITIONS="system systemex system_ext system_other vendor cust odm odm_ext oem factory product modem xrom oppo_product opproduct reserve india my_preload my_odm my_stock my_operator my_country my_product my_company my_engineering my_heytap my_custom my_manifest my_carrier my_region my_bigball my_version special_preload vendor_dlkm odm_dlkm system_dlkm mi_ext"

if [[ -d "$1" ]]; then
    echo 'Directory detected. Copying...'
    rsync -a "$1" "$PROJECT_DIR/working/${UNZIP_DIR}/"
elif [[ -f "$1" ]]; then

# Set variables
PROJECT_DIR="/path/to/project"
FILE="firmware.zip"
UNZIP_DIR=$(basename "${FILE}" .zip)

# Create cache directory
CACHE_DIR="${PROJECT_DIR}/cache"
mkdir -p "${CACHE_DIR}"

# Extract rom via Firmware_extractor
if [[ ! -d "${CACHE_DIR}/${UNZIP_DIR}" ]]; then
  bash "${PROJECT_DIR}/Firmware_extractor/extractor.sh" "${PROJECT_DIR}/input/${FILE}" "${CACHE_DIR}/${UNZIP_DIR}"
fi

# Extract boot.img and dtbo.img in parallel
if [[ -f "${CACHE_DIR}/${UNZIP_DIR}/boot.img" ]]; then
  extract-dtb "${CACHE_DIR}/${UNZIP_DIR}/boot.img" -o "${CACHE_DIR}/${UNZIP_DIR}/bootimg" > /dev/null &
  bash "${PROJECT_DIR}/mkbootimg_tools/mkboot" "${CACHE_DIR}/${UNZIP_DIR}/boot.img" "${CACHE_DIR}/${UNZIP_DIR}/boot" > /dev/null 2>&1 &
  [[ ! -e "${PROJECT_DIR}/extract-ikconfig" ]] && curl https://raw.githubusercontent.com/torvalds/linux/master/scripts/extract-ikconfig > ${PROJECT_DIR}/extract-ikconfig
  bash "${PROJECT_DIR}/extract-ikconfig" "${CACHE_DIR}/${UNZIP_DIR}/boot.img" > "${CACHE_DIR}/${UNZIP_DIR}/ikconfig" &
  mkdir -p "${CACHE_DIR}/${UNZIP_DIR}/bootRE"
  python3 "${PROJECT_DIR}/vmlinux-to-elf/vmlinux_to_elf/kallsyms_finder.py" "${CACHE_DIR}/${UNZIP_DIR}/boot.img" > "${CACHE_DIR}/${UNZIP_DIR}/bootRE/boot_kallsyms.txt" 2>&1 &
  python3 "${PROJECT_DIR}/vmlinux-to-elf/vmlinux_to_elf/main.py" "${CACHE_DIR}/${UNZIP_DIR}/boot.img" "${CACHE_DIR}/${UNZIP_DIR}/bootRE/boot.elf" > /dev/null 2>&1 &
  wait
  echo "Boot extracted"
fi

if [[ -f "${CACHE_DIR}/${UNZIP_DIR}/dtbo.img" ]]; then
  extract-dtb "${CACHE_DIR}/${UNZIP_DIR}/dtbo.img" -o "${CACHE_DIR}/${UNZIP_DIR}/dtbo" > /dev/null &
  echo "DTBO extracted"
fi

# Extract dts
mkdir -p "${CACHE_DIR}/${UNZIP_DIR}/bootdts"
dtb_list=$(find "${CACHE_DIR}/${UNZIP_DIR}/bootimg" -name '*.dtb' -type f -printf '%P\n' | sort)
for dtb_file in $dtb_list; do
  dtc -I dtb -O dts -o "$(echo "${CACHE_DIR}/${UNZIP_DIR}/bootdts/${

# extract PARTITIONS
cd "$PROJECT_DIR"/working/"${UNZIP_DIR}" || exit
extract_partition() {
    p=$1
    if [[ -e "$p.img" ]]; then
        mkdir "$p" 2> /dev/null || rm -rf "${p:?}"/*
        echo "Extracting $p partition"
        7z x "$p".img -y -o"$p"/ > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            rm "$p".img > /dev/null 2>&1
        else
        #handling erofs images, which can't be handled by 7z
            if [ -f $p.img ] && [ $p != "modem" ]; then
                echo "Couldn't extract $p partition by 7z. Using fsck.erofs."
                rm -rf "${p}"/*
                "$PROJECT_DIR"/Firmware_extractor/tools/Linux/bin/fsck.erofs --extract="$p" "$p".img
                if [ $? -eq 0 ]; then
                    rm -fv "$p".img > /dev/null 2>&1
                else
                    echo "Couldn't extract $p partition by fsck.erofs. Using mount loop"
                    $sudo_cmd mount -o loop -t auto "$p".img "$p"
                    mkdir "${p}_"
                    $sudo_cmd cp -rf "${p}/"* "${p}_"
                    $sudo_cmd umount "${p}"
                    $sudo_cmd cp -rf "${p}_/"* "${p}"
                    $sudo_cmd rm -rf "${p}_"
                    if [ $? -eq 0 ]; then
                        rm -fv "$p".img > /dev/null 2>&1
                    else
                        echo "Couldn't extract $p partition. It might use an unsupported filesystem."
                        echo "For EROFS: make sure you're using Linux 5.4+ kernel."
                        echo "For F2FS: make sure you're using Linux 5.15+ kernel."
                    fi
                fi
            fi
        fi
    fi
}

export -f extract_partition
echo "$PARTITIONS" | xargs -n1 -P$(nproc) bash -c 'extract_partition "$@"' _

# Fix permissions
$sudo_cmd chown "$(whoami)" "$PROJECT_DIR"/working/"${UNZIP_DIR}"/./* -fR
$sudo_cmd chmod -fR u+rwX "$PROJECT_DIR"/working/"${UNZIP_DIR}"/./*

# board-info.txt
find "$PROJECT_DIR"/working/"${UNZIP_DIR}"/modem -type f -print0 | xargs -0 -P $(nproc) strings | grep "QC_IMAGE_VERSION_STRING=MPSS." | sed "s|QC_IMAGE_VERSION_STRING=MPSS.||g" | cut -c 4- | sed -e 's/^/require version-baseband=/' >> "$PROJECT_DIR"/working/"${UNZIP_DIR}"/board-info.txt
find "$PROJECT_DIR"/working/"${UNZIP_DIR}"/tz* -type f -print0 | xargs -0 -P $(nproc) strings | grep "QC_IMAGE_VERSION_STRING" | sed "s|QC_IMAGE_VERSION_STRING|require version-trustzone|g" >> "$PROJECT_DIR"/working/"${UNZIP_DIR}"/board-info.txt
if [ -e "$PROJECT_DIR"/working/"${UNZIP_DIR}"/vendor/build.prop ]; then
    strings "$PROJECT_DIR"/working/"${UNZIP_DIR}"/vendor/build.prop | grep "ro.vendor.build.date.utc" | sed "s|ro.vendor.build.date.utc|require version-vendor|g" >> "$PROJECT_DIR"/working/"${UNZIP_DIR}"/board-info.txt
fi
sort -u -o "$PROJECT_DIR"/working/"${UNZIP_DIR}"/board-info.txt "$PROJECT_DIR"/working/"${UNZIP_DIR}"/board-info.txt

# set variables
prop_file=$(ls system/build*.prop 2> /dev/null || ls system/system/build*.prop 2> /dev/null || echo "")
if [[ -z "${prop_file}" ]]; then
    echo "No system build*.prop found, pushing cancelled!"
    exit
fi

prop_content=$(cat "$prop_file")
flavor=$(grep -oP "(?<=^ro.(vendor.)?build.flavor=).*" <<< "$prop_content" | head -1)
release=$(grep -oP "(?<=^ro.(vendor.)?build.version.release=).*" <<< "$prop_content" | head -1)
id=$(grep -oP "(?<=^ro.(vendor.)?build.id=).*" <<< "$prop_content" | head -1)
incremental=$(grep -oP "(?<=^ro.(vendor.)?build.version.incremental=).*" <<< "$prop_content" | head -1)
tags=$(grep -oP "(?<=^ro.(vendor.)?build.tags=).*" <<< "$prop_content" | head -1)
platform=$(grep -oP "(?<=^ro.(vendor.)?board.platform=).*" <<< "$prop_content" | head -1)
manufacturer=$(grep -oP "(?<=^ro.(vendor.)?product.(system.)?manufacturer=).*" <<< "$prop_content" | head -1)
fingerprint=$(grep -oP "(?<=^ro.(vendor.)?build.fingerprint=).*" <<< "$prop_content" | head -1)
brand=$(grep -oP "(?<=^ro.(vendor.)?product.(vendor.)?brand=).*" <<< "$prop_content" | head -1)
codename=$(grep -oP "(?<=^ro.(vendor.)?product.device=).*" <<< "$prop_content" | head -1)

# create TWRP device tree if possible
twrpimg="$PROJECT_DIR/working/$UNZIP_DIR/$(if [[ $is_ab = true ]]; then echo boot.img; else echo recovery.img; fi)"

if [[ -f "$twrpimg" ]]; then
    twrpdt="$PROJECT_DIR/working/$UNZIP_DIR/twrp-device-tree"
    python3 -m twrpdtgen "$twrpimg" --output "$twrpdt" && [[ ! -e "$twrpdt/README.md" ]] && curl https://raw.githubusercontent.com/wiki/SebaUbuntu/TWRP-device-tree-generator/4.-Build-TWRP-from-source.md > "$twrpdt/README.md" || exit 1
fi

# copy file names
chown "$(whoami)" ./* -R
chmod -R u+rwX ./* #ensure final permissions

if [[ -n $GIT_OAUTH_TOKEN ]]; then
    GITPUSH=(git push https://"$GIT_OAUTH_TOKEN"@github.com/$ORG/"${repo,,}".git "$branch")
    curl --silent --fail "https://raw.githubusercontent.com/$ORG/$repo/$branch/all_files.txt" 2> /dev/null && echo "Firmware already dumped!" && exit 1
    git init
    if [[ -z "$(git config --get user.email)" ]]; then
        git config user.email AndroidDumps@github.com
    fi
    if [[ -z "$(git config --get user.name)" ]]; then
        git config user.name AndroidDumps
    fi
    curl -s -X POST -H "Authorization: token ${GIT_OAUTH_TOKEN}" -d '{ "name": "'"$repo"'" }' "https://api.github.com/orgs/${ORG}/repos" #create new repo
    curl -s -X PUT -H "Authorization: token ${GIT_OAUTH_TOKEN}" -H "Accept: application/vnd.github.mercy-preview+json" -d '{ "names": ["'"$manufacturer"'","'"$platform"'","'"$top_codename"'"]}' "https://api.github.com/repos/${ORG}/${repo}/topics"
    git remote add origin https://github.com/$ORG/"${repo,,}".git
    git checkout -b "$branch"
    find . -size +97M -printf '%P\n' -o -name "*sensetime*" -printf '%P\n' -o -name "*.lic" -printf '%P\n' >| .gitignore
    git add --all
    git commit -asm "Add ${description}"
    git update-ref -d HEAD
    git reset system/ vendor/ product/
    git checkout -b "$branch"
    
    # run git add and git commit in parallel using xargs
    echo -e "$(find vendor/ -type f -printf '%P\n' | sed 's/^/vendor\//' | xargs -I {} echo "git add {}" | tr '\n' '\0')" | xargs -0 -P 4 -n 1 sh -c
    echo -e "$(find system/system/app/ -type f -printf '%P\n' | sed 's

# Telegram channel
TG_TOKEN=$(< "$PROJECT_DIR"/.tgtoken)
if [[ -n "$TG_TOKEN" ]]; then
    CHAT_ID="@android_dumps"
    commit_head=$(git log --format=format:%H | head -n 1)
    commit_link="https://github.com/$ORG/$repo/commit/$commit_head"
    echo -e "Sending telegram notification"
    TEXT=$(printf "<b>Brand: %s</b>\n<b>Device: %s</b>\n<b>Version:</b> %s\n<b>Fingerprint:</b> %s\n<b>GitHub:</b>\n<a href=\"%s\">Commit</a>\n<a href=\"https://github.com/%s/%s/tree/%s/\">%s</a>" \
        "$brand" "$codename" "$release" "$fingerprint" "$commit_link" "$ORG" "$repo" "$branch" "$codename")
    curl -s "https://api.telegram.org/bot${TG_TOKEN}/sendmessage?text=${TEXT}&chat_id=${CHAT_ID}&parse_mode=HTML&disable_web_page_preview=True" > /dev/null
fi

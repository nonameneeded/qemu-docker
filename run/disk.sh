#!/usr/bin/env bash
set -eu

BOOT="$STORAGE/boot.img"
[ ! -f "$BOOT" ] && echo "ERROR: Boot image does not exist ($BOOT)" && exit 81

DATA="${STORAGE}/data.img"
DISK_SIZE=$(echo "${DISK_SIZE}" | sed 's/MB/M/g;s/GB/G/g;s/TB/T/g')
DATA_SIZE=$(numfmt --from=iec "${DISK_SIZE}")

if [ -f "${DATA}" ]; then

  OLD_SIZE=$(stat -c%s "${DATA}")

  if [ "$DATA_SIZE" -gt "$OLD_SIZE" ]; then

    echo "INFO: Resizing data disk from $OLD_SIZE to $DATA_SIZE bytes.."
           
    REQ=$((DATA_SIZE-OLD_SIZE))
      
    # Check free diskspace    
    SPACE=$(df --output=avail -B 1 "${STORAGE}" | tail -n 1)
      
    if (( REQ > SPACE )); then
      echo "ERROR: Not enough free space to resize virtual disk." && exit 84
    fi

    if ! fallocate -l "${DATA_SIZE}" "${DATA}"; then
      echo "ERROR: Could not allocate file for virtual disk." && exit 85
    fi
      
  fi

  if [ "$DATA_SIZE" -lt "$OLD_SIZE" ]; then

    echo "INFO: Shrinking existing disks is not supported yet!"
    echo "INFO: Creating backup of old drive in storage folder..."

    mv -f "${DATA}" "${DATA}.bak"

  fi
  
fi

if [ ! -f "${DATA}" ]; then

  # Check free diskspace
  SPACE=$(df --output=avail -B 1 "${STORAGE}" | tail -n 1)

  if (( DATA_SIZE > SPACE )); then
    echo "ERROR: Not enough free space to create virtual disk." && exit 86
  fi

  # Create an empty file
  if ! fallocate -l "${DATA_SIZE}" "${DATA}"; then
    rm -f "${DATA}"
    echo "ERROR: Could not allocate file for virtual disk." && exit 87
  fi

  # Check if file exists
  if [ ! -f "${DATA}" ]; then
    echo "ERROR: Data image does not exist ($DATA)" && exit 88
  fi

fi

KVM_DISK_OPTS="\
    -drive id=cdrom0,if=none,format=raw,readonly=on,file=${BOOT} \
    -device virtio-scsi-pci,id=scsi0 \
    -device scsi-cd,bus=scsi0.0,drive=cdrom0 \
    -device virtio-scsi-pci,id=hw-userdata,bus=pcie.0,addr=0xa \
    -drive file=${DATA},if=none,id=drive-userdata,format=raw,cache=none,aio=native,discard=on,detect-zeroes=on \
    -device scsi-hd,bus=hw-userdata.0,channel=0,scsi-id=0,lun=0,drive=drive-userdata,id=userdata0,rotation_rate=1,bootindex=1"
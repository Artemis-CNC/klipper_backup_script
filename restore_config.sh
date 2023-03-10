#!/bin/bash

### FUNCTIONS
function check_yes_no {
  ANSWER=$1
  case $ANSWER in
    y|Y|n|N)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

function import_config {
  CONFIG_FILE="$HOME/.config/klipper_backup_script/backup.cfg"
  CONFIG_FILE_SECURE="$HOME/.config/klipper_backup_script/sec_backup.cfg"

  sed -i "s/^BREAK=.*/BREAK=0/g" "$HOME/.config/klipper_backup_script/backup.cfg"

  ### Check if the file contains malicious code
  if egrep -q -v '^#|^[^ ]*=[^;]*' "$CONFIG_FILE"
  then
  	echo "Warning! Config file is unclean, cleaning it..." | tee -a "$HOME/backup_log/$(date +%F).log"
  	### Filter the original to a new file
  	egrep '^#|^[^ ]*=[^;&]*'  "$CONFIG_FILE" > "$CONFIG_FILE_SECURE"
  	CONFIG_FILE="$CONFIG_FILE_SECURE"
  fi

  source "$CONFIG_FILE"
}

function validate_input {
  INPUT=$1
  case $INPUT in
    1|2)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

function choose_source {
  if [[ $GIT = 1 && $CLOUD = 1 ]]
  then
  	echo "From which source should the backup be restored?"
  	echo "1: GitHub"
  	echo "2: Google Drive"
  	while ! validate_input $SOURCE
  	do
  		read -p "Backup source [1|2] " SOURCE
  		case $SOURCE in
  			1)
  				echo "GitHub selected as backup source" | tee -a "$HOME/backup_log/$(date +%F).log"
  				;;
  			2)
  				echo "Google Drive selected as backup source" | tee -a "$HOME/backup_log/$(date +%F).log"
  				;;
  			*)
  				echo -e "${RED}Please select a valid source${NONE}" | tee -a "$HOME/backup_log/$(date +%F).log"
  				;;
  		esac
  	done
  ## Only Git configured
  elif [[ $GIT = 1 ]]  then
  	echo "GitHub selected as backup source" | tee -a "$HOME/backup_log/$(date +%F).log"
  	SOURCE=1
  ## Only Google Drive configured
  elif [[ $CLOUD = 1 ]]
  then
  	echo "Google Drive selected as backup source" | tee -a "$HOME/backup_log/$(date +%F).log"
  	SOURCE=2
  else
  	echo -e "${RED}Restoring is not possible${NONE}" | tee -a "$HOME/backup_log/$(date +%F).log"
  	echo -e "${RED}Please make sure you have a valid config file${NONE}" | tee -a "$HOME/backup_log/$(date +%F).log"
  	exit 1
  fi
}

function choose_mode {
  echo "Which restoring mode do you want?"
  echo "1: Restore an old config to an existing installation"
  echo "2: Restore a config to a new installation"

  while ! validate_input $MODE
  do
  	read -p "Please enter the restore mode [1|2] " MODE
  	case $MODE in
  		1)
  			echo "Restoring to existing installation" | tee -a "$HOME/backup_log/$(date +%F).log"
  			;;
  		2)
  			echo "Restoring to new installation" | tee -a "$HOME/backup_log/$(date +%F).log"
  			;;
  		*)
  			echo -e "${RED}Please select a valid restoring method${NONE}" | tee -a "$HOME/backup_log/$(date +%F).log"
  			;;
  	esac
  done
}

function determine_action {
  if [[ $SOURCE = 1 && $MODE = 1 ]]
  then
  	## GitHub to existing installation
  	ACTION=1
  elif [[ $SOURCE = 1 && $MODE = 2 ]]
  then
  	## GitHub to new installation
  	ACTION=2
  elif [[ $SOURCE = 2 && $MODE = 1 ]]
  then
  	## Google Drive to existing installation
  	ACTION=3
  elif [[ $SOURCE = 2 && $MODE = 2 ]]
  then
  	## Google Drive to new installation
  	ACTION=4
  else
  	## Input error
  	echo -e "${RED}Error while calculating which action to take${NONE}" | tee -a "$HOME/backup_log/$(date +%F).log"
  	echo "Aborting" | tee -a "$HOME/backup_log/$(date +%F).log"
  	exit 2
  fi
}

function choose_config_git {
  echo "The following configs can be restored:"
  for i in ${GITHUB_CONFIG_FOLDER_LIST[@]}
  do
    echo "$i) ${GITHUB_CONFIG_FOLDER_LIST[$i]}"
    SOURCE_OPTIONS=$(( $SOURCE_OPTIONS + 1 ))
  done

  while [[ $RESTORE_SOURCE -gt $SOURCE_OPTIONS ]]
  do
    read -p "Which configuration should be restored? " RESTORE_SOURCE

    case $RESTORE_SOURCE in
      [a-zA-Z]+)
        echo echo "Please provide a calid config to be restored"
        ;;
      [0-9]+)
        if [[ $RESTORE_SOURCE -gt $SOURCE_OPTIONS || $RESTORE_SOURCE -lt 0 ]]
        then
          echo "Please provide a calid config to be restored"
        else
          echo "Restoring ${GITHUB_CONFIG_FOLDER_LIST[$RESTORE_SOURCE]}" | tee -a "$HOME/backup_log/$(date +%F).log"
        fi
        ;;
      *)
        echo echo "Please provide a calid config to be restored"
        ;;
    esac
  done
}

function choose_config_drive {
  echo "The following configs can be restored:"
  for i in ${DRIVE_CONFIG_FOLDER_LIST[@]}
  do
    echo "$i) ${DRIVE_CONFIG_FOLDER_LIST[$i]}"
    SOURCE_OPTIONS=$(( $SOURCE_OPTIONS + 1 ))
  done

  while [[ $RESTORE_SOURCE -gt $SOURCE_OPTIONS ]]
  do
    read -p "Which configuration should be restored? " RESTORE_SOURCE

    case $RESTORE_SOURCE in
      [a-zA-Z]+)
        echo echo "Please provide a calid config to be restored"
        ;;
      [0-9]+)
        if [[ $RESTORE_SOURCE -gt $SOURCE_OPTIONS || $RESTORE_SOURCE -lt 0 ]]
        then
          echo "Please provide a calid config to be restored"
        else
          echo "Selected ${DRIVE_CONFIG_FOLDER_LIST[$RESTORE_SOURCE]}" | tee -a "$HOME/backup_log/$(date +%F).log"
        fi
        ;;
      *)
        echo echo "Please provide a calid config to be restored"
        ;;
    esac
  done
}

function keep_old_drive {
  while ! check_yes_no $DELETE_OLD_CONFIG
  do
    read -p "Do you want to keep the old folder? [Y|n] " DEL
    DEL=${DELETE_OLD_CONFIG:-y}
  done

  case $DELETE_OLD_CONFIG in
    y|Y)
      echo "Old folder is located at $HOME/${DRIVE_CONFIG_FOLDER_LIST[$RESTORE_SOURCE]}_bak_$(date +%F)" | tee -a "$HOME/backup_log/$(date +%F).log"
      ;;
    n|N)
      echo "Deleting backup" | tee -a "$HOME/backup_log/$(date +%F).log"
      rm -r "$HOME/${DRIVE_CONFIG_FOLDER_LIST[$RESTORE_SOURCE]}_bak_$(date +%F)"
      ;;
    *)
      echo "${RED}Unexpected error!${NONE}"
      exit 1
      ;;
  esac
}

function keep_old_git {
  while ! check_yes_no $DELETE_OLD_CONFIG
  do
    read -p "Do you want to keep the old folder? [Y|n] " DEL
    DEL=${DELETE_OLD_CONFIG:-y}
  done

  case $DELETE_OLD_CONFIG in
    y|Y)
      echo "Old folder is located at $HOME/${GITHUB_CONFIG_FOLDER_LIST[$RESTORE_SOURCE]}_bak_$(date +%F)" | tee -a "$HOME/backup_log/$(date +%F).log"
      ;;
    n|N)
      echo "Deleting backup" | tee -a "$HOME/backup_log/$(date +%F).log"
      rm -r "$HOME/${GITHUB_CONFIG_FOLDER_LIST[$RESTORE_SOURCE]}_bak_$(date +%F)"
      ;;
    *)
      echo "${RED}Unexpected error!${NONE}"
      exit 1
      ;;
  esac
}

function restore_git_existing {
  choose_config_git
  
  echo "Backing up the current ${GITHUB_CONFIG_FOLDER_LIST[$RESTORE_SOURCE]} folder" | tee -a "$HOME/backup_log/$(date +%F).log"
  cp "$HOME/${GITHUB_CONFIG_FOLDER_LIST[$RESTORE_SOURCE]}" "$HOME/${GITHUB_CONFIG_FOLDER_LIST[$RESTORE_SOURCE]}_bak_$(date +%F)"

  echo "Restoring ${GITHUB_CONFIG_FOLDER_LIST[$RESTORE_SOURCE]}" | tee -a "$HOME/backup_log/$(date +%F).log"
  git -C "$HOME/${GITHUB_CONFIG_FOLDER_LIST[$RESTORE_SOURCE]}$LOCAL_FOLDER_APPEND" fetch --all | tee -a "$HOME/backup_log/$(date +%F).log"
  git -C "$HOME/${GITHUB_CONFIG_FOLDER_LIST[$RESTORE_SOURCE]}$LOCAL_FOLDER_APPEND" reset --hard origin/master | tee -a "$HOME/backup_log/$(date +%F).log"

  keep_old_git
}

function restore_git_new {
  echo "Checking SSH key" | tee -a "$HOME/backup_log/$(date +%F).log"
  if [[ -f "$HOME/.ssh/github_id_rsa" ]]
  then
    choose_config_git

    if [[ -d "$HOME/${GITHUB_CONFIG_FOLDER_LIST[$RESTORE_SOURCE]}$LOCAL_FOLDER_APPEND/.git" ]]
    then
      echo -e "${RED}ERROR!${NONE} ${GITHUB_CONFIG_FOLDER_LIST[$RESTORE_SOURCE]} is already a git repository" | tee -a "$HOME/backup_log/$(date +%F).log"
      echo "Please use restore mode 1" | tee -a "$HOME/backup_log/$(date +%F).log"
    else
      echo "Backing up the current ${GITHUB_CONFIG_FOLDER_LIST[$RESTORE_SOURCE]} folder" | tee -a "$HOME/backup_log/$(date +%F).log"
      cp "$HOME/${GITHUB_CONFIG_FOLDER_LIST[$RESTORE_SOURCE]}" "$HOME/${GITHUB_CONFIG_FOLDER_LIST[$RESTORE_SOURCE]}_bak_$(date +%F)"

      echo "Removing broken config" | tee -a "$HOME/backup_log/$(date +%F).log"
      rm -r "$HOME/$RESTORE_SOURCE$LOCAL_FOLDER_APPEND"
      echo "Restoring ${GITHUB_CONFIG_FOLDER_LIST[$RESTORE_SOURCE]}" | tee -a "$HOME/backup_log/$(date +%F).log"
      git -C "$HOME" clone "https://github.com/$USER/${GITHUB_REPO_LIST[$RESTORE_SOURCE]}" "$HOME/$RESTORE_SOURCE$LOCAL_FOLDER_APPEND" | tee -a "$HOME/backup_log/$(date +%F).log"

      keep_old_git
    fi
  else
    echo -e "${RED}ERROR!${NONE} Please set up a SSH key pair" | tee -a "$HOME/backup_log/$(date +%F).log"
  fi
}

function restore_drive {
  choose_config_drive

  echo "Backing up the current ${DRIVE_CONFIG_FOLDER_LIST[$RESTORE_SOURCE]} folder" | tee -a "$HOME/backup_log/$(date +%F).log"
  cp "$HOME/${DRIVE_CONFIG_FOLDER_LIST[$RESTORE_SOURCE]}" "$HOME/${GITHUB_CONFIG_FOLDER_LIST[$RESTORE_SOURCE]}_bak_$(date +%F)"
  rm "$HOME/${DRIVE_CONFIG_FOLDER_LIST[$RESTORE_SOURCE]}$LOCAL_FOLDER_APPEND/*"

  echo "Restoring ${DRIVE_CONFIG_FOLDER_LIST[$RESTORE_SOURCE]}" | tee -a "$HOME/backup_log/$(date +%F).log"
  rclone copy "$REMOTE":"${DRIVE_REMOTE_FOLDER_LIST[$RESTORE_SOURCE]}" "$HOME/${DRIVE_CONFIG_FOLDER_LIST[$RESTORE_SOURCE]}$LOCAL_FOLDER_APPEND" --transfers=1 --log-file="$HOME/backup_log/$(date +%F).log" --log-level=INFO

  keep_old_drive
}

function restore_backup {
  SOURCE_OPTIONS=0
  RESTORE_SOURCE=999

  case $ACTION in
  	1)
  		restore_git_existing
  		;;
  	2)
  		restore_git_new
  		;;
  	3)
  		restore_drive
  		;;
  	4)
  		restore_drive
  		;;
  	*)
  		## Wrong action chosen
  		echo "${RED}Something went wrong while calculating the right restore action${NONE}" | tee -a "$HOME/backup_log/$(date +%F).log"
  		;;
  esac
}

### RESTORE SCRIPT
YELLOW='\033[0;33m'
RED='\033[0;31m'
NONE='\033[0m'

choose_source
choose_mode
determine_action
restore_backup
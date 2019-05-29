#!/bin/sh

GIT=git

alinode_has() {
  type "$1" > /dev/null 2>&1
  return $?
}

alinode_temp_dir() {
  echo `pwd`"/tmp-"`echo $RANDOM`
  return $?
}

alinode_download() {
  if alinode_has "wget"; then
    ARGS=$(echo "$*" | sed -e 's/--progress-bar /--progress=bar /' \
                           -e 's/-L //' \
                           -e 's/-I //' \
                           -e 's/-s /-q /' \
                           -e 's/-o /-O /' \
                           -e 's/-C - /-c /')
    wget $ARGS
  else
    echo "Please install 'wget' command"
  fi
}

alinode_pre_install() {
  if [[ $- == *i* ]];
  then
    echo
  else
    echo
    echo 'Usage:'
    echo '  bash -i alinode_all.sh'
    exit
  fi

  if alinode_has $GIT; then
    echo
  elif alinode_has "wget"; then
    echo
  else
    echo >&2 "Please install 'git', 'wget', 'unzip' command, then run 'bash -i alinode_all.sh' "
    echo
    exit 1
  fi
}

# Param Default Intro
alinode_read_para() {
  echo $3  >&2
  echo Please input $1 [default: $2] >&2

  read PARA
  if [ "$PARA" =  "" ]; then
    VAR=$2
  else
    VAR=$PARA
  fi
  echo "$1 set: $VAR"  >&2
  echo $VAR
}

alinode_read_array_para() {
  read args
  if [ -z "$args" ]; then
    echo []
  else
    para=""
    for a in $args
      do fa="\"$a\", "
        para="$para$fa"
    done
    para=`echo ${para::-2}`

    para=[$para]
    echo $para
  fi
}

alinode_install_tnvm() {
  echo 'Install tnvm...'
  echo
  echo "Use Aliyun ECS server (y/n)?"
  read IS_ECS
  if [ "$IS_ECS" = y -o "$IS_ECS" = Y -o "$IS_ECS" = "" ]; then
    echo
  else
    echo 'BTW, you can try Aliyun ECS for better install speed......'
    echo
  fi

  if alinode_has $GIT; then
    TMP_TNVM_DIR=`alinode_temp_dir`
    git clone https://github.com/aliyun-node/tnvm.git $TMP_TNVM_DIR
    mv -f $TMP_TNVM_DIR/install.sh ./
    rm -rf $TMP_TNVM_DIR
  else
    TNVM_SOURCE="https://raw.githubusercontent.com/aliyun-node/tnvm/master/install.sh"
    alinode_download -s "$TNVM_SOURCE" -o "./install.sh"
  fi
  # issue of bashrc, require delete
  sed -i '/exec bash/d' ./install.sh
  sed -i '/source "$NVM_PROFILE"/d' ./install.sh

  chmod a+x ./install.sh
  ./install.sh

  source ~/.bashrc
  rm ./install.sh
}

alinode_install_alinode() {
  PACKAGE=`alinode_read_para 'packages optional: alinode/node/iojs' alinode ""`
  echo
  echo 'selected:' $PACKAGE
  echo 'Please select version:'
  CHOICES=`tnvm lookup|awk '{print $6 "--base on node-" $9}'`
  echo
  for CHOICE in $CHOICES
    do
      echo $CHOICE
      DEFAULT_PACKAGE=$CHOICE
  done

  # remove color information
  DEFAULT_PACKAGE=`echo $DEFAULT_PACKAGE|sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g"|awk -F "--" '{print $1}'`

  INSTALL_PACKAGE=`alinode_read_para "$PACKAGE version(e.g, alinode-v1.0.0)" $DEFAULT_PACKAGE "" `
  tnvm install $INSTALL_PACKAGE
  tnvm use $INSTALL_PACKAGE

  if [ "$PACKAGE" = "alinode" ]; then
    echo alinode inner version: `node -p "process.alinode"` node version: `node -v`
  else
    echo $PACKAGE version: `node -v`
  fi
}

alinode_install_cnpm() {
  if ! alinode_has "cnpm"; then
    echo
    echo "Install cnpm for better speed..."
    npm install -g cnpm --registry=http://registry.npm.taobao.org
  fi
}

alinode_install_agenthub() {
  echo
  echo 'Install agenthub...'
  if alinode_has "cnpm"; then
    cnpm install @alicloud/agenthub -g
  else
    npm install @alicloud/agenthub -g
  fi
}

config_hint_id_token() {
  echo 'To get your APP Id and Token:'
  echo
  echo 'visit https://node.console.aliyun.com/'
}

config_hint_logdir() {
  echo 'set alinode log dir...'
  echo
  echo -e '\e[31mNotice: ***Must be same with NODE_LOG_DIR of start up***\e[0m'
  echo -e '\e[31m      ***Use /tmp/ dir if without NODE_LOG_DIR set  ***\e[0m'
}

config_hint_error_log() {
  echo 'Please input error_log dir'
  echo -e '\e[31merror_log is your application log，with stack information\e[0m'
  echo -e '\e[31m格式: /path/to/your/error_log/error.#YYYY-#MM-#DD.log\e[0m'
  echo -e '\e[31m多于1个error_log，以空格分隔\e[0m'
  echo -e '\e[31mIgnore with enter\e[0m'
}

config_hint_packages() {
  echo 'Please input dependency dir'
  echo -e '\e[31mdependency is your denpendency information\e[0m'
  echo -e '\e[31mFormat: /path/to/your/error_log/yourdep.json\e[0m'
  echo -e '\e[31mSplit with space if more than 1\e[0m'
  echo -e '\e[31mIgnore with enter\e[0m'
}

alinode_configure_agenthub() {
  echo
  echo 'configure agenthub...'
  echo
  config_hint_id_token
  echo
  echo 'Please input your App ID'
  read APP_ID
  echo 'Your App ID: ' $APP_ID
  echo
  echo 'Please input App Token'
  read APP_TOKEN
  echo 'App Token: ' $APP_TOKEN
  echo

  config_hint_logdir
  LOG_DIR=`alinode_read_para "alinode log dir " "/tmp/" ""`

  config_hint_error_log
  err=`alinode_read_array_para`

  config_hint_packages
  dep=`alinode_read_array_para`

  DEFAULT_CFG_DIR=`pwd`
  CFG_DIR=`alinode_read_para "Configuration dir " $DEFAULT_CFG_DIR  ""`
  CFG_PATH=$CFG_DIR'/yourconfig.json'
  touch $CFG_PATH
  > $CFG_PATH

  echo   { >> $CFG_PATH
  echo   "  "\"server\":            \"agentserver.node.aliyun.com:8080\", >> $CFG_PATH
  echo   "  "\"appid\":             \"$APP_ID\", >> $CFG_PATH
  echo   "  "\"secret\":            \"$APP_TOKEN\", >> $CFG_PATH
  echo   "  "\"logdir\":            \"$LOG_DIR\", >> $CFG_PATH
  echo   "  "\"reconnectDelay\":    10, >> $CFG_PATH
  echo   "  "\"heartbeatInterval\": 60, >> $CFG_PATH
  echo   "  "\"reportInterval\":    60, >> $CFG_PATH
  echo   "  "\"error_log\":         $err, >>$CFG_PATH
  echo   "  "\"packages\":          $dep >>$CFG_PATH
  echo   } >> $CFG_PATH

  echo
  echo Your configuration below, you can modify by change $CFG_PATH
  cat $CFG_PATH
}

alinode_post_install() {
  echo
  echo 'to start agenthub with below, enjoy alinode':
  echo
  echo '    nohup agenthub' $CFG_PATH '&'
  echo
  exec bash
}


alinode_pre_install
alinode_install_tnvm
alinode_install_alinode
alinode_install_cnpm
alinode_install_agenthub
alinode_configure_agenthub
alinode_post_install

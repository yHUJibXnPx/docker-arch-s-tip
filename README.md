# docker-arch-s-tip
docker multi-arch s-tip 本项目通过 Docker 构建了一个多架构连接服务器并执行命令邮件反馈的测试容器，用于探索连接远程服务器以及邮件发送。

![Watchers](https://img.shields.io/github/watchers/yHUJibXnPx/docker-arch-s-tip) ![Stars](https://img.shields.io/github/stars/yHUJibXnPx/docker-arch-s-tip) ![Forks](https://img.shields.io/github/forks/yHUJibXnPx/docker-arch-s-tip) ![Vistors](https://visitor-badge.laobi.icu/badge?page_id=yHUJibXnPx.docker-arch-s-tip) ![LICENSE](https://img.shields.io/badge/license-MIT-green.svg)
<!-- <a href="https://star-history.com/#yHUJibXnPx/docker-arch-s-tip&Date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=yHUJibXnPx/docker-arch-s-tip&type=Date&theme=dark" />
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=yHUJibXnPx/docker-arch-s-tip&type=Date" />
    <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=yHUJibXnPx/docker-arch-s-tip&type=Date" />
  </picture>
</a> -->
<!-- START_STAR_HISTORY_SELF -->
![Star History Chart](./star_history_self.png)
<!-- END_STAR_HISTORY_SELF -->

## 目录结构

项目工作目录如下：
```plaintext
.
├── .env.amd64                 # amd64 环境配置模板，改名为 .env 后使用
├── .env.arm64                 # arm64 环境配置模板，改名为 .env 后使用
├── custom_scripts             # 自定义脚本目录，挂载到容器内 /scripts/
│   ├── check_disk.sh          # 示例：磁盘容量预警推送
│   ├── check_singbox.sh       # 示例：sing-box 版本更新提醒推送
│   └── system_info.sh         # 示例：系统信息推送
├── secrets                    # 敏感信息目录（内容不会被 git 追踪）
│   ├── hosts.json             # 服务器列表模板
│   ├── tg_token.txt           # Telegram Token 模板
│   └── mail_pass.txt          # 邮件密码模板
├── docker-compose.yml         # Docker Compose 编排配置
├── Dockerfile                 # Docker 镜像构建说明
├── LICENSE                    # 许可协议
├── README.md                  # 本文档
├── requestment.txt            # Python脚本所需依赖  
├── make_star_chart.py         # 生成 星星统计 脚本 
└── scripts                    # 内置脚本目录
    ├── common.sh              # 公共日志和辅助函数
    ├── configure-cron.sh      # 容器入口，负责初始化 cron 调度
    └── s-tip.sh               # 核心：SSH 巡检 + 推送
```

## 特点

- **多架构连接服务器并执行命令邮件反馈的测试测试**  
  实验测试构建多架构连接服务器并执行命令邮件反馈的测试镜像需求。  
  其中 .env 配置文件中 `CRON_SCHEDULE` 变量是任务调度配置，比如  
    - 0 8 * * * ，每8:00执行一次远程连接并执行信息反馈  
  
  其中 .env 配置文件中 `HOSTS_JSON` 变量是服务器及其登陆相关参数配置  
    - .env 传参数需要使用压缩的 json 格式，多条server格式示例如下  
  ```json
  {"info":[{"host":"server1.com","username":"root","port":22,"password":"123456","script_file":["/scripts/check_disk.sh","/scripts/system_info.sh"],"script":"uname -a"},{"host":"server2.com","username":"root","port":8022,"password":"123456","script_file":"/scripts/check_singbox.sh"},{"host":"server3.com","username":"root","port":22,"password":"123456"}]}
  ```

    - 它的扩展格式如下，可以编辑好之后再进行json压缩，填入 .env  
      - `host` 必填，服务器 ip 或 domain
      - `username` 必填，服务器登陆 用户名
      - `port` 必填，服务器 ssh 端口
      - `password` 必填，服务器登陆 密码
      - `script` 可选，自定义 `script` 单行命令与 `.env` 的 `SCRIPT` 变量等效
      - `script_file` 可选，自定义脚本文件，指向容器内路径 `/scripts` 即可，默认对应宿主机映射路径 `./custom_scripts`
  ```json
  {
    "info": [
      {
        "host": "server1.com",
        "username": "root",
        "port": 22,
        "password": "123456",
        "script_file": [
          "/scripts/check_disk.sh",
          "/scripts/system_info.sh"
        ],
        "script": "uname -a"
      },
      {
        "host": "server2.com",
        "username": "root",
        "port": 8022,
        "password": "123456",
        "script_file": "/scripts/check_singbox.sh"
      },
      {
        "host": "server3.com",
        "username": "root",
        "port": 22,
        "password": "123456"
      }
    ]
  }
  ```
  其中 .env 配置文件中 `SCRIPT` 变量是远程执行命令，比如  
    - 进入主目录 然后检查cpu系统架构等相关信息，然后退出  
  ```bash
  echo '=== system ===' ; uname -a ; echo '=== disk ===' ; df -h ; echo '=== time ===' ; date ; echo '=== ps ===' ; ps
  ```
  其中 .env 配置文件中 `ENABLE_TG` 变量是 telegram 的推送开关控制变量，默认 true 开启  
  其中 .env 配置文件中 `TELEGRAM_TOKEN` 变量是 telegram 的 api 调用 token 通过 @BotFather 获取  
  其中 .env 配置文件中 `TELEGRAM_USERID` 变量是  telegram 的 user id 通过 @userinfobot 或 @HaxTG_bot 获取  
  其中 .env 配置文件中 `ENABLE_EMAIL` 变量是 email 的推送开关控制变量，默认 true 开启  
  其中 .env 配置文件中 `AUTHTYPE` 变量是认证方式，通过端口判断，默认是 password 也可以选择 oauth2   
  其中 .env 配置文件中 `MAILADDR` 变量是邮箱服务器域名  
  其中 .env 配置文件中 `MAILPORT` 变量是邮箱服务器端口   
  其中 .env 配置文件中 `MAILUSERNAME` 变量是邮箱服务器登录账号  
  其中 .env 配置文件中 `MAILFROM` 变量是发件人邮箱  
  其中 .env 配置文件中 `MAILPASSWORD` 变量是邮箱服务器登录密码  
  其中 .env 配置文件中 `MAILSENDTO` 变量是收件人邮箱  

## 密钥安全配置

本项目支持两种方式传入敏感信息（SSH 密码、Telegram Token、邮件密码），**二选一，不可同时设置**：

### 方式一：明文写入 `.env`（仅用于本地测试）

直接在 `.env` 文件里填写明文值，简单快捷，但密码会随 Docker 环境变量暴露，**不建议在生产环境使用**：

```env
HOSTS_JSON={"info":[{"host":"your-server.com","username":"root","port":22,"password":"your-password"}]}
TELEGRAM_TOKEN=123456:ABCdef...
MAILPASSWORD=your-mail-password
```

### 方式二：Docker Secret 文件（推荐，适合生产部署）

将敏感信息写入独立文件，由 Docker 以只读方式挂载到容器内，`.env` 中只填写文件路径：

**第一步：复制模板并填写真实内容**

```bash
# 服务器列表
cp secrets/hosts.json.example secrets/hosts.json

# Telegram Token（只需一行 token，不含引号）
cp secrets/tg_token.txt.example secrets/tg_token.txt

# 邮件密码（只需一行密码，不含引号）
cp secrets/mail_pass.txt.example secrets/mail_pass.txt
```

**第二步：编辑各文件，填入真实值**

`secrets/hosts.json` 格式：
```json
{"info":[{"host":"server1.com","username":"root","port":22,"password":"123456","script_file":["/scripts/check_disk.sh","/scripts/system_info.sh"],"script":"uname -a"},{"host":"server2.com","username":"root","port":8022,"password":"123456","script_file":"/scripts/check_singbox.sh"},{"host":"server3.com","username":"root","port":22,"password":"123456"}]}
```

`secrets/tg_token.txt`：123456789:ABCdefGHIjklMNOpqrSTUvwxYZ
`secrets/mail_pass.txt`：your-real-mail-password

**第三步：确认 `.env` 中使用文件路径而非明文**

```env
# 注释掉明文，启用文件路径
# HOSTS_JSON=...
HOSTS_JSON_FILE=/run/secrets/hosts.json

# TELEGRAM_TOKEN=...
TELEGRAM_TOKEN_FILE=/run/secrets/tg_token.txt

# MAILPASSWORD=...
MAILPASSWORD_FILE=/run/secrets/mail_pass.txt
```

> **注意**：如果不想 `secrets/` 里的真实文件被 git 追踪。需要在 `.gitignore` 添加以下内容忽略保护，让真实文件不会被 git 追踪。
> 请勿将填写了真实密码的文件 commit 进版本库。
```plaintext
# 忽略 secrets 目录下所有真实文件，只保留模板
secrets/*
!secrets/*.example
```

## 快速入门

### 通过 docker-compose 文件启动（如果你在 docker-compose.yml 中配置了服务）：

修改环境文件比如 .env.arm64 修改完善后，改名为 .env 以支持 docker-compose.yml 文件

```bash
docker-compose up
```

### 使用 Secret 文件模式启动（推荐）

完成密钥配置后（见上方"密钥安全配置"章节），直接启动即可：

```bash
# 复制并重命名配置文件
cp .env.arm64 .env   # arm64 机器
# cp .env.amd64 .env  # amd64 机器

# 确认 secrets/ 目录下的文件已就绪
ls secrets/
# 应看到：hosts.json  tg_token.txt  mail_pass.txt

# 启动
docker compose up -d

# 查看日志
docker logs -f s_tip_container
```

### 通过 docker 启动 s-tip 服务

项目中通过 `tini` 执行 `configure-cron.sh` 启动 s-tip 服务。你可以直接进入容器后执行脚本，或在 Docker Compose 设置中指定此命令。启动后，查看打印反馈信息和邮件接收情况。

例如，通过 docker 运行容器：

```bash
docker run --rm -it ghcr.io/yhujibxnpx/docker-arch-s-tip:latest tini -- "/usr/local/bin/configure-cron.sh"
```

## 构建 Docker 镜像

你可能需要一些前置条件，比如 docker compose buildx 环境的部署
稍微说一下吧，点到为止  
比如我的机器是 Ubuntu 24.04 LTS (GNU/Linux 6.8.0-57-generic aarch64)

  - **docker 部署过程如下：**

```bash
# 系统可以使用官方一键安装脚本 https://github.com/docker/docker-install
curl -fsSL https://test.docker.com -o test-docker.sh
sh test-docker.sh
# Manage Docker as a non-root user
## 非 root 用户需要加入到 docker 组才有权限使用
# Create the docker group
## 添加 docker 组
sudo groupadd docker
# Add your user to the docker group.
## 将当前用户加入到 docker 组权限
sudo usermod -aG docker ${USER}
# Log out and log back in so that your group membership is re-evaluated.
## 临时进入 docker 组测试，更好的方式是退出并重新登录测试
newgrp docker 
# Configure Docker to start on boot
# 启用 docker 开机自启动服务
sudo systemctl enable docker.service
sudo systemctl enable containerd.service
# satrt
# 开启 docker 服务，其实上一步就启用了
sudo systemctl start docker.service
sudo systemctl start containerd.service
# Verify that Docker Engine is installed correctly by running the hello-world image
# 测试 docker hello-world:latest 打印
docker run --rm hello-world:latest
```

  - **compose 部署更新过程如下：**

```bash
# GitHub 项目 URI
URI="docker/compose"

# 获取最新版本
VERSION=$(curl -sL "https://github.com/${URI}/releases" | grep -Eo '/releases/tag/[^"]+' | awk -F'/tag/' '{print $2}' | head -n 1)
echo "Latest version: ${VERSION}"

# 获取操作系统和架构信息
OS=$(uname -s)
ARCH=$(uname -m)

# 映射平台到官方命名
case "${OS}" in
  Linux)
    PLATFORM="linux"
    if [[ "${ARCH}" == "arm64" || "${ARCH}" == "aarch64" ]]; then
      ARCH="aarch64"
    elif [[ "${ARCH}" == "x86_64" ]]; then
      ARCH="x86_64"
    else
      echo "Unsupported architecture: ${ARCH}"
      echo 'should exit 1'
    fi
    ;;
  *)
    echo "Unsupported OS: ${OS}"
    echo 'should exit 1'
    ;;
esac

# 输出最终平台和架构
echo "Platform: ${PLATFORM}"
echo "Architecture: ${ARCH}"

# 拼接下载链接和校验码链接
TARGET_FILE="docker-compose-${PLATFORM}-${ARCH}"
SHA256_FILE="${TARGET_FILE}.sha256"
URI_DOWNLOAD="https://github.com/${URI}/releases/download/${VERSION}/${TARGET_FILE}"
URI_SHA256="https://github.com/${URI}/releases/download/${VERSION}/${SHA256_FILE}"
echo "Download URL: ${URI_DOWNLOAD}"
echo "SHA256 URL: ${URI_SHA256}"

# 检查文件是否存在
if [[ -f "/tmp/${TARGET_FILE}" ]]; then
  echo "File already exists: /tmp/${TARGET_FILE}"
  
  # 删除旧的 SHA256 文件（如果存在）
  if [[ -f "/tmp/${SHA256_FILE}" ]]; then
    echo "Removing old SHA256 file: /tmp/${SHA256_FILE}"
    rm -fv "/tmp/${SHA256_FILE}"
  fi

  # 下载新的 SHA256 文件
  echo "Downloading SHA256 file..."
  curl -L -C - --retry 3 --retry-delay 5 --progress-bar -o "/tmp/${SHA256_FILE}" "${URI_SHA256}"

  # 校验文件完整性
  # shasum 校验依赖 perl 可能 linux 系统需要手动安装
  echo "Verifying file integrity for /tmp/${TARGET_FILE}..."
  cd /tmp
  if ! shasum -a 256 -c "${SHA256_FILE}"; then
    log_warning "SHA256 checksum failed. Removing file and retrying..."
    rm -fv "/tmp/${TARGET_FILE}"
  else
    echo "File integrity verified successfully."
  fi
fi

# 如果文件不存在或之前校验失败
if [[ ! -f "/tmp/${TARGET_FILE}" ]]; then
  echo "Downloading file..."
  curl -L -C - --retry 3 --retry-delay 5 --progress-bar -o "/tmp/${TARGET_FILE}" "${URI_DOWNLOAD}"

  # 删除旧的 SHA256 文件并重新下载
  if [[ -f "/tmp/${SHA256_FILE}" ]]; then
    echo "Removing old SHA256 file: /tmp/${SHA256_FILE}"
    rm -fv "/tmp/${SHA256_FILE}"
  fi
  echo "Downloading SHA256 file..."
  curl -L --progress-bar -o "/tmp/${SHA256_FILE}" "${URI_SHA256}"

  # 校验完整性
  # shasum 校验依赖 perl 可能 linux 系统需要手动安装
  echo "Verifying file integrity for /tmp/${TARGET_FILE}..."
  cd /tmp
  if ! shasum -a 256 -c "${SHA256_FILE}"; then
    echo "Download failed: SHA256 checksum does not match."
    echo 'should exit 1'
  else
    echo "File integrity verified successfully."
  fi
fi

sudo mv -fv "/tmp/${TARGET_FILE}" /usr/local/bin/docker-compose
# Apply executable permissions to the binary
## 赋予执行权
sudo chmod -v +x /usr/local/bin/docker-compose
# create a symbolic link to /usr/libexec/docker/cli-plugins/
# 创建插件目录和软链接
sudo mkdir -pv /usr/libexec/docker/cli-plugins/
sudo ln -sfv /usr/local/bin/docker-compose /usr/libexec/docker/cli-plugins/docker-compose
# Test the installation.
## 测试版本打印
docker-compose version
docker compose version
```

  - **buildx 部署更新过程如下：**

```bash
# GitHub 项目 URI
URI="docker/buildx"

# 获取最新版本
VERSION=$(curl -sL "https://github.com/${URI}/releases" | grep -Eo '/releases/tag/[^"]+' | awk -F'/tag/' '{print $2}' | head -n 1)
echo "Latest version: ${VERSION}"

# 获取操作系统和架构信息
OS=$(uname -s)
ARCH=$(uname -m)

# 映射平台到官方命名
case "${OS}" in
  Linux)
    PLATFORM="linux"
    if [[ "${ARCH}" == "arm64" || "${ARCH}" == "aarch64" ]]; then
      ARCH="arm64"
    elif [[ "${ARCH}" == "x86_64" ]]; then
      ARCH="amd64"
    else
      echo "Unsupported architecture: ${ARCH}"
      echo 'should exit 1'
    fi
    ;;
  *)
    echo "Unsupported OS: ${OS}"
    echo 'should exit 1'
    ;;
esac

# 输出最终平台和架构
echo "Platform: ${PLATFORM}"
echo "Architecture: ${ARCH}"

# 拼接下载链接和校验码链接
TARGET_FILE="buildx-${VERSION}.${PLATFORM}-${ARCH}"
SHA256_FILE="${TARGET_FILE}.sbom.json"
URI_DOWNLOAD="https://github.com/${URI}/releases/download/${VERSION}/${TARGET_FILE}"
URI_SHA256="https://github.com/${URI}/releases/download/${VERSION}/${SHA256_FILE}"
echo "Download URL: ${URI_DOWNLOAD}"
echo "SHA256 URL: ${URI_SHA256}"

# 检查文件是否存在
if [[ -f "/tmp/${TARGET_FILE}" ]]; then
  echo "File already exists: /tmp/${TARGET_FILE}"
  
  # 删除旧的 SHA256 文件（如果存在）
  if [[ -f "/tmp/${SHA256_FILE}" ]]; then
    echo "Removing old SHA256 file: /tmp/${SHA256_FILE}"
    rm -fv "/tmp/${SHA256_FILE}"
  fi

  # 下载新的 SHA256 文件
  echo "Downloading SHA256 file..."
  curl -L -C - --retry 3 --retry-delay 5 --progress-bar -o "/tmp/${SHA256_FILE}" "${URI_SHA256}"
  # 提取校验码
  CHECKSUM=$(cat "/tmp/${SHA256_FILE}" | jq -r --arg filename "${TARGET_FILE}" '.subject[] | select(.name == $filename) | .digest.sha256')
  # 将校验码写入源文件
  echo "${CHECKSUM} *${TARGET_FILE}" > "/tmp/${SHA256_FILE}"
  echo "校验码 ${CHECKSUM} 已写入文件: /tmp/${SHA256_FILE}"

  # 校验文件完整性
  # shasum 校验依赖 perl 可能 linux 系统需要手动安装
  echo "Verifying file integrity for /tmp/${TARGET_FILE}..."
  cd /tmp
  if ! shasum -a 256 -c "${SHA256_FILE}"; then
    log_warning "SHA256 checksum failed. Removing file and retrying..."
    rm -fv "/tmp/${TARGET_FILE}"
  else
    echo "File integrity verified successfully."
  fi
fi

# 如果文件不存在或之前校验失败
if [[ ! -f "/tmp/${TARGET_FILE}" ]]; then
  echo "Downloading file..."
  curl -L -C - --retry 3 --retry-delay 5 --progress-bar -o "/tmp/${TARGET_FILE}" "${URI_DOWNLOAD}"

  # 删除旧的 SHA256 文件并重新下载
  if [[ -f "/tmp/${SHA256_FILE}" ]]; then
    echo "Removing old SHA256 file: /tmp/${SHA256_FILE}"
    rm -fv "/tmp/${SHA256_FILE}"
  fi
  echo "Downloading SHA256 file..."
  curl -L --progress-bar -o "/tmp/${SHA256_FILE}" "${URI_SHA256}"
  # 提取校验码
  CHECKSUM=$(cat "/tmp/${SHA256_FILE}" | jq -r --arg filename "${TARGET_FILE}" '.subject[] | select(.name == $filename) | .digest.sha256')
  # 将校验码写入源文件
  echo "${CHECKSUM} *${TARGET_FILE}" > "/tmp/${SHA256_FILE}"
  echo "校验码 ${CHECKSUM} 已写入文件: /tmp/${SHA256_FILE}"

  # 校验完整性
  # shasum 校验依赖 perl 可能 linux 系统需要手动安装
  echo "Verifying file integrity for /tmp/${TARGET_FILE}..."
  cd /tmp
  if ! shasum -a 256 -c "${SHA256_FILE}"; then
    echo "Download failed: SHA256 checksum does not match."
    echo 'should exit 1'
  else
    echo "File integrity verified successfully."
  fi
fi

sudo mv -fv "/tmp/${TARGET_FILE}" /usr/local/bin/docker-buildx
# Apply executable permissions to the binary
## 赋予执行权
sudo chmod -v +x /usr/local/bin/docker-buildx
# create a symbolic link to /usr/libexec/docker/cli-plugins/
# 创建插件目录和软链接
sudo mkdir -pv /usr/libexec/docker/cli-plugins/
sudo ln -sfv /usr/local/bin/docker-buildx /usr/libexec/docker/cli-plugins/docker-buildx
# Test the installation.
## 测试版本打印
docker-buildx version
docker buildx version
```

  - **scout-cli 部署更新过程如下：**
  Docker Scout 是一组集成到 Docker 用户界面和命令行界面 （CLI） 中的软件供应链功能。这些功能提供了对容器映像的结构和安全性的全面可见性。 此存储库包含 CLI 插件的可安装二进制文件。
  ```bash
mkdir -pv $HOME/.docker
curl -sSfL https://raw.githubusercontent.com/docker/scout-cli/main/install.sh | sh -s --
  ```
  1. scout-cli 使用例子，登陆docker账号，其中 `yHUJibXnPx` 换成你自己的
  ```bash
docker login -u yHUJibXnPx
  ```
  2. 注册到已知的组织单位，如果你有的话，没有可以不执行
  ```bash
docker scout enroll ORG_NAME
  ```
  3. 快速查看镜像
  ```bash
docker scout quickview hello-world:latest
  ```
  会返回以下信息，其中漏洞等级含义如下
  | CVSS分数    | 漏洞等级   |
  |------------|--------------|
  | 9.0 – 10.0 | **关键** (C) |
  | 7.0 – 8.9  | **高** (H)   |
  | 4.0 – 6.9  | **中** (M)   |
  | 0.1 – 3.9  | **低** (L)   |
  ```plaintext
    ✓ Image stored for indexing
    ✓ Indexed 0 packages
    ✓ 1 exception obtained

    i Base image was auto-detected. To get more accurate results, build images with max-mode provenance attestations.
      Review docs.docker.com ↗ for more information.

  Target   │  hello-world:latest  │    0C     0H     0M     0L   
    digest │  1b44b5a3e06a        │                              

What's next:
    Include policy results in your quickview by supplying an organization → docker scout quickview hello-world:latest --org <organization>
  ```
  4. 检测镜像漏洞
  ```bash
docker scout cves --only-package hello-world:latest
  ```
  会返回以下内容，
  ```plaintext
    ✓ SBOM of image already cached, 1183 packages indexed
    ✓ No vulnerable package detected


## Overview

                    │       Analyzed Image         
────────────────────┼──────────────────────────────
  Target            │                              
    digest          │  4fbad79ded98                
    platform        │ linux/amd64                  
    vulnerabilities │    0C     0H     0M     0L   
    size            │ 1.1 GB                       
    packages        │ 0                            


## Packages and Vulnerabilities

  No vulnerable packages detected
  ```
  5. 比较两个镜像的安全性与依赖差异，比如 hello-world 不同版本间的比较(`docker scout compare`是实验性功能，未来会有变化)
  ```bash
# pull 两个不同版本 
docker pull hello-world:latest
docker pull hello-world:nanoserver:1709
# 比较
docker scout compare --to hello-world:latest hello-world:nanoserver1709
  ```
  会返回以下内容，
  ```plaintext
    ! 'docker scout compare' is experimental and its behaviour might change in the future
    ✓ Pulled
    ✓ Image stored for indexing
    ✓ Indexed 1 packages
    ✓ SBOM of image already cached, 0 packages indexed
    ✓ 1 exception obtained
    ✓ 1 exception obtained
  
  
  ## Overview
  
                      │        Analyzed Image        │      Comparison Image        
  ────────────────────┼──────────────────────────────┼──────────────────────────────
    Target            │  hello-world:nanoserver1709  │  hello-world:latest          
      digest          │  786a29974908                │  1b44b5a3e06a                
      tag             │  nanoserver1709              │  latest                      
      platform        │ windows/amd64                │ linux/amd64                  
      vulnerabilities │    0C     0H     0M     0L   │    0C     0H     0M     0L   
                      │                              │                              
      size            │ 99 MB (+99 MB)               │ 2.5 kB                       
      packages        │ 1 (+1)                       │ 0                            
                      │                              │                              
  
  
  ## Environment Variables
  
  
    - PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
  
  
  
  ## Packages and Vulnerabilities
  
  
    +    1 packages added
  
  
  
  
     Package              Type   Version        Compared Version  
  
  +  runscripthelper.exe  nuget  10.0.16299.15
  ```

  - **docker buildx build 在项目目录下执行构建镜像具体流程命令 ：**

```bash
# docker proxy pull
## 配置 docker 代理，比如 http://192.168.255.253:7890
sudo mkdir -pv /etc/systemd/system/docker.service.d
cat << '469138946ba5fa' | sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=http://192.168.255.253:7890"
Environment="HTTPS_PROXY=http://192.168.255.253:7890"
Environment="NO_PROXY=localhost,127.0.0.1,192.168.255.0/24"
469138946ba5fa
sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl show --property=Environment docker

# docker login & config
## 使用 github 具有上传下载镜像权限 [write:packages(read:packages)] 的 token 登陆 github 并预配置用户和目录参数
echo '请输入具有上传下载镜像权限 [write:packages(read:packages)] 的 github token (不会显示输入内容):' ; read -sr GITHUB_TOKEN
echo '请输入 github 用户名(为空则默认是 yhujibxnpx ):' ; read -r USERNAME
echo '请输入你的 github 镜像存储源(为空则默认是 ghcr.io ):' ; read -r DOCKER_DOMAIN
echo '请输入 docker 项目存放的父目录(为空则默认目录 /media/psf/KingStonSSD1T/docker-workspace ):' ; read -r CUSTOM_DIR
echo '请输入你的 docker 项目名(为空则默认是我的仓库名即 docker-arch-s-tip ):' ; read -r REPO
echo '请输入你的 docker buildx 构建可能需要的大缓存存储目录(为空则默认目录 /media/psf/KingStonSSD1T/docker_buildx.cache ):' ; read -r BUILDX_CACHE

## 执行登陆和变量赋值解除
USERNAME=${USERNAME:-yhujibxnpx}
DOCKER_DOMAIN=${DOCKER_DOMAIN:-ghcr.io}
echo ${GITHUB_TOKEN} | docker login ${DOCKER_DOMAIN} -u ${USERNAME} --password-stdin ; unset GITHUB_TOKEN
CUSTOM_DIR=${CUSTOM_DIR:-'/media/psf/KingStonSSD1T/docker-workspace'}
REPO=${REPO:-docker-arch-s-tip}
BUILDX_CACHE=${BUILDX_CACHE:-'/media/psf/KingStonSSD1T/docker_buildx.cache'}

## 创建缓存目录和新缓存目录
mkdir -pv ${BUILDX_CACHE}
mkdir -pv ${BUILDX_CACHE}-new
echo ${USERNAME}
echo ${DOCKER_DOMAIN}
echo ${CUSTOM_DIR}/${REPO}
echo ${BUILDX_CACHE}
echo ${BUILDX_CACHE}-new

## 进入到项目目录
cd ${CUSTOM_DIR}/${REPO}

# stop and remove containerd
## 停止并移除当前运行容器
docker-compose stop
docker-compose rm -fv

# delete image tag
## 删除当前镜像，如果需要可以解除注释粘贴执行
#docker rmi ${DOCKER_DOMAIN}/${USERNAME}/${REPO}:latest

# All emulators:
## 多架构跨平台环境虚拟
docker run --privileged --rm tonistiigi/binfmt:master --install all
# Show currently supported architectures and installed emulators
docker run --privileged --rm tonistiigi/binfmt:master

# docker buildx 
## 使用 docker buildx 构建单/多架构镜像
# buildx create
## 停用删除已有的 builder
docker-buildx stop ${REPO}
docker-buildx rm -f ${REPO}
## 创建 buildx 构建节点并启用查看信息
#docker-buildx create --use
docker-buildx create --name ${REPO} --use
## 或者和上一步骤二选一如果最终测试不好也可以换用代理模式比如 192.168.255.253:7890 创建 buildx 构建节点并启用
docker buildx create --use --name ${REPO} \
  --driver docker-container \
  --driver-opt env.http_proxy=http://192.168.255.253:7890 \
  --driver-opt env.https_proxy=http://192.168.255.253:7890

## 实例启动后查看 builder 信息
docker-buildx inspect --bootstrap

#  说明：
#  --build-arg 可以用于为构建容器添加环境变量，比如代理环境
#    --build-arg HTTP_PROXY="http://192.168.255.253:7890" --build-arg HTTPS_PROXY="http://192.168.255.253:7890" --build-arg NO_PROXY="localhost,127.0.0.1,google.cn"
#  --platform linux/arm64/v8,linux/amd64 表示构建多个平台的镜像。
#  --tag 参数根据你自己的环境变量（例如 DOCKER_DOMAIN、USERNAME、REPO）设置镜像名称。
#  --no-cache 选项来避免使用过多的缓存，不要与 --cache-from 和 --cache-to 合用
#  --cache-from 从 ${BUILDX_CACHE} 目录中加载缓存数据，加速构建。
#  --cache-to 将新生成的缓存数据写入到 ${BUILDX_CACHE}-new 目录中。
#  --label 添加单镜像标签应该和 Dockerfile 中的 LABEL 等效
#  --load 表示将构建完成的镜像加载到 Docker 本地镜像库中（对于跨平台构建，注意在某些情况下可能只能加载当前体系结构的镜像）。
#  --push 表示将构建完成的镜像推送到 Docker 远端镜像库中 
#  --output 导出器以下是type参数信息
#    type=image 导出类型为 image 镜像 type=oci 则是导出镜像为 OCI 标准归档文件，允许在本地离线处理多架构镜像，脱离对实时网络连接的依赖。
#    name=ghcr.io/yhujibxnpx/docker-arch-s-tip:latest 镜像名
#    compression=zstd 压缩类型 zstd 也支持 gzip 和 estargz
#    compression-level=22 设置 zstd 压缩级别为 22 ，gzip 和 estargz 的范围是 0-9 ， zstd 的范围是 0-22
#    force-compression=true 强制重压缩
#  最近发现对于多架构镜像需要额外在 --output 中配置多架构标签属性 --label 仅适用于单架构情况 https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry#adding-a-description-to-multi-arch-images
#  --output 
#    annotation-index.org.opencontainers.image.description='' 多架构镜像注释标签
#    annotation-index.org.opencontainers.image.title='' 多架构镜像标题标签
#    annotation-index.org.opencontainers.image.version='' 多架构镜像版本标签
#    annotation-index.org.opencontainers.image.authors='' 多架构镜像作者标签
#    annotation-index.org.opencontainers.image.source='' 多架构镜像关联仓库标签
#    annotation-index.org.opencontainers.image.licenses='' 多架构镜像协议标签
#  最近发现云端镜像仓库有 unknown/unknown 未识别架构的问题，如下方案可以规避云端仓库 https://github.com/docker/buildx/issues/1964#issuecomment-1644634461
#  --output 导出器 type=oci-mediatypes=false 关闭OCI索引，然而失败了☹️，unknown/unknown 显示问题存在
#  --provenance=false 设置为不生成来源信息，但禁用 provenance 信息，意味着你失去了有关构建过程的详细记录和签名。这对追踪镜像的安全性和来源可能会有一些影响，可以解决 unknown/unknown 显示问题
#  参考 https://docs.docker.com/build/building/variables/#buildx_no_default_attestations
#  export BUILDX_NO_DEFAULT_ATTESTATIONS=1 添加环境变量禁用来源证明应该和 --provenance=false 等效，也可以解决 unknown/unknown 显示问题
#  综上，我觉得 unknown/unknown 也可以接受，就这样吧

# buildx build load
## 单架构本地存储，比如 linux/arm64/v8 ，压缩生成镜像
docker buildx build \
  --platform linux/arm64/v8 \
  --cache-from type=local,src=${BUILDX_CACHE} \
  --cache-to type=local,dest=${BUILDX_CACHE}-new,mode=max \
  --output type=image,name=${DOCKER_DOMAIN}/${USERNAME}/${REPO}:latest,compression=zstd,compression-level=22,force-compression=true \
  --tag ${DOCKER_DOMAIN}/${USERNAME}/${REPO}:latest \
  --load .

# docker-compose s-tip
## docker-compose 运行测试
docker-compose stop
docker-compose rm -fv
docker-compose up -d --force-recreate
## 容器日志 ctrl+c 退出
docker-compose logs -f
## 容器状态监控 ctrl+c 退出
#docker-compose stats

# buildx build push
## 多架构上传仓库，比如 linux/arm64/v8,linux/amd64，去除oci索引，防止 unknown/unknown
## 正常构建镜像会很大，但是时间很短，上传会浪费大量带宽
# buildx build push
## 多架构上传仓库，比如 linux/arm64/v8,linux/amd64
## 正常构建镜像会很大，但是时间很短，上传会浪费大量带宽
docker buildx build \
  --platform linux/arm64/v8,linux/amd64 \
  --cache-from type=local,src=${BUILDX_CACHE} \
  --cache-to type=local,dest=${BUILDX_CACHE}-new,mode=max \
  --output type=image,name=${DOCKER_DOMAIN}/${USERNAME}/${REPO}:latest,\
annotation-index.org.opencontainers.image.description='docker multi-arch s-tip support amd64 and arm64/v8',\
annotation-index.org.opencontainers.image.title='Multi-arch s-tip',\
annotation-index.org.opencontainers.image.version='1.0.0',\
annotation-index.org.opencontainers.image.authors='yHUJibXnPx <bXnPxyHUJi@outlook.com>',\
annotation-index.org.opencontainers.image.source='https://github.com/yHUJibXnPx/docker-arch-s-tip',\
annotation-index.org.opencontainers.image.licenses='MIT' \
  --annotation org.opencontainers.image.description='docker multi-arch s-tip support amd64 and arm64/v8' \
  --annotation org.opencontainers.image.title='Multi-arch s-tip' \
  --annotation org.opencontainers.image.version='1.0.0' \
  --annotation org.opencontainers.image.authors='yHUJibXnPx <bXnPxyHUJi@outlook.com>' \
  --annotation org.opencontainers.image.source='https://github.com/yHUJibXnPx/docker-arch-s-tip' \
  --annotation org.opencontainers.image.licenses='MIT' \
  --push .

## 或者多架构上传仓库，比如 linux/arm64/v8,linux/amd64，压缩
## 但压缩会意味着浪费更多的时间，但是也许会节省带宽，然而我并不清楚压缩和正常构建之间的关系
docker buildx build \
  --platform linux/arm64/v8,linux/amd64 \
  --cache-from type=local,src=${BUILDX_CACHE} \
  --cache-to type=local,dest=${BUILDX_CACHE}-new,mode=max \
  --output type=image,name=${DOCKER_DOMAIN}/${USERNAME}/${REPO}:latest,compression=zstd,compression-level=22,force-compression=true,\
annotation-index.org.opencontainers.image.description='docker multi-arch s-tip support amd64 and arm64/v8',\
annotation-index.org.opencontainers.image.title='Multi-arch s-tip',\
annotation-index.org.opencontainers.image.version='1.0.0',\
annotation-index.org.opencontainers.image.authors='yHUJibXnPx <bXnPxyHUJi@outlook.com>',\
annotation-index.org.opencontainers.image.source='https://github.com/yHUJibXnPx/docker-arch-s-tip',\
annotation-index.org.opencontainers.image.licenses='MIT' \
  --annotation org.opencontainers.image.description='docker multi-arch s-tip support amd64 and arm64/v8' \
  --annotation org.opencontainers.image.title='Multi-arch s-tip' \
  --annotation org.opencontainers.image.version='1.0.0' \
  --annotation org.opencontainers.image.authors='yHUJibXnPx <bXnPxyHUJi@outlook.com>' \
  --annotation org.opencontainers.image.source='https://github.com/yHUJibXnPx/docker-arch-s-tip' \
  --annotation org.opencontainers.image.licenses='MIT' \
  --push .

## 或者多架构上传仓库，比如 linux/arm64/v8,linux/amd64，压缩，不生成镜像来源，防止 unknown/unknown
## 使用 export BUILDX_NO_DEFAULT_ATTESTATIONS=1 或 --provenance=false 禁用来源信息，意味着你失去了有关构建过程的详细记录和签名。这对追踪镜像的安全性和来源可能会有一些影响。
#export BUILDX_NO_DEFAULT_ATTESTATIONS=1
docker buildx build \
  --platform linux/arm64/v8,linux/amd64 \
  --cache-from type=local,src=${BUILDX_CACHE} \
  --cache-to type=local,dest=${BUILDX_CACHE}-new,mode=max \
  --output type=image,name=${DOCKER_DOMAIN}/${USERNAME}/${REPO}:latest,compression=zstd,compression-level=22,force-compression=true,\
annotation-index.org.opencontainers.image.description='docker multi-arch s-tip support amd64 and arm64/v8',\
annotation-index.org.opencontainers.image.title='Multi-arch s-tip',\
annotation-index.org.opencontainers.image.version='1.0.0',\
annotation-index.org.opencontainers.image.authors='yHUJibXnPx <bXnPxyHUJi@outlook.com>',\
annotation-index.org.opencontainers.image.source='https://github.com/yHUJibXnPx/docker-arch-s-tip',\
annotation-index.org.opencontainers.image.licenses='MIT' \
  --annotation org.opencontainers.image.description='docker multi-arch s-tip support amd64 and arm64/v8' \
  --annotation org.opencontainers.image.title='Multi-arch s-tip' \
  --annotation org.opencontainers.image.version='1.0.0' \
  --annotation org.opencontainers.image.authors='yHUJibXnPx <bXnPxyHUJi@outlook.com>' \
  --annotation org.opencontainers.image.source='https://github.com/yHUJibXnPx/docker-arch-s-tip' \
  --annotation org.opencontainers.image.licenses='MIT' \
  --provenance=false \
  --push .
#unset BUILDX_NO_DEFAULT_ATTESTATIONS
```

如果你构建镜像成功，但是多次传输失败，那不怕，别哭还有办法，多架构 OCI 归档导出并用 skopeo 多架构镜像上传，可以使用以下方法
```bash
# Skopeo 在传输大型 Blob 时比 Docker 原生 Push 更稳定，且支持从归档文件直接同步。
# 安装 Skopeo 请按照各自的系统进行安装
# Linux (Ubuntu/Debian): 
sudo apt-get install -y skopeo
# macOS: 
brew install skopeo
# Alpine: 
apk add skopeo

# 导出已经编译好的镜像缓存到本地 OCI 标准归档文件
docker buildx build \
  --platform linux/arm64/v8,linux/amd64 \
  --cache-from type=local,src=${BUILDX_CACHE} \
  --cache-to type=local,dest=${BUILDX_CACHE}-new,mode=max \
  --tag ${DOCKER_DOMAIN}/${USERNAME}/${REPO}:latest \
  --output type=oci,dest=./${REPO}.tar,name=${DOCKER_DOMAIN}/${USERNAME}/${REPO}:latest,compression=zstd,compression-level=22,force-compression=true,\
annotation-index.org.opencontainers.image.description='docker multi-arch s-tip support amd64 and arm64/v8',\
annotation-index.org.opencontainers.image.title='Multi-arch s-tip',\
annotation-index.org.opencontainers.image.version='1.0.0',\
annotation-index.org.opencontainers.image.authors='yHUJibXnPx <bXnPxyHUJi@outlook.com>',\
annotation-index.org.opencontainers.image.source='https://github.com/yHUJibXnPx/docker-arch-s-tip',\
annotation-index.org.opencontainers.image.licenses='MIT' \
  --annotation org.opencontainers.image.description='docker multi-arch s-tip support amd64 and arm64/v8' \
  --annotation org.opencontainers.image.title='Multi-arch s-tip' \
  --annotation org.opencontainers.image.version='1.0.0' \
  --annotation org.opencontainers.image.authors='yHUJibXnPx <bXnPxyHUJi@outlook.com>' \
  --annotation org.opencontainers.image.source='https://github.com/yHUJibXnPx/docker-arch-s-tip' \
  --annotation org.opencontainers.image.licenses='MIT' .

# 然后通过 skopeo 将多架构镜像压缩包上传即可
# --all: 确保同时复制归档中的所有架构（amd64 和 arm64）。
skopeo copy \
  --all \
  --authfile ${HOME}/.docker/config.json \
  oci-archive:./${REPO}.tar \
  docker://${DOCKER_DOMAIN}/${USERNAME}/${REPO}:latest && \
rm -fv ./${REPO}.tar
```

如果你以上方法都尝试了，经常失败，那说明网络真的很不好，别怕别哭，还有办法，可以尝试一个一个架构的构建并传输到云存储空间，可以使用以下方法
```bash
# 无压缩：push 的层更小、更快，失败重传代价低。
# 分架构 push：如果某个架构 push 失败，只需重试那一个，不会浪费几个小时重传整个 multi-arch。
# 注意这个方法会让你的latest丧失镜像注释标签
# 构建并推送 amd64
docker buildx build \
  --platform linux/amd64 \
  --cache-from type=local,src=${BUILDX_CACHE} \
  --cache-to type=local,dest=${BUILDX_CACHE}-new,mode=max \
  --output type=image,name=${DOCKER_DOMAIN}/${USERNAME}/${REPO}:amd64 \
  --tag ${DOCKER_DOMAIN}/${USERNAME}/${REPO}:amd64 \
  --annotation org.opencontainers.image.description='docker multi-arch s-tip support amd64 and arm64/v8' \
  --annotation org.opencontainers.image.title='Multi-arch s-tip' \
  --annotation org.opencontainers.image.version='1.0.0' \
  --annotation org.opencontainers.image.authors='yHUJibXnPx <bXnPxyHUJi@outlook.com>' \
  --annotation org.opencontainers.image.source='https://github.com/yHUJibXnPx/docker-arch-s-tip' \
  --annotation org.opencontainers.image.licenses='MIT' \
  --provenance=false \
  --push .

# 构建并推送 arm64
docker buildx build \
  --platform linux/arm64/v8 \
  --cache-from type=local,src=${BUILDX_CACHE} \
  --cache-to type=local,dest=${BUILDX_CACHE}-new,mode=max \
  --output type=image,name=${DOCKER_DOMAIN}/${USERNAME}/${REPO}:arm64 \
  --tag ${DOCKER_DOMAIN}/${USERNAME}/${REPO}:arm64 \
  --annotation org.opencontainers.image.description='docker multi-arch s-tip support amd64 and arm64/v8' \
  --annotation org.opencontainers.image.title='Multi-arch s-tip' \
  --annotation org.opencontainers.image.version='1.0.0' \
  --annotation org.opencontainers.image.authors='yHUJibXnPx <bXnPxyHUJi@outlook.com>' \
  --annotation org.opencontainers.image.source='https://github.com/yHUJibXnPx/docker-arch-s-tip' \
  --annotation org.opencontainers.image.licenses='MIT' \
  --provenance=false \
  --push .

# 合并推送 manifest
# manifest 合并：最终依然得到一个 :latest 多架构镜像，使用体验不变。
docker manifest create ${DOCKER_DOMAIN}/${USERNAME}/${REPO}:latest \
  --amend ${DOCKER_DOMAIN}/${USERNAME}/${REPO}:amd64 \
  --amend ${DOCKER_DOMAIN}/${USERNAME}/${REPO}:arm64
docker manifest push ${DOCKER_DOMAIN}/${USERNAME}/${REPO}:latest
```

什么？以上方案觉得除了 amd64 架构的镜像，其他架构的构建很慢？  
别慌，别怕，别哭，如果你手里有其他架构的设备那就还有办法提速！  
跨架构混合动力构建（Linux x86 + Mac M4 ARM）  
```bash
# 此教程也适用于其他 arm64或其他架构 设备
# 将公钥发送到目标 macmini m4 arm64 机器 hostname 或 ip 上都行，目的是为了免密码
# 比如 hostname eefu5ab649831964tekiMac-mini.local
ssh-copy-id af5ab649831964@eefu5ab649831964tekiMac-mini.local

# 我的 macmini m4 arm64 机器上的 docker desktop 服务的默认路径位置在 unix:///Users/af5ab649831964/.docker/run/docker.sock 也就是 /Users/af5ab649831964/.docker/run/docker.sock
# 如果是用 colima 或其他工具，docker 服务位置路径可能会变。
# 其他 linux arm64 机器上的 docker 服务位置应该在 unix:///var/run/docker.sock 也就是 /var/run/docker.sock
# 通过 ssh 协议隧道作为媒介转发 macmini m4 arm64 机器的 docker 服务到 2374 端口
# -f 会保持后台运行，如果不需要 -f 那就需要额外开一个新窗口继续执行以下操作。
ssh -fNL localhost:2374:/Users/af5ab649831964/.docker/run/docker.sock af5ab649831964@eefu5ab649831964tekiMac-mini.local -v

# 配置 Docker Context 与混合 Builder
# 为本地 Docker 创建一个叫 other_${REPO} 的引擎，其实它走的是 2374 隧道
docker context create other_${REPO} --docker "host=tcp://127.0.0.1:2374"
# 分别为不同的架构创建不同的 builder 构建者，跨架构联合构建镜像，提升效率
# linux/amd64 使用本地默认引擎
docker buildx create --name ${REPO} --platform linux/amd64 default
# linux/arm64 追加子项并使用 macmini m4 arm64 机器的引擎
docker buildx create --append --name ${REPO} --platform linux/arm64/v8 other_${REPO}
# 使用 builder 构建者
docker buildx use ${REPO}
# 运行并查看 builder 构建者状态
docker buildx inspect --bootstrap

# 配合代理加速构建容器的环境，跨平台构建镜像提升效率
docker buildx build \
  --build-arg HTTP_PROXY="http://192.168.255.253:7890" \
  --build-arg HTTPS_PROXY="http://192.168.255.253:7890" \
  --build-arg NO_PROXY="localhost,127.0.0.1,google.cn" \
  --platform linux/arm64/v8,linux/amd64 \
  --cache-from type=local,src=${BUILDX_CACHE} \
  --cache-to type=local,dest=${BUILDX_CACHE}-new,mode=max \
  --output type=image,name=${DOCKER_DOMAIN}/${USERNAME}/${REPO}:latest,compression=zstd,compression-level=22,force-compression=true,\
annotation-index.org.opencontainers.image.description='docker multi-arch s-tip support amd64 and arm64/v8',\
annotation-index.org.opencontainers.image.title='Multi-arch s-tip',\
annotation-index.org.opencontainers.image.version='1.0.0',\
annotation-index.org.opencontainers.image.authors='yHUJibXnPx <bXnPxyHUJi@outlook.com>',\
annotation-index.org.opencontainers.image.source='https://github.com/yHUJibXnPx/docker-arch-s-tip',\
annotation-index.org.opencontainers.image.licenses='MIT' \
  --annotation org.opencontainers.image.description='docker multi-arch s-tip support amd64 and arm64/v8' \
  --annotation org.opencontainers.image.title='Multi-arch s-tip' \
  --annotation org.opencontainers.image.version='1.0.0' \
  --annotation org.opencontainers.image.authors='yHUJibXnPx <bXnPxyHUJi@outlook.com>' \
  --annotation org.opencontainers.image.source='https://github.com/yHUJibXnPx/docker-arch-s-tip' \
  --annotation org.opencontainers.image.licenses='MIT' \
  --push .

# 构建完成后，如果不再使用，可以停止甚至删除来释放远端设备的 BuildKit 资源。
docker-buildx stop ${REPO}
docker-buildx rm -f ${REPO}
docker context rm -f other_${REPO}

# 关闭 SSH 隧道（如果是后台运行）
# 找到并结束那个转发 2374 端口的进程
pkill -f "2374:/Users/af5ab649831964/.docker/run/docker.sock"
```
拓扑示意图  

```mermaid
graph LR
    A[Linux PC - amd64] -- 1. 指挥与构建 amd64 --> C{Docker Buildx}

    B[Mac Mini M4 - arm64] -- 2. 承担 arm64 编译任务 --> C
 
    D[本地代码] --> C

    C -- 3. 合并多架构镜像 --> E[Github Registry]
    
    style B stroke:#333,stroke-width:2px
    subgraph SSH_Tunnel [加密隧道]
    B
    end
```

检查镜像，清理环境  
```bash
# 现在就可以检查镜像状态了
docker history ${DOCKER_DOMAIN}/${USERNAME}/${REPO}:latest
docker images ${DOCKER_DOMAIN}/${USERNAME}/${REPO}:latest

# 查看 Docker 镜像元数据信息
docker inspect ${DOCKER_DOMAIN}/${USERNAME}/${REPO}:latest
# 查看 Docker 镜像清单（Manifest）。JSON 格式 Docker 镜像清单包含了有关镜像的元数据，包括层（layers）、架构（architecture）、操作系统（OS）、标签（tags）等信息
docker manifest inspect ${DOCKER_DOMAIN}/${USERNAME}/${REPO}:latest
# 启用调试模式后，命令会输出更多的详细信息，包括 Docker 连接的网络请求、API 调用等
docker --debug manifest inspect ${DOCKER_DOMAIN}/${USERNAME}/${REPO}:latest

# delete buildx cache dir
## 删除 docker buildx 所使用的大存储缓存目录，你也可以留着
rm -frv ${BUILDX_CACHE}

# create new buildx cache dir
## 使用  docker buildx 新的缓存替换旧缓存
mv -fv ${BUILDX_CACHE}-new ${BUILDX_CACHE}
mkdir -pv  ${BUILDX_CACHE}-new

## 清理 buildx 构建缓存。以及清理构建新镜像所产生的 <none> 标签老镜像
docker builder prune -af
docker rmi $(docker images -qaf dangling=true)

# docker build clean
## 清理所有停止的容器
#docker container prune -f
## 清理未使用的镜像
#docker image prune -af
## 清理不使用的网络
#docker network prune -f
## 清理不使用的卷
#docker volume prune -af
## 清理所有不需要的数据: 如果想要彻底清理所有未使用的镜像、容器、网络和卷，可以使用
#docker system prune --all --volumes -af

# buildx remove other node
## 清理 buildx 不使用的节点，你也可以留着
docker-buildx use default
docker-buildx ls
#docker-buildx rm -f $(docker-buildx ls --format '{{.Builder.Name}}')
#docker-buildx rm -f --all-inactive
docker-buildx stop ${REPO}
docker-buildx rm -f ${REPO}
docker-buildx ls
```

## 许可证
本项目采用 [MIT License](LICENSE) 许可。

## 联系与反馈
遇到问题或有改进建议，请在 [issues](https://github.com/yHUJibXnPx/docker-arch-s-tip/issues) 中提出，或直接联系项目维护者。

## 参考
[ubuntu install docker](https://docs.docker.com/engine/install/ubuntu/)  
[Install Docker Engine](https://docs.docker.com/engine/install/)  
[Install Docker Compose](https://docs.docker.com/compose/install/)  
[docker-install](https://github.com/docker/docker-install)  
[docker scout-cli](https://github.com/docker/scout-cli/)  
[docker buildx](https://docs.docker.com/build/builders/)  
[docker buildx output](https://docs.docker.com/build/exporters/#export-filesystem)  
[buildx_no_default_attestations](https://docs.docker.com/build/building/variables/#buildx_no_default_attestations)  
[docker compose](https://docs.docker.com/compose/install/linux/)  
[github docker buildx](https://github.com/docker/buildx)  
[github docker compose](https://github.com/docker/compose)  
[docker proxy pull](https://docs.docker.com/engine/daemon/proxy/)  
[adding-a-description-to-multi-arch-images](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry#adding-a-description-to-multi-arch-images)  
[oci unknown/unknown](https://github.com/docker/buildx/issues/1964#issuecomment-1644634461)  
[buildx_no_default_attestations](https://docs.docker.com/build/building/variables/#buildx_no_default_attestations)  
[frankiejun/serv00-play](https://github.com/frankiejun/serv00-play)  
[使用 email 发送邮件](https://blog.csdn.net/liuyuinsdu/article/details/113878840)  
[docker builders drivers remote](https://docs.docker.com/build/builders/drivers/remote/)  

# 声明
本项目仅作学习交流使用，用于解决生理需求，学习各种姿势，不做任何违法行为。仅供交流学习使用，出现违法问题我负责不了，我也没能力负责，我没工作，也没收入，年纪也大了，你就算灭了我也没用，我也没能力负责。  

# 01. Tomcat 설치 (Amazon Linux 2023)

## 왜 dnf로 설치가 안 되는가

AL2023의 기본 리포지토리에는 Tomcat이 포함되어 있지 않습니다.
따라서 Apache Tomcat 공식 사이트에서 직접 tar.gz 아카이브를 받아 설치해야 합니다.

---

## 1. 사전 준비 — Java 설치

Tomcat은 JVM 위에서 실행되므로 Java가 먼저 설치되어 있어야 합니다.

```bash
# 사용 가능한 JDK 확인
dnf search java-*-amazon-corretto

# Amazon Corretto 17 설치 (Tomcat 10.x 권장)
sudo dnf install -y java-17-amazon-corretto-headless

# 설치 확인
java -version
# openjdk version "17.x.x" ...

# JAVA_HOME 확인
readlink -f $(which java)
# /usr/lib/jvm/java-17-amazon-corretto.x86_64/bin/java

# 환경변수 설정
echo 'export JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto.x86_64' | sudo tee /etc/profile.d/java.sh
source /etc/profile.d/java.sh
echo $JAVA_HOME
```

### Java 버전별 Tomcat 호환성

| Tomcat 버전 | 최소 Java | 권장 Java |
|------------|----------|----------|
| 10.1       | Java 11  | Java 17  |
| 10.0       | Java 8   | Java 11  |
| 9.0        | Java 8   | Java 11  |

---

## 2. Tomcat 다운로드 및 설치

```bash
# ============================================================
# 버전 변수 설정
# ============================================================
TOMCAT_VERSION="10.1.24"
TOMCAT_MAJOR="10"

# ============================================================
# 다운로드
# ============================================================
cd /tmp
wget https://dlcdn.apache.org/tomcat/tomcat-${TOMCAT_MAJOR}/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz

# 무결성 검증 (선택 사항이지만 권장)
wget https://downloads.apache.org/tomcat/tomcat-${TOMCAT_MAJOR}/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz.sha512
sha512sum -c apache-tomcat-${TOMCAT_VERSION}.tar.gz.sha512

# ============================================================
# 압축 해제 및 설치 경로 이동
# ============================================================
sudo mkdir -p /opt/tomcat
sudo tar xzf apache-tomcat-${TOMCAT_VERSION}.tar.gz -C /opt/tomcat --strip-components=1

# 설치 확인
ls /opt/tomcat
# bin  conf  lib  logs  temp  webapps  work
```

---

## 3. 전용 사용자 생성

```bash
# tomcat 시스템 계정 생성 (로그인 불가)
sudo useradd -r -m -U -d /opt/tomcat -s /bin/false tomcat

# 설치 디렉토리 소유권 변경
sudo chown -R tomcat:tomcat /opt/tomcat

# 실행 권한 부여
sudo chmod -R u+x /opt/tomcat/bin
sudo chmod -R g+rx /opt/tomcat/bin

# 권한 확인
ls -la /opt/tomcat/bin/*.sh
```

---

## 4. 환경 변수 설정 (setenv.sh)

```bash
sudo tee /opt/tomcat/bin/setenv.sh << 'EOF'
#!/bin/bash

# Java 홈 디렉토리
export JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto.x86_64

# Tomcat 홈 디렉토리
export CATALINA_HOME=/opt/tomcat
export CATALINA_BASE=/opt/tomcat

# JVM 메모리 옵션
# -Xms: 초기 힙 크기
# -Xmx: 최대 힙 크기
# -XX:MetaspaceSize: Metaspace 초기 크기
# -XX:MaxMetaspaceSize: Metaspace 최대 크기
export CATALINA_OPTS="-Xms512m -Xmx1024m -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=256m"

# GC 로깅 (Java 17)
export CATALINA_OPTS="$CATALINA_OPTS -Xlog:gc*:file=/opt/tomcat/logs/gc.log:time,uptime:filecount=5,filesize=10m"

# JMX 원격 모니터링 (선택)
# export CATALINA_OPTS="$CATALINA_OPTS -Dcom.sun.management.jmxremote"
# export CATALINA_OPTS="$CATALINA_OPTS -Dcom.sun.management.jmxremote.port=9999"
# export CATALINA_OPTS="$CATALINA_OPTS -Dcom.sun.management.jmxremote.ssl=false"
# export CATALINA_OPTS="$CATALINA_OPTS -Dcom.sun.management.jmxremote.authenticate=false"

# PID 파일 경로
export CATALINA_PID=/opt/tomcat/temp/tomcat.pid
EOF

sudo chmod +x /opt/tomcat/bin/setenv.sh
sudo chown tomcat:tomcat /opt/tomcat/bin/setenv.sh
```

---

## 5. systemd 서비스 등록

```bash
sudo tee /etc/systemd/system/tomcat.service << 'EOF'
[Unit]
Description=Apache Tomcat Web Application Container
Documentation=https://tomcat.apache.org
After=network-online.target
Wants=network-online.target

[Service]
Type=forking

User=tomcat
Group=tomcat

# 환경변수
Environment="JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto.x86_64"
Environment="CATALINA_HOME=/opt/tomcat"
Environment="CATALINA_BASE=/opt/tomcat"
Environment="CATALINA_PID=/opt/tomcat/temp/tomcat.pid"
Environment="CATALINA_OPTS=-Xms512m -Xmx1024m -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=256m"

# 시작 / 중지 명령
ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

# PID 파일 위치
PIDFile=/opt/tomcat/temp/tomcat.pid

# 종료 후 재시작
Restart=on-failure
RestartSec=10

# 파일 디스크립터 제한 (대량 동시 연결 시)
LimitNOFILE=65536

# 타임아웃
TimeoutStartSec=60
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

# systemd 데몬 리로드
sudo systemctl daemon-reload

# 서비스 시작 + 부팅 자동 시작
sudo systemctl enable --now tomcat

# 상태 확인
sudo systemctl status tomcat
```

---

## 6. 방화벽 설정

```bash
# Tomcat 기본 포트 (HTTP)
sudo firewall-cmd --permanent --add-port=8080/tcp

# HTTPS (SSL 커넥터 사용 시)
sudo firewall-cmd --permanent --add-port=8443/tcp

# AJP (Apache/Nginx 연동 시)
# 주의: AJP는 외부에 절대 노출하지 않도록 주의
# sudo firewall-cmd --permanent --add-port=8009/tcp

# Manager App (관리 목적, 제한된 IP만 허용)
# 실제 운영 환경에서는 Nginx 등으로 IP 제한 필요
sudo firewall-cmd --reload
sudo firewall-cmd --list-all
```

AWS EC2 사용 시 Security Group에서 8080 인바운드 허용 필요.

---

## 7. 설치 확인 및 테스트

```bash
# 서비스 상태
sudo systemctl status tomcat

# 로그 확인
sudo tail -f /opt/tomcat/logs/catalina.out

# 포트 리스닝 확인
sudo ss -tlnp | grep java

# HTTP 응답 테스트
curl -I http://localhost:8080
# HTTP/1.1 200 OK
# Server: Apache-Coyote/1.1

# Tomcat 버전 확인
/opt/tomcat/bin/version.sh
# Server version: Apache Tomcat/10.1.24
# JVM Version: 17.x.x
```

---

## 8. Manager App 설정

Tomcat Manager는 웹 UI로 WAR 파일 배포/언배포를 할 수 있는 관리 도구입니다.

```bash
# 관리자 계정 추가
sudo vi /opt/tomcat/conf/tomcat-users.xml
```

```xml
<!-- tomcat-users.xml에 추가 -->
<tomcat-users>
  <role rolename="manager-gui"/>
  <role rolename="manager-script"/>
  <role rolename="admin-gui"/>
  <user username="admin"
        password="강력한패스워드"
        roles="manager-gui,admin-gui"/>
</tomcat-users>
```

```bash
# Manager 접근 IP 제한 해제 (기본: localhost만 허용)
# 외부 접근이 필요한 경우 (개발 환경)
sudo vi /opt/tomcat/webapps/manager/META-INF/context.xml
```

```xml
<!-- 기본값 (localhost만 허용) -->
<Context antiResourceLocking="false" privileged="true" >
  <Valve className="org.apache.catalina.valves.RemoteAddrValve"
         allow="127\.\d+\.\d+\.\d+|::1|0:0:0:0:0:0:0:1" />
</Context>

<!-- 특정 IP 대역 허용 예시 -->
<Context antiResourceLocking="false" privileged="true" >
  <Valve className="org.apache.catalina.valves.RemoteAddrValve"
         allow="127\..*|192\.168\.1\..*" />
</Context>
```

---

## 9. WAR 파일 배포 방법

```bash
# ============================================================
# 방법 1: webapps 디렉토리에 복사 (자동 배포)
# ============================================================
# Tomcat은 webapps/ 안의 WAR 파일을 자동으로 압축 해제하여 배포
sudo cp myapp.war /opt/tomcat/webapps/
sudo chown tomcat:tomcat /opt/tomcat/webapps/myapp.war
# 잠시 후 /opt/tomcat/webapps/myapp/ 디렉토리 자동 생성

# ============================================================
# 방법 2: Manager App REST API
# ============================================================
curl -u admin:패스워드 \
  "http://localhost:8080/manager/text/deploy?path=/myapp&war=file:/tmp/myapp.war"

# ============================================================
# 방법 3: Manager App 웹 UI
# ============================================================
# 브라우저에서: http://localhost:8080/manager/html

# ============================================================
# 언배포 (Undeploy)
# ============================================================
curl -u admin:패스워드 \
  "http://localhost:8080/manager/text/undeploy?path=/myapp"

# ============================================================
# 재로드 (코드 변경 반영, WAR 재배포 없이)
# ============================================================
curl -u admin:패스워드 \
  "http://localhost:8080/manager/text/reload?path=/myapp"
```

---

## 10. 업그레이드 방법

```bash
# 새 버전 다운로드
TOMCAT_NEW="10.1.25"
cd /tmp
wget https://dlcdn.apache.org/tomcat/tomcat-10/v${TOMCAT_NEW}/bin/apache-tomcat-${TOMCAT_NEW}.tar.gz

# 현재 서비스 중지
sudo systemctl stop tomcat

# 기존 설정 백업
sudo cp -r /opt/tomcat/conf /opt/tomcat_conf_backup

# 새 버전 압축 해제
sudo tar xzf apache-tomcat-${TOMCAT_NEW}.tar.gz -C /tmp/

# 새 바이너리만 교체 (bin, lib 교체, conf는 유지)
sudo rsync -av --exclude='conf' --exclude='webapps' --exclude='logs' --exclude='work' --exclude='temp' \
    /tmp/apache-tomcat-${TOMCAT_NEW}/ /opt/tomcat/

# 권한 복원
sudo chown -R tomcat:tomcat /opt/tomcat

# 서비스 재시작
sudo systemctl start tomcat

# 버전 확인
/opt/tomcat/bin/version.sh
```

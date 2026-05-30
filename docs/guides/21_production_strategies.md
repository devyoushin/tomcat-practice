# 21. 실무 운영 전략

## setenv.sh 환경별 관리

```bash
# /opt/tomcat/bin/setenv.sh (공통 기반)
# 이 파일은 catalina.sh가 자동으로 로드함

# ============================================================
# JVM 메모리
# ============================================================
export JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto
export CATALINA_OPTS="\
  -server \
  -Xms2g \
  -Xmx2g \
  -XX:MetaspaceSize=256m \
  -XX:MaxMetaspaceSize=512m \
"

# ============================================================
# GC
# ============================================================
export CATALINA_OPTS="$CATALINA_OPTS \
  -XX:+UseG1GC \
  -XX:MaxGCPauseMillis=200 \
  -XX:G1HeapRegionSize=16m \
"

# ============================================================
# GC 로깅
# ============================================================
export CATALINA_OPTS="$CATALINA_OPTS \
  -Xlog:gc*:file=/opt/tomcat/logs/gc.log:time,uptime,tags:filecount=5,filesize=50m \
"

# ============================================================
# OOM 시 힙 덤프 자동 생성 (실무 필수)
# ============================================================
export CATALINA_OPTS="$CATALINA_OPTS \
  -XX:+HeapDumpOnOutOfMemoryError \
  -XX:HeapDumpPath=/opt/tomcat/logs/heapdump-$(hostname)-$(date +%Y%m%d%H%M%S).hprof \
"

# ============================================================
# JVM 크래시 로그
# ============================================================
export CATALINA_OPTS="$CATALINA_OPTS \
  -XX:ErrorFile=/opt/tomcat/logs/hs_err_$(date +%Y%m%d%H%M%S).log \
"

# ============================================================
# 기타
# ============================================================
export CATALINA_OPTS="$CATALINA_OPTS \
  -Djava.awt.headless=true \
  -Dfile.encoding=UTF-8 \
  -Duser.timezone=Asia/Seoul \
"

# catalina.out 비활성화 (JULI 파일 핸들러만 사용)
# export CATALINA_OUT=/dev/null
```

### 환경별 분기 처리

```bash
# /opt/tomcat/bin/setenv.sh 에서 환경 변수로 분기
ENV=${APP_ENV:-prod}  # 기본값 prod

case "$ENV" in
  dev)
    export CATALINA_OPTS="$CATALINA_OPTS -Xms512m -Xmx512m"
    export CATALINA_OPTS="$CATALINA_OPTS -Dspring.profiles.active=dev"
    ;;
  staging)
    export CATALINA_OPTS="$CATALINA_OPTS -Xms1g -Xmx1g"
    export CATALINA_OPTS="$CATALINA_OPTS -Dspring.profiles.active=staging"
    ;;
  prod)
    export CATALINA_OPTS="$CATALINA_OPTS -Xms2g -Xmx2g"
    export CATALINA_OPTS="$CATALINA_OPTS -Dspring.profiles.active=prod"
    ;;
esac
```

---

## 배포 전략

### 1. Hot Deploy (Manager API) — 소규모 단일 서버

```bash
#!/bin/bash
# hot_deploy.sh — Tomcat Manager API를 통한 무중단 배포
# 주의: 세션 유실 발생 (stateful 앱에서는 권장 안 함)

MANAGER_URL="http://localhost:8080/manager/text"
CRED="deployer:$(cat /etc/tomcat-deployer-pass)"  # 파일에서 읽기 (스크립트에 비번 하드코딩 금지)
APP_PATH="/myapp"
WAR="/tmp/myapp.war"

# 배포 (undeploy + deploy 대신 update=true 사용)
curl -sf -u "$CRED" \
  --upload-file "$WAR" \
  "${MANAGER_URL}/deploy?path=${APP_PATH}&update=true"

# 결과 확인
RESULT=$(curl -sf -u "$CRED" "${MANAGER_URL}/list" | grep "^${APP_PATH}:")
echo "배포 결과: $RESULT"
```

### 2. Blue-Green 배포 — 운영 권장

```
트래픽 흐름:
  [Nginx] → [Blue Tomcat :8080]  (현재 운영)
                                 [Green Tomcat :8081]  (신버전 준비)

배포 절차:
  1. Green에 신버전 배포 및 기동
  2. Green 헬스체크
  3. Nginx upstream을 Green으로 전환 (nginx -s reload)
  4. Blue는 드레이닝 후 대기 (다음 배포 시 반전)
```

```bash
#!/bin/bash
# blue_green_switch.sh

NGINX_CONF="/etc/nginx/conf.d/app.conf"
ACTIVE=$(grep -oP '(?<=# ACTIVE: )\w+' "$NGINX_CONF")
NEW_VERSION=$([ "$ACTIVE" == "blue" ] && echo "green" || echo "blue")

BLUE_PORT=8080
GREEN_PORT=8081
NEW_PORT=$([ "$NEW_VERSION" == "green" ] && echo "$GREEN_PORT" || echo "$BLUE_PORT")

# 1. 신버전 Tomcat 헬스체크
echo ">>> $NEW_VERSION 헬스체크 (port: $NEW_PORT)"
for i in $(seq 1 20); do
    HTTP=$(curl -sf -o /dev/null -w "%{http_code}" "http://localhost:${NEW_PORT}/myapp/actuator/health")
    [ "$HTTP" == "200" ] && break
    echo "  대기중... ($i/20)"
    sleep 3
done

if [ "$HTTP" != "200" ]; then
    echo "헬스체크 실패. 배포 중단."
    exit 1
fi

# 2. Nginx upstream 전환
sed -i "s/# ACTIVE: $ACTIVE/# ACTIVE: $NEW_VERSION/" "$NGINX_CONF"
sed -i "s/server localhost:${BLUE_PORT:-8080}/server localhost:${NEW_PORT}/" "$NGINX_CONF"

nginx -t && nginx -s reload
echo ">>> 전환 완료: $ACTIVE → $NEW_VERSION"
```

### 3. Rolling 배포 — 클러스터 환경

```bash
#!/bin/bash
# rolling_deploy.sh — 노드 순차 배포 (세션 스티키 환경)

NODES=("10.0.1.10" "10.0.1.11" "10.0.1.12")
WAR_PATH="/tmp/myapp.war"
TOMCAT_USER="tomcat"
DEPLOY_DIR="/opt/tomcat/webapps"
HEALTH_URL="http://{NODE}:8080/myapp/actuator/health"
NGINX_UPSTREAM="app_upstream"
HEALTH_TIMEOUT=120

for NODE in "${NODES[@]}"; do
    echo "===== 배포 시작: $NODE ====="

    # 1. Nginx에서 해당 노드 제거 (드레이닝)
    # nginx upstream_conf 모듈 또는 OpenResty 사용 시:
    # curl -X POST "http://nginx-api/upstream/$NGINX_UPSTREAM/servers/$NODE:8080" -d '{"down":true}'
    echo "  Nginx에서 $NODE 제외"
    sleep 30  # 기존 연결 드레이닝 대기

    # 2. 배포
    echo "  WAR 배포"
    ssh "$TOMCAT_USER@$NODE" "
        sudo cp $WAR_PATH $DEPLOY_DIR/myapp.war
        sudo chown tomcat:tomcat $DEPLOY_DIR/myapp.war
        sudo systemctl restart tomcat
    "

    # 3. 헬스체크
    echo "  헬스체크"
    URL="${HEALTH_URL/\{NODE\}/$NODE}"
    for i in $(seq 1 $((HEALTH_TIMEOUT / 5))); do
        HTTP=$(curl -sf -o /dev/null -w "%{http_code}" "$URL" 2>/dev/null)
        [ "$HTTP" == "200" ] && break
        sleep 5
    done

    if [ "$HTTP" != "200" ]; then
        echo "  헬스체크 실패! 배포 중단. 수동 확인 필요."
        exit 1
    fi

    # 4. Nginx에 노드 재투입
    echo "  Nginx에 $NODE 재투입"
    # curl -X POST "http://nginx-api/upstream/$NGINX_UPSTREAM/servers/$NODE:8080" -d '{"down":false}'
    echo "===== $NODE 완료 ====="
    sleep 10  # 트래픽 서서히 증가 대기
done

echo "Rolling 배포 완료"
```

---

## Graceful Shutdown

Tomcat을 갑자기 kill하면 처리 중인 요청이 끊깁니다.

### systemd를 통한 Graceful Shutdown

```ini
# /etc/systemd/system/tomcat.service
[Unit]
Description=Apache Tomcat
After=network.target

[Service]
Type=forking
User=tomcat
Group=tomcat
Environment=JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto
Environment=CATALINA_HOME=/opt/tomcat
ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

# Graceful shutdown: 최대 60초 대기
TimeoutStopSec=60
KillMode=process
KillSignal=SIGTERM
SendSIGKILL=yes        # SIGTERM 후 TimeoutStopSec 경과 시 SIGKILL

[Install]
WantedBy=multi-user.target
```

### server.xml shutdown 타임아웃 설정

```xml
<!-- server.xml -->
<!-- unloadDelay: 언디플로이 시 서블릿 destroy() 대기 시간 (ms) -->
<Host name="localhost"
      appBase="webapps"
      unpackWARs="true"
      autoDeploy="false"
      undeployOldVersions="false">
</Host>
```

```bash
# Graceful shutdown 명령
sudo systemctl stop tomcat
# 또는
/opt/tomcat/bin/shutdown.sh 60 -force
# → 60초 대기 후에도 안 끝나면 강제 종료
```

---

## 장애 대응 Runbook

### OOM (OutOfMemoryError) 발생 시

```bash
# 1. 힙 덤프 위치 확인 (setenv.sh에 HeapDumpOnOutOfMemoryError 설정 필요)
ls -lh /opt/tomcat/logs/*.hprof

# 2. 힙 덤프 분석 도구
# Eclipse Memory Analyzer (MAT): 가장 많이 씀
# VisualVM, JDK Mission Control

# 3. 힙 덤프 수동 생성 (살아있는 Tomcat에서)
jmap -dump:live,format=b,file=/tmp/heap_$(date +%H%M%S).hprof $(pgrep -f tomcat)

# 4. 클래스별 인스턴스 수 빠른 확인
jmap -histo:live $(pgrep -f tomcat) | head -30

# 5. 즉시 조치: Tomcat 재시작
sudo systemctl restart tomcat
```

### Thread Starvation (스레드 고갈) 발생 시

```bash
# 증상: 요청 큐가 쌓이고 응답 없음, access_log에 요청만 쌓임

# 1. 스레드 덤프 연속 3회 수집 (5초 간격)
for i in 1 2 3; do
    jstack $(pgrep -f tomcat) > /tmp/thread_dump_$(date +%H%M%S).txt
    sleep 5
done

# 2. 블로킹 스레드 확인
grep -A 3 "BLOCKED" /tmp/thread_dump_*.txt

# 3. WAITING 상태 카운트
grep "java.lang.Thread.State: WAITING" /tmp/thread_dump_1.txt | wc -l

# 4. 현재 스레드 수 확인 (Tomcat Manager)
curl -u deployer:pass http://localhost:8080/manager/text/status

# 5. 빠른 진단: maxThreads 대비 현재 스레드 수
# Manager UI: http://localhost:8080/manager/status
```

### 응답 지연 발생 시

```bash
# 1. 느린 요청 확인 (접근 로그에서 응답시간 필드 기준)
# 패턴에 %D (milliseconds) 포함 필요
awk '$NF > 3000 {print}' /opt/tomcat/logs/localhost_access_log.$(date +%Y-%m-%d).txt | tail -50

# 2. DB 커넥션 풀 고갈 확인 (JNDI DataSource)
# 애플리케이션 로그에서 "Cannot get a connection" 검색
grep -i "cannot get a connection\|connection pool\|timeout" /opt/tomcat/logs/catalina.out | tail -20

# 3. GC 지연 확인
grep -E "Pause|pause" /opt/tomcat/logs/gc.log | tail -20

# 4. CPU/메모리 현황
top -p $(pgrep -f tomcat) -b -n 1
```

---

## Warm-up (Pre-loading) 전략

Tomcat 재시작 후 JIT 컴파일이 완료되기 전까지 응답이 느립니다.

### 방법 1: ServletContextListener로 사전 로딩

```java
@WebListener
public class WarmUpListener implements ServletContextListener {
    @Override
    public void contextInitialized(ServletContextEvent sce) {
        // 주요 클래스 사전 로딩
        try {
            // DB 커넥션 풀 미리 확보
            DataSource ds = (DataSource) new InitialContext().lookup("java:comp/env/jdbc/mydb");
            try (Connection conn = ds.getConnection()) {
                conn.prepareStatement("SELECT 1").execute();
            }

            // 주요 서비스 초기화 (Spring 환경)
            // applicationContext.getBean(CriticalService.class).initialize();

            log.info("Warm-up 완료");
        } catch (Exception e) {
            log.warn("Warm-up 중 일부 실패 (무시): {}", e.getMessage());
        }
    }
}
```

### 방법 2: 배포 스크립트에서 Warm-up 요청

```bash
# deploy.sh 마지막 단계
echo ">>> Warm-up 요청"
for endpoint in "/myapp/api/users" "/myapp/api/products" "/myapp/api/health"; do
    curl -sf "http://localhost:8080$endpoint" > /dev/null
    echo "  $endpoint 완료"
done

# JIT 컴파일 시간 확보
sleep 10
echo ">>> Warm-up 완료. 트래픽 투입"
```

### 방법 3: JVM Class Data Sharing (CDS)

```bash
# 클래스 로딩 메타데이터 공유 파일 생성 (JDK 17+)
java -Xshare:dump -XX:SharedArchiveFile=/opt/tomcat/cds.jsa

# setenv.sh에 적용
export CATALINA_OPTS="$CATALINA_OPTS \
  -XX:SharedArchiveFile=/opt/tomcat/cds.jsa \
  -XX:+UseSharedSpaces \
"
```

---

## 정기 점검 체크리스트

### 매일

```bash
#!/bin/bash
# daily_check.sh

echo "===== Tomcat 일일 점검 $(date) ====="

# 1. 프로세스 확인
pgrep -fa tomcat || echo "[WARN] Tomcat 프로세스 없음"

# 2. 포트 응답 확인
curl -sf -o /dev/null http://localhost:8080/myapp/actuator/health \
  && echo "[OK] 헬스체크 정상" \
  || echo "[ALERT] 헬스체크 실패"

# 3. 로그 에러 수 확인 (어제 기준)
YESTERDAY=$(date -d yesterday +%Y-%m-%d 2>/dev/null || date -v -1d +%Y-%m-%d)
ERROR_COUNT=$(grep -c "ERROR\|SEVERE\|Exception" /opt/tomcat/logs/catalina.out 2>/dev/null || echo 0)
echo "[INFO] catalina.out 에러 수: $ERROR_COUNT"

# 4. 디스크 사용량
DISK_USAGE=$(df -h /opt/tomcat/logs | awk 'NR==2{print $5}')
echo "[INFO] 로그 파티션 사용률: $DISK_USAGE"

# 5. 힙 사용률 (JMX 없이 빠른 확인)
jcmd $(pgrep -f tomcat) GC.heap_info 2>/dev/null | grep -E "used|committed" | head -5
```

### 매주

```bash
#!/bin/bash
# weekly_check.sh

# 1. 오래된 로그 파일 확인
echo "30일 이상 된 로그:"
find /opt/tomcat/logs -name "*.log" -o -name "*.txt" -o -name "*.gz" | \
  xargs ls -lt 2>/dev/null | awk '$6$7$8 < "'"$(date -d '30 days ago' +%Y-%m-%d 2>/dev/null)"'"' | head

# 2. 힙 덤프 잔존 여부
HPROF_FILES=$(ls /opt/tomcat/logs/*.hprof 2>/dev/null)
[ -n "$HPROF_FILES" ] && echo "[ALERT] 힙 덤프 파일 존재: $HPROF_FILES" || echo "[OK] 힙 덤프 없음"

# 3. GC 로그에서 Full GC 빈도 확인
echo "Full GC 발생 횟수 (최근 7일):"
grep "Pause Full" /opt/tomcat/logs/gc.log 2>/dev/null | wc -l

# 4. 접근 로그에서 5xx 에러율
echo "5xx 응답 비율:"
ACCESS_LOG="/opt/tomcat/logs/localhost_access_log.$(date +%Y-%m-%d).txt"
TOTAL=$(wc -l < "$ACCESS_LOG" 2>/dev/null || echo 0)
ERR5XX=$(grep -c '" 5[0-9][0-9] ' "$ACCESS_LOG" 2>/dev/null || echo 0)
[ "$TOTAL" -gt 0 ] && echo "$ERR5XX / $TOTAL ($(( ERR5XX * 100 / TOTAL ))%)" || echo "데이터 없음"
```

---

## 운영 중 설정 변경 (재시작 없이)

### logging.properties 동적 변경

```bash
# 운영 중 특정 패키지 로그 레벨 변경 (디버깅 시)
# JMX MBean을 통해 변경 (Tomcat Manager 또는 jconsole)

# jcmd로 동적 변경
jcmd $(pgrep -f tomcat) VM.set_flag -JVMParam ...

# 또는 Logback 사용 시: logback.xml의 scan="true" 설정으로 자동 재로딩
# <configuration scan="true" scanPeriod="30 seconds">
```

### JVM 플래그 동적 변경

```bash
# 일부 JVM 플래그는 실행 중 변경 가능
# GC 튜닝 파라미터 등

# 변경 가능한 플래그 목록 확인
jcmd $(pgrep -f tomcat) VM.flags -all | grep manageable

# 예: MaxHeapFreeRatio 변경
jcmd $(pgrep -f tomcat) VM.set_flag MaxHeapFreeRatio 40
```

---

## 모니터링 알람 설정 (CloudWatch 예시)

```bash
# AL2023 + CloudWatch Agent 설정
sudo tee /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/opt/tomcat/logs/catalina.out",
            "log_group_name": "/ec2/tomcat/catalina",
            "log_stream_name": "{instance_id}",
            "timestamp_format": "%Y-%m-%d %H:%M:%S"
          },
          {
            "file_path": "/opt/tomcat/logs/localhost_access_log.*",
            "log_group_name": "/ec2/tomcat/access",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "Tomcat/Custom",
    "metrics_collected": {
      "procstat": [
        {
          "pattern": "org.apache.catalina.startup.Bootstrap",
          "measurement": ["cpu_usage", "memory_rss", "num_threads"],
          "metrics_collection_interval": 60
        }
      ]
    }
  }
}
EOF

# CloudWatch Metric Alarm: 힙 사용률 80% 초과 시 알람
aws cloudwatch put-metric-alarm \
  --alarm-name "Tomcat-HighMemory" \
  --metric-name "memory_rss" \
  --namespace "Tomcat/Custom" \
  --statistic Average \
  --period 60 \
  --threshold 1600000000 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 3 \
  --alarm-actions "arn:aws:sns:ap-northeast-2:123456789:ops-alert"
```

---

## 실무 배포 실수 방지 체크리스트

```
배포 전
  [ ] WAR 파일 빌드 버전 태그 확인
  [ ] 배포 대상 환경 재확인 (prod인지 staging인지)
  [ ] DB 마이그레이션 스크립트 먼저 실행
  [ ] 롤백 계획 준비 (이전 WAR 파일 보관 위치 확인)
  [ ] 배포 시간: 트래픽 최저 시간대 선택

배포 중
  [ ] 헬스체크 엔드포인트 응답 확인
  [ ] catalina.out에서 "Server startup in" 확인
  [ ] 접근 로그에서 5xx 급증 없는지 모니터링

배포 후
  [ ] 주요 기능 스모크 테스트
  [ ] 응답 시간 이전 대비 정상 범위 확인
  [ ] GC 로그 이상 없는지 확인 (5분간 모니터링)
  [ ] 30분 후 에러율 재확인
```

---

## 빠른 명령어 모음 (실무 치트시트)

```bash
# Tomcat 상태 확인
sudo systemctl status tomcat
curl -sf http://localhost:8080/myapp/actuator/health

# 실시간 로그 모니터링
tail -f /opt/tomcat/logs/catalina.out
tail -f /opt/tomcat/logs/localhost_access_log.$(date +%Y-%m-%d).txt

# 에러만 실시간 모니터링
tail -f /opt/tomcat/logs/catalina.out | grep --line-buffered -i "error\|exception\|warn"

# 현재 스레드 수
ps -L -p $(pgrep -f tomcat) | wc -l

# JVM 메모리 현황
jcmd $(pgrep -f tomcat) GC.heap_info

# 빠른 스레드 덤프
jstack $(pgrep -f tomcat) 2>/dev/null | grep "java.lang.Thread.State" | sort | uniq -c | sort -rn

# 느린 요청 실시간 (3초 이상)
tail -f /opt/tomcat/logs/localhost_access_log.$(date +%Y-%m-%d).txt | awk '$NF > 3000'

# 오늘 에러 요약
grep "$(date +%Y-%m-%d)" /opt/tomcat/logs/catalina.out | grep -c "ERROR\|SEVERE"

# Tomcat 재시작 (안전)
sudo systemctl restart tomcat && sleep 5 && curl -sf http://localhost:8080/myapp/actuator/health
```

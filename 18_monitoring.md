# 18. 모니터링 (JMX & Manager App)

## Manager App 모니터링

### 상태 페이지

```bash
# 서버 상태 (HTML)
curl -u admin:password http://localhost:8080/manager/status

# 서버 상태 (XML, 파싱에 적합)
curl -u admin:password http://localhost:8080/manager/status/all?XML=true

# 주요 확인 항목
# - JVM 메모리 (힙, NonHeap)
# - 스레드 풀 (maxThreads, currentThreads, currentThreadsBusy)
# - Connector 요청 통계
# - 배포된 앱 목록
```

### 앱 관리 명령

```bash
BASE_URL="http://localhost:8080/manager/text"
AUTH="-u admin:password"

# 앱 목록
curl $AUTH "$BASE_URL/list"

# 앱 배포
curl $AUTH "$BASE_URL/deploy?path=/myapp&war=file:/tmp/myapp.war"

# 앱 언배포
curl $AUTH "$BASE_URL/undeploy?path=/myapp"

# 앱 시작 / 중지 / 재로드
curl $AUTH "$BASE_URL/start?path=/myapp"
curl $AUTH "$BASE_URL/stop?path=/myapp"
curl $AUTH "$BASE_URL/reload?path=/myapp"

# 세션 만료
curl $AUTH "$BASE_URL/expire?path=/myapp&idle=30"  # 30분 이상 유휴 세션 만료

# 세션 정보
curl $AUTH "$BASE_URL/sessions?path=/myapp"

# 서버 정보
curl $AUTH "$BASE_URL/serverinfo"
```

---

## JMX 모니터링

### JMX 원격 활성화

```bash
# setenv.sh에 추가
export CATALINA_OPTS="$CATALINA_OPTS \
  -Dcom.sun.management.jmxremote \
  -Dcom.sun.management.jmxremote.port=9999 \
  -Dcom.sun.management.jmxremote.rmi.port=9998 \
  -Dcom.sun.management.jmxremote.ssl=false \
  -Dcom.sun.management.jmxremote.authenticate=false \
  -Djava.rmi.server.hostname=서버IP \
"
```

```bash
# 방화벽 포트 허용
sudo firewall-cmd --permanent --add-port=9999/tcp
sudo firewall-cmd --permanent --add-port=9998/tcp
sudo firewall-cmd --reload
```

### jconsole로 연결

```bash
# 로컬
jconsole

# 원격 (서버IP:9999)
jconsole 서버IP:9999
```

---

## 주요 JMX MBean

### Connector 스레드 풀

```
MBean: Catalina:type=ThreadPool,name="http-nio-8080"

주요 속성:
- currentThreadCount     : 현재 생성된 스레드 수
- currentThreadsBusy     : 현재 요청 처리 중인 스레드 수
- maxThreads             : 최대 스레드 수
- connectionCount        : 현재 열린 연결 수
- maxConnections         : 최대 연결 수
```

### 요청 프로세서

```
MBean: Catalina:type=GlobalRequestProcessor,name="http-nio-8080"

주요 속성:
- requestCount           : 총 처리 요청 수
- errorCount             : 총 에러 수
- bytesReceived          : 수신 바이트
- bytesSent              : 송신 바이트
- processingTime         : 총 처리 시간 (ms)
- maxTime                : 최대 처리 시간 (ms)
```

### 세션 관리

```
MBean: Catalina:type=Manager,context=/myapp,host=localhost

주요 속성:
- activeSessions         : 현재 활성 세션 수
- maxActive              : 최대 동시 세션 수 (지금까지)
- sessionCounter         : 총 생성 세션 수
- expiredSessions        : 만료된 세션 수
- rejectedSessions       : 거부된 세션 수 (maxActiveSessions 초과)
- sessionAverageAliveTime: 평균 세션 유지 시간
- sessionMaxAliveTime    : 최대 세션 유지 시간
```

### 데이터소스

```
MBean: Catalina:type=DataSource,host=localhost,context=/myapp,class=javax.sql.DataSource,name="jdbc/mydb"

주요 속성:
- numActive              : 사용 중인 커넥션 수
- numIdle                : 유휴 커넥션 수
- maxTotal               : 최대 커넥션 수
- numTestsPerEvictionRun : 주기적 테스트 수
```

---

## JVM 모니터링 명령어

```bash
# JVM 힙 상태
jmap -heap $(pgrep -f tomcat)

# GC 실시간 통계
jstat -gcutil $(pgrep -f tomcat) 1000  # 1초마다 출력

# 스레드 덤프 (교착 상태 분석)
jstack $(pgrep -f tomcat) > /tmp/thread_dump_$(date +%Y%m%d_%H%M%S).txt

# OOM 발생 시 자동 힙 덤프
# setenv.sh에 추가:
export CATALINA_OPTS="$CATALINA_OPTS \
  -XX:+HeapDumpOnOutOfMemoryError \
  -XX:HeapDumpPath=/opt/tomcat/logs/heapdump.hprof \
"

# 힙 히스토그램 (객체별 메모리 사용량)
jmap -histo:live $(pgrep -f tomcat) | head -30

# 메모리 분석 (jcmd 사용)
jcmd $(pgrep -f tomcat) VM.native_memory scale=MB
jcmd $(pgrep -f tomcat) GC.heap_info
jcmd $(pgrep -f tomcat) Thread.print > /tmp/threads.txt
```

---

## Prometheus + Grafana 연동

### JMX Exporter 방식

```bash
# jmx_prometheus_javaagent 다운로드
wget https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.19.0/jmx_prometheus_javaagent-0.19.0.jar
sudo cp jmx_prometheus_javaagent-0.19.0.jar /opt/tomcat/lib/
```

```yaml
# /opt/tomcat/conf/jmx_exporter.yml
---
startDelaySeconds: 0
ssl: false
lowercaseOutputName: true
rules:
  # 스레드 풀
  - pattern: 'Catalina<type=ThreadPool, name="(.*?)"><>(currentThreadCount|currentThreadsBusy|maxThreads|connectionCount)'
    name: tomcat_threadpool_$2
    labels:
      name: "$1"

  # 요청 처리
  - pattern: 'Catalina<type=GlobalRequestProcessor, name="(.*?)"><>(requestCount|errorCount|processingTime|bytesSent|bytesReceived)'
    name: tomcat_global_$2
    labels:
      name: "$1"

  # 세션
  - pattern: 'Catalina<type=Manager, host=(.*), context=(.*)><>(activeSessions|sessionCounter|expiredSessions)'
    name: tomcat_session_$3
    labels:
      host: "$1"
      context: "$2"
```

```bash
# setenv.sh에 javaagent 추가
export CATALINA_OPTS="$CATALINA_OPTS \
  -javaagent:/opt/tomcat/lib/jmx_prometheus_javaagent-0.19.0.jar=9404:/opt/tomcat/conf/jmx_exporter.yml \
"
```

### Prometheus 스크레이프 설정

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'tomcat'
    static_configs:
      - targets: ['tomcat-host:9404']
    metrics_path: '/metrics'
```

### Grafana 대시보드

```
Grafana 대시보드 ID: 3894 (JVM 통계), 8563 (Tomcat 전용)
```

---

## 모니터링 체크리스트

```bash
# 1. JVM 메모리 사용률 (80% 초과 시 경고)
jstat -gcutil $(pgrep -f tomcat) | awk 'NR>1 {print "Heap: " $4+$6 "%"}'

# 2. 스레드 포화 여부
# currentThreadsBusy >= maxThreads × 0.8 → 경고

# 3. 세션 수 이상 증가 여부
curl -u admin:password http://localhost:8080/manager/text/sessions?path=/

# 4. 접근 로그에서 5xx 에러 비율
awk '{print $9}' /opt/tomcat/logs/localhost_access_log.$(date +%Y-%m-%d).txt \
  | awk '/^5/ {err++} {total++} END {printf "5xx rate: %.2f%%\n", err/total*100}'

# 5. GC pause 시간 확인 (1초 초과 시 경고)
grep "Pause" /opt/tomcat/logs/gc.log | tail -20
```

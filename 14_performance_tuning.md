# 14. 성능 튜닝

## JVM 튜닝

### 힙 메모리 설정

```bash
# setenv.sh
export CATALINA_OPTS="\
  -Xms1g \
  -Xmx2g \
  -XX:MetaspaceSize=256m \
  -XX:MaxMetaspaceSize=512m \
"
# -Xms: 초기 힙 크기 (Xmx와 같게 설정 → GC로 인한 힙 확장 방지)
# -Xmx: 최대 힙 크기 (물리 메모리의 50~75% 권장)
# MetaspaceSize: 클래스 메타데이터 저장 공간
```

### GC 설정 (Java 17+)

```bash
# ZGC (저지연, 대용량 힙에 적합)
export CATALINA_OPTS="$CATALINA_OPTS \
  -XX:+UseZGC \
  -XX:MaxGCPauseMillis=10 \
"

# G1GC (균형적, 일반적으로 권장)
export CATALINA_OPTS="$CATALINA_OPTS \
  -XX:+UseG1GC \
  -XX:MaxGCPauseMillis=200 \
  -XX:G1HeapRegionSize=16m \
  -XX:G1NewSizePercent=30 \
  -XX:G1MaxNewSizePercent=40 \
  -XX:G1MixedGCCountTarget=8 \
"
```

### GC 로깅

```bash
export CATALINA_OPTS="$CATALINA_OPTS \
  -Xlog:gc*:file=/opt/tomcat/logs/gc.log:time,uptime,tags:filecount=5,filesize=20m \
"
```

### JVM 기타 옵션

```bash
export CATALINA_OPTS="$CATALINA_OPTS \
  -server \                            # 서버 JIT 컴파일러 사용 (기본)
  -XX:+OptimizeStringConcat \          # 문자열 연결 최적화
  -XX:+UseStringDeduplication \        # G1GC에서 중복 문자열 메모리 절약
  -Djava.awt.headless=true \           # GUI 없는 서버 환경
  -Dfile.encoding=UTF-8 \
  -Duser.timezone=Asia/Seoul \
"
```

---

## Connector 스레드 튜닝

```xml
<!-- server.xml -->
<Connector port="8080"
           protocol="org.apache.coyote.http11.Http11NioProtocol"

           <!-- 스레드 풀 -->
           maxThreads="400"              <!-- 동시 요청 처리 수 (CPU 코어 × 2 ~ 4배) -->
           minSpareThreads="20"          <!-- 최소 유휴 스레드 -->
           acceptCount="200"             <!-- 스레드 포화 시 대기 큐 -->
           maxConnections="20000"        <!-- NIO 최대 연결 수 -->

           <!-- 타임아웃 -->
           connectionTimeout="10000"    <!-- 연결 타임아웃 단축 (기본 20초 → 10초) -->
           keepAliveTimeout="15000"     <!-- Keep-Alive 타임아웃 -->
           maxKeepAliveRequests="100"   <!-- Keep-Alive당 최대 요청 수 -->

           <!-- TCP 설정 -->
           tcpNoDelay="true"            <!-- Nagle 알고리즘 비활성화 -->
           socket.txBufSize="65536"     <!-- 송신 버퍼 크기 -->
           socket.rxBufSize="65536"     <!-- 수신 버퍼 크기 -->
/>
```

### Executor 공유 스레드 풀

```xml
<Executor name="tomcatThreadPool"
          namePrefix="catalina-exec-"
          maxThreads="400"
          minSpareThreads="20"
          prestartminSpareThreads="true"   <!-- 시작 시 최소 스레드 미리 생성 -->
          maxQueueSize="100"               <!-- 대기 큐 크기 -->
          maxIdleTime="60000" />           <!-- 유휴 스레드 종료 대기 시간 -->
```

---

## OS 레벨 튜닝

```bash
# ============================================================
# 파일 디스크립터 한계 증가
# ============================================================
sudo tee /etc/security/limits.d/tomcat.conf << 'EOF'
tomcat soft nofile 65536
tomcat hard nofile 65536
tomcat soft nproc  65536
tomcat hard nproc  65536
EOF

# systemd 서비스에서도 설정
# /etc/systemd/system/tomcat.service에 추가:
# LimitNOFILE=65536
# LimitNPROC=65536

# ============================================================
# 커널 네트워크 파라미터 튜닝
# ============================================================
sudo tee /etc/sysctl.d/99-tomcat.conf << 'EOF'
# 소켓 백로그
net.core.somaxconn = 65536
net.ipv4.tcp_max_syn_backlog = 65536

# TIME_WAIT 최적화
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15

# 소켓 버퍼
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# 로컬 포트 범위 확대 (클라이언트로서)
net.ipv4.ip_local_port_range = 10240 65535
EOF

sudo sysctl -p /etc/sysctl.d/99-tomcat.conf
```

---

## 정적 파일 최적화

```xml
<!-- conf/web.xml의 DefaultServlet 설정 -->
<servlet>
    <servlet-name>default</servlet-name>
    <servlet-class>org.apache.catalina.servlets.DefaultServlet</servlet-class>
    <init-param>
        <param-name>debug</param-name>
        <param-value>0</param-value>
    </init-param>
    <init-param>
        <param-name>listings</param-name>
        <param-value>false</param-value>
    </init-param>
    <init-param>
        <!-- 정적 파일 캐시 활성화 -->
        <param-name>cacheMaxSize</param-name>
        <param-value>102400</param-value>   <!-- 캐시 최대 크기 (KB) -->
    </init-param>
    <init-param>
        <param-name>cacheObjectMaxSize</param-name>
        <param-value>512</param-value>      <!-- 단일 파일 최대 캐시 크기 (KB) -->
    </init-param>
    <init-param>
        <param-name>cacheTtl</param-name>
        <param-value>5000</param-value>     <!-- 캐시 TTL (ms) -->
    </init-param>
    <load-on-startup>1</load-on-startup>
</servlet>
```

---

## JSP 튜닝

```xml
<!-- conf/web.xml의 JspServlet -->
<servlet>
    <servlet-name>jsp</servlet-name>
    <servlet-class>org.apache.jasper.servlet.JspServlet</servlet-class>
    <init-param>
        <!-- 운영 환경: false (JSP 변경 감지 비활성화) -->
        <param-name>development</param-name>
        <param-value>false</param-value>
    </init-param>
    <init-param>
        <!-- 컴파일 결과 캐시 크기 -->
        <param-name>checkInterval</param-name>
        <param-value>0</param-value>  <!-- 0: 변경 감지 비활성화 -->
    </init-param>
    <init-param>
        <!-- 디버그 정보 제외 (클래스 크기 감소) -->
        <param-name>classdebuginfo</param-name>
        <param-value>false</param-value>
    </init-param>
    <init-param>
        <!-- 미리 컴파일된 JSP 클래스 매핑 파일 -->
        <param-name>mappedFile</param-name>
        <param-value>true</param-value>
    </init-param>
    <load-on-startup>3</load-on-startup>
</servlet>
```

---

## 응답 압축

```xml
<Connector port="8080"
           protocol="HTTP/1.1"
           compression="on"
           compressionMinSize="2048"
           compressibleMimeType="text/html,text/xml,text/plain,text/css,text/javascript,application/javascript,application/json,application/xml"
           noCompressionUserAgents="" />
```

---

## 성능 측정

```bash
# Apache Bench (ab) 로 부하 테스트
ab -n 10000 -c 100 http://localhost:8080/myapp/

# wrk 로 부하 테스트
wrk -t4 -c100 -d30s http://localhost:8080/myapp/

# JVM 상태 확인
jstat -gc $(pgrep -f tomcat) 1000  # 1초마다 GC 통계
jstat -gcutil $(pgrep -f tomcat) 1000

# 스레드 덤프 (현재 스레드 상태)
jstack $(pgrep -f tomcat) > /tmp/thread_dump.txt

# 힙 덤프
jmap -dump:format=b,file=/tmp/heap.hprof $(pgrep -f tomcat)

# GC 확인
jcmd $(pgrep -f tomcat) GC.heap_info
```

---

## 성능 체크리스트

```
JVM 설정
  [ ] Xms = Xmx (힙 리사이징 방지)
  [ ] 적절한 GC 선택 (G1GC 또는 ZGC)
  [ ] GC 로깅 활성화 (분석용)

Connector
  [ ] maxThreads 적절히 설정 (과도하게 높이면 스레드 컨텍스트 스위칭 증가)
  [ ] connectionTimeout 적정값으로 단축
  [ ] 압축 활성화

애플리케이션
  [ ] reloadable="false" (운영)
  [ ] development="false" (JSP)
  [ ] DB 커넥션 풀 적정 크기 설정
  [ ] 세션 크기 최소화

OS
  [ ] 파일 디스크립터 한계 증가
  [ ] TCP 파라미터 튜닝
  [ ] Transparent Huge Pages 비활성화 (GC 성능)
```

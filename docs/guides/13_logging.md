# 13. 로깅

## Tomcat 로깅 구조

Tomcat은 내부적으로 `java.util.logging` (JUL) 기반의 **JULI(Java Util Logging Improvements)**를 사용합니다.
웹 애플리케이션은 주로 **Log4j2**, **Logback** 등의 SLF4J 기반 프레임워크를 사용합니다.

---

## 로그 파일 목록

```
/opt/tomcat/logs/
├── catalina.out                       ← JVM stdout/stderr, 가장 중요한 로그
├── catalina.YYYY-MM-DD.log            ← Catalina 내부 로그 (JUL)
├── localhost.YYYY-MM-DD.log           ← 호스트 레벨 로그
├── manager.YYYY-MM-DD.log             ← Manager App 로그
├── host-manager.YYYY-MM-DD.log        ← Host Manager App 로그
└── localhost_access_log.YYYY-MM-DD.txt ← AccessLogValve 접근 로그
```

### catalina.out vs catalina.YYYY-MM-DD.log

| 파일 | 내용 | 특징 |
|------|------|------|
| `catalina.out` | JVM 전체 stdout/stderr | 로그 로테이션 없음, 무한 증가 주의 |
| `catalina.*.log` | JULI가 관리하는 Catalina 로그 | 날짜별 자동 로테이션 |

---

## logging.properties 설정

```properties
# conf/logging.properties

# 핸들러 목록 (콘솔 + 파일)
handlers = \
  1catalina.org.apache.juli.AsyncFileHandler, \
  2localhost.org.apache.juli.AsyncFileHandler, \
  3manager.org.apache.juli.AsyncFileHandler, \
  4host-manager.org.apache.juli.AsyncFileHandler, \
  java.util.logging.ConsoleHandler

# ============================================================
# 핸들러 설정
# ============================================================
.handlers = 1catalina.org.apache.juli.AsyncFileHandler, java.util.logging.ConsoleHandler

# Catalina 파일 핸들러
1catalina.org.apache.juli.AsyncFileHandler.level = FINE
1catalina.org.apache.juli.AsyncFileHandler.directory = ${catalina.base}/logs
1catalina.org.apache.juli.AsyncFileHandler.prefix = catalina.
1catalina.org.apache.juli.AsyncFileHandler.suffix = .log
1catalina.org.apache.juli.AsyncFileHandler.maxDays = 90        # 보관 일수
1catalina.org.apache.juli.AsyncFileHandler.encoding = UTF-8

# localhost 파일 핸들러
2localhost.org.apache.juli.AsyncFileHandler.level = FINE
2localhost.org.apache.juli.AsyncFileHandler.directory = ${catalina.base}/logs
2localhost.org.apache.juli.AsyncFileHandler.prefix = localhost.
2localhost.org.apache.juli.AsyncFileHandler.suffix = .log
2localhost.org.apache.juli.AsyncFileHandler.maxDays = 90
2localhost.org.apache.juli.AsyncFileHandler.encoding = UTF-8

# 콘솔 핸들러
java.util.logging.ConsoleHandler.level = FINE
java.util.logging.ConsoleHandler.formatter = org.apache.juli.OneLineFormatter
java.util.logging.ConsoleHandler.encoding = UTF-8

# ============================================================
# 로거 설정 (패키지별 레벨 조정)
# ============================================================

# Catalina 전체
org.apache.catalina.core.ContainerBase.[Catalina].[localhost].level = INFO
org.apache.catalina.core.ContainerBase.[Catalina].[localhost].handlers = 2localhost.org.apache.juli.AsyncFileHandler

# Manager App
org.apache.catalina.core.ContainerBase.[Catalina].[localhost].[/manager].level = INFO
org.apache.catalina.core.ContainerBase.[Catalina].[localhost].[/manager].handlers = 3manager.org.apache.juli.AsyncFileHandler

# 특정 패키지 로그 레벨 상세 설정 (디버깅용)
org.apache.coyote.http11.Http11NioProtocol.level = WARNING
org.apache.tomcat.util.net.NioSelectorPool.level = WARNING
org.apache.catalina.session.level = INFO
```

---

## 접근 로그 (AccessLogValve)

```xml
<!-- server.xml의 Host 또는 Context 내부에 설정 -->
<Valve className="org.apache.catalina.valves.AccessLogValve"
       directory="${catalina.base}/logs"
       prefix="access_log"
       suffix=".txt"
       fileDateFormat="yyyy-MM-dd"
       rotatable="true"

       <!-- 로그 포맷 -->
       pattern="%{yyyy-MM-dd HH:mm:ss.SSS}t %h %l %u &quot;%r&quot; %s %b %D %{Referer}i %{User-Agent}i"

       <!-- 버퍼링 (성능 향상, 기본 true) -->
       buffered="true"
       bufferedWrite="true"

       <!-- 특정 요청 제외 (헬스체크 등) -->
       conditionIf=""
       conditionUnless="skipLogging"

       <!-- IP 치환 (Nginx 뒤에 있을 때) -->
       requestAttributesEnabled="true" />
```

### 주요 패턴 변수

| 변수 | 설명 |
|------|------|
| `%h` | 원격 호스트 IP |
| `%l` | 원격 논리 사용자명 |
| `%u` | 인증 사용자명 |
| `%t` | 요청 수신 시각 |
| `%r` | 요청 첫 번째 라인 |
| `%s` | HTTP 상태 코드 |
| `%b` | 응답 크기 (bytes, `-`: 0인 경우) |
| `%B` | 응답 크기 (bytes, 0도 숫자로 출력) |
| `%D` | 처리 시간 (밀리초) |
| `%T` | 처리 시간 (초) |
| `%{X-Forwarded-For}i` | 특정 요청 헤더 값 |
| `%{Referer}i` | Referer 헤더 |
| `%{User-Agent}i` | User-Agent 헤더 |
| `%q` | 쿼리 스트링 |
| `%m` | HTTP 메서드 |
| `%U` | URI |

---

## catalina.out 로테이션

`catalina.out`은 JVM stdout이라 JULI가 관리하지 않습니다.
별도 설정이 없으면 무한 증가합니다.

### 방법 1: logrotate 사용

#### logrotate 기본 개념

| 옵션 | 설명 |
|------|------|
| `daily` / `weekly` / `monthly` | 로테이션 주기 |
| `rotate N` | N개 파일 보관 후 삭제 |
| `size 500M` | 파일 크기 기준 로테이션 (주기 대신 사용 가능) |
| `compress` | gzip 압축 |
| `delaycompress` | 가장 최근 로테이션 파일은 압축 안 함 (tail 가능하도록) |
| `missingok` | 파일 없어도 에러 무시 |
| `notifempty` | 빈 파일은 로테이션 안 함 |
| `copytruncate` | 파일 내용만 비움 (Tomcat 재시작 불필요 — 실무 핵심) |
| `create` | 기존 파일 이름 변경 후 새 파일 생성 (fd 재오픈 필요) |
| `sharedscripts` | `postrotate`를 여러 파일이 공유 (1회만 실행) |
| `dateext` | 파일명에 날짜 붙임 (catalina.out-20260415.gz 형태) |

#### `copytruncate` vs `create` (실무 핵심 차이)

```
copytruncate 방식:
  파일 복사 → 원본 비움
  Tomcat이 같은 fd를 계속 사용 → 재시작 불필요
  단점: 복사와 비움 사이 짧은 시간에 쓰인 로그 유실 가능 (수 ms)

create 방식:
  원본 파일 이름 변경 → 새 파일 생성
  Tomcat은 여전히 이름 변경된 파일에 씀
  → postrotate에서 Tomcat에 신호 보내 fd 재오픈 필요 (실질적으로 재시작)
  → catalina.out은 copytruncate가 현실적
```

#### catalina.out + 접근 로그 통합 설정

```bash
sudo tee /etc/logrotate.d/tomcat << 'EOF'
# catalina.out: copytruncate 방식 (무중단)
/opt/tomcat/logs/catalina.out {
    daily
    rotate 30
    missingok
    notifempty
    compress
    delaycompress
    dateext
    dateformat -%Y%m%d
    copytruncate
    su tomcat tomcat
}

# 접근 로그: JULI가 날짜별로 새 파일 생성하므로 오래된 것만 압축/정리
/opt/tomcat/logs/localhost_access_log.*.txt {
    monthly
    rotate 3
    missingok
    compress
    nodelaycompress
    su tomcat tomcat
    sharedscripts
    postrotate
        # 이미 날짜 기반으로 파일이 나뉘므로 압축만
        find /opt/tomcat/logs -name "localhost_access_log.*.txt" -mtime +30 -exec gzip {} \;
    endscript
}

# GC 로그 (JVM이 직접 관리하지 않는 경우)
/opt/tomcat/logs/gc.log {
    weekly
    rotate 8
    missingok
    compress
    delaycompress
    copytruncate
    su tomcat tomcat
}
EOF

# 권한 확인
sudo chmod 644 /etc/logrotate.d/tomcat
```

#### logrotate 테스트 및 운영

```bash
# dry run (실제 로테이션 없이 시뮬레이션)
sudo logrotate -d /etc/logrotate.d/tomcat

# 강제 실행 (rotate 조건 무시하고 즉시 실행)
sudo logrotate -f /etc/logrotate.d/tomcat

# 상태 파일 확인 (마지막 로테이션 날짜)
cat /var/lib/logrotate/logrotate.status | grep tomcat

# cron 스케줄 확인 (기본: 매일 실행)
cat /etc/cron.daily/logrotate
# 또는 systemd timer 확인
systemctl list-timers | grep logrotate

# 로테이션 후 디스크 사용량 확인
du -sh /opt/tomcat/logs/
ls -lh /opt/tomcat/logs/
```

#### size 기반 로테이션 (용량 임계치)

```bash
# 크기가 500MB를 넘으면 즉시 로테이션 (시간과 무관)
/opt/tomcat/logs/catalina.out {
    size 500M
    rotate 5
    missingok
    compress
    delaycompress
    copytruncate
    su tomcat tomcat
}
```

> **실무 팁**: 운영 서버에서 `daily + rotate 30`을 기본으로 하되, 트래픽이 많아 하루에 수GB씩 쌓이는 환경이라면 `size 1G`를 추가하거나, 로그 레벨을 조정합니다.

### 방법 2: catalina.out 비활성화

catalina.out 대신 JULI 파일 핸들러만 사용합니다.

```bash
# setenv.sh에 추가
export CATALINA_OUT=/dev/null

# 이 경우 모든 로그는 catalina.YYYY-MM-DD.log에 기록됨
# JULI의 maxDays 설정으로 자동 보관 관리 가능 (logrotate 불필요)
```

---

## 앱 로깅 (Log4j2 / Logback)

웹 애플리케이션에서 SLF4J + Logback을 사용하는 경우:

```xml
<!-- WEB-INF/lib에 포함 -->
<!-- logback-classic-*.jar, logback-core-*.jar, slf4j-api-*.jar -->

<!-- WEB-INF/classes/logback.xml -->
<configuration>
    <appender name="FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
        <file>/opt/tomcat/logs/myapp.log</file>
        <rollingPolicy class="ch.qos.logback.core.rolling.TimeBasedRollingPolicy">
            <fileNamePattern>/opt/tomcat/logs/myapp.%d{yyyy-MM-dd}.log</fileNamePattern>
            <maxHistory>30</maxHistory>
            <totalSizeCap>1GB</totalSizeCap>
        </rollingPolicy>
        <encoder>
            <pattern>%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n</pattern>
        </encoder>
    </appender>

    <root level="INFO">
        <appender-ref ref="FILE" />
    </root>
</configuration>
```

---

## 로그 분석 명령어

```bash
# 실시간 로그 모니터링
tail -f /opt/tomcat/logs/catalina.out
tail -f /opt/tomcat/logs/localhost_access_log.$(date +%Y-%m-%d).txt

# 에러만 필터링
grep -i "ERROR\|Exception\|SEVERE" /opt/tomcat/logs/catalina.out

# 특정 시간대 로그
awk '/2024-01-15 10:00/,/2024-01-15 11:00/' /opt/tomcat/logs/catalina.out

# 접근 로그에서 상태 코드별 집계
awk '{print $9}' /opt/tomcat/logs/localhost_access_log.*.txt | sort | uniq -c | sort -rn

# 느린 요청 추출 (100ms 이상)
awk '$NF > 100 {print}' /opt/tomcat/logs/localhost_access_log.*.txt

# 가장 많이 요청된 URL Top 10
awk '{print $7}' /opt/tomcat/logs/localhost_access_log.*.txt | sort | uniq -c | sort -rn | head -10

# IP별 요청 수 집계
awk '{print $1}' /opt/tomcat/logs/localhost_access_log.*.txt | sort | uniq -c | sort -rn | head -20
```

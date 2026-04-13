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

```bash
sudo tee /etc/logrotate.d/tomcat << 'EOF'
/opt/tomcat/logs/catalina.out {
    daily
    rotate 30
    missingok
    notifempty
    compress
    delaycompress
    sharedscripts
    copytruncate    # 파일 이름 변경 없이 내용만 잘라냄 (무중단)
}
EOF

# 수동 실행 테스트
sudo logrotate -d /etc/logrotate.d/tomcat  # dry run
sudo logrotate -f /etc/logrotate.d/tomcat  # 강제 실행
```

### 방법 2: catalina.out 비활성화

catalina.out 대신 JULI 파일 핸들러만 사용합니다.

```bash
# catalina.sh에서 CATALINA_OUT을 /dev/null로 설정
# setenv.sh에 추가
export CATALINA_OUT=/dev/null
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

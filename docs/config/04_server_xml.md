# 04. server.xml 설정

`server.xml`은 Tomcat의 핵심 설정 파일입니다.
서버 전체 구조(Connector, Engine, Host, Context)를 정의합니다.

## 전체 구조 예시

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Server port="8005" shutdown="SHUTDOWN">

  <!-- 리스너: Tomcat 라이프사이클 이벤트 처리 -->
  <Listener className="org.apache.catalina.startup.VersionLoggerListener" />
  <Listener className="org.apache.catalina.core.AprLifecycleListener" SSLEngine="on" />
  <Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />
  <Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener" />
  <Listener className="org.apache.catalina.core.ThreadLocalLeakPreventionListener" />

  <!-- 전역 JNDI 리소스 -->
  <GlobalNamingResources>
    <Resource name="UserDatabase"
              auth="Container"
              type="org.apache.catalina.UserDatabase"
              description="User database that can be updated and saved"
              factory="org.apache.catalina.users.MemoryUserDatabaseFactory"
              pathname="conf/tomcat-users.xml" />
  </GlobalNamingResources>

  <Service name="Catalina">

    <!-- HTTP Connector -->
    <Connector port="8080"
               protocol="HTTP/1.1"
               connectionTimeout="20000"
               redirectPort="8443"
               maxThreads="200"
               minSpareThreads="10"
               acceptCount="100"
               URIEncoding="UTF-8" />

    <!-- HTTPS Connector (SSL 설정 참조) -->
    <!-- <Connector port="8443" ... /> -->

    <!-- AJP Connector (Apache/Nginx 연동) -->
    <!-- <Connector protocol="AJP/1.3" port="8009" ... /> -->

    <Engine name="Catalina" defaultHost="localhost">

      <!-- Realm 설정 -->
      <Realm className="org.apache.catalina.realm.LockOutRealm">
        <Realm className="org.apache.catalina.realm.UserDatabaseRealm"
               resourceName="UserDatabase"/>
      </Realm>

      <!-- 기본 가상 호스트 -->
      <Host name="localhost" appBase="webapps"
            unpackWARs="true" autoDeploy="true">

        <!-- 접근 로그 Valve -->
        <Valve className="org.apache.catalina.valves.AccessLogValve"
               directory="logs"
               prefix="localhost_access_log"
               suffix=".txt"
               pattern="%h %l %u %t &quot;%r&quot; %s %b" />

      </Host>
    </Engine>
  </Service>
</Server>
```

---

## Server 요소

```xml
<Server port="8005" shutdown="SHUTDOWN">
```

| 속성 | 설명 | 보안 고려사항 |
|------|------|-------------|
| `port` | shutdown 명령을 수신하는 포트 | `-1`로 설정하면 비활성화 (권장) |
| `shutdown` | shutdown 신호 문자열 | 기본값 변경 권장 |

```xml
<!-- shutdown 포트 비활성화 (보안 권장) -->
<Server port="-1" shutdown="SHUTDOWN">
```

---

## Connector 설정 상세

### HTTP/1.1 NIO Connector

```xml
<Connector
    port="8080"
    protocol="HTTP/1.1"

    <!-- I/O 모델 (기본: NIO) -->
    <!-- protocol="org.apache.coyote.http11.Http11NioProtocol" -->

    <!-- 타임아웃 -->
    connectionTimeout="20000"      <!-- 연결 타임아웃 (ms) -->
    keepAliveTimeout="15000"       <!-- Keep-Alive 타임아웃 -->

    <!-- 스레드 설정 -->
    maxThreads="200"               <!-- 최대 Worker 스레드 수 -->
    minSpareThreads="10"           <!-- 최소 대기 스레드 수 -->
    acceptCount="100"              <!-- 연결 대기 큐 크기 -->
    maxConnections="10000"         <!-- 최대 동시 연결 수 -->

    <!-- 요청 크기 제한 -->
    maxHttpHeaderSize="8192"       <!-- HTTP 헤더 최대 크기 (bytes) -->
    maxPostSize="2097152"          <!-- POST 데이터 최대 크기 (bytes, 기본 2MB) -->

    <!-- 인코딩 -->
    URIEncoding="UTF-8"

    <!-- X-Forwarded-For 처리 (Nginx/LB 뒤에 있을 때) -->
    <!-- proxyName, proxyPort는 deprecated, RemoteIpValve 사용 권장 -->

    redirectPort="8443"            <!-- HTTP → HTTPS 리다이렉트 포트 -->
/>
```

### NIO2 Connector (비동기 I/O)

```xml
<Connector port="8080"
           protocol="org.apache.coyote.http11.Http11Nio2Protocol"
           connectionTimeout="20000"
           redirectPort="8443" />
```

### 커넥션 압축 활성화

```xml
<Connector port="8080"
           protocol="HTTP/1.1"
           compression="on"
           compressionMinSize="2048"
           compressibleMimeType="text/html,text/xml,text/plain,text/css,text/javascript,application/javascript,application/json"
           connectionTimeout="20000"
           redirectPort="8443" />
```

---

## Engine 설정

```xml
<Engine name="Catalina" defaultHost="localhost">
```

| 속성 | 설명 |
|------|------|
| `name` | Engine 이름 (로그, JMX에서 사용) |
| `defaultHost` | Host 헤더와 일치하는 Host가 없을 때 사용할 기본 Host |
| `jvmRoute` | 클러스터링 시 세션 스티키 라우팅용 식별자 (`worker1`, `worker2`) |

```xml
<!-- 클러스터링 환경 -->
<Engine name="Catalina" defaultHost="localhost" jvmRoute="worker1">
```

---

## Host 설정

```xml
<Host name="localhost"
      appBase="webapps"
      unpackWARs="true"
      autoDeploy="true"
      deployOnStartup="true">
```

| 속성 | 기본값 | 설명 |
|------|--------|------|
| `name` | - | 가상 호스트 이름 (도메인) |
| `appBase` | `webapps` | 웹 앱 기본 디렉토리 (상대경로: CATALINA_BASE 기준) |
| `unpackWARs` | `true` | WAR 자동 압축 해제 여부 |
| `autoDeploy` | `true` | 런타임 중 새 WAR 자동 배포 여부 |
| `deployOnStartup` | `true` | 시작 시 자동 배포 여부 |
| `xmlValidation` | `false` | XML 유효성 검사 여부 |
| `xmlNamespaceAware` | `false` | XML 네임스페이스 인식 여부 |

---

## 주요 Listener

```xml
<!-- APR/OpenSSL 사용 시 (네이티브 성능 향상) -->
<Listener className="org.apache.catalina.core.AprLifecycleListener" SSLEngine="on" />

<!-- JRE 메모리 누수 방지 (권장) -->
<Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />

<!-- 스레드 로컬 누수 방지 -->
<Listener className="org.apache.catalina.core.ThreadLocalLeakPreventionListener" />

<!-- 버전 정보 로깅 -->
<Listener className="org.apache.catalina.startup.VersionLoggerListener" />
```

---

## Valve 설정

### AccessLogValve

```xml
<Valve className="org.apache.catalina.valves.AccessLogValve"
       directory="logs"
       prefix="localhost_access_log"
       suffix=".txt"
       pattern="%h %l %u %t &quot;%r&quot; %s %b %D"
       rotatable="true"
       fileDateFormat="yyyy-MM-dd"
       buffered="true"
       bufferedWrite="true" />
```

주요 패턴 변수:

| 변수 | 의미 |
|------|------|
| `%h` | 원격 호스트 (IP) |
| `%l` | 원격 논리 사용자 이름 |
| `%u` | 인증된 사용자 이름 |
| `%t` | 타임스탬프 |
| `%r` | 요청 첫 번째 라인 |
| `%s` | HTTP 상태 코드 |
| `%b` | 응답 크기 (bytes) |
| `%D` | 처리 시간 (ms) |
| `%{X-Forwarded-For}i` | 특정 요청 헤더 값 |

### RemoteAddrValve (IP 접근 제어)

```xml
<!-- 특정 IP만 허용 -->
<Valve className="org.apache.catalina.valves.RemoteAddrValve"
       allow="192\.168\.1\..*|127\..*" />

<!-- 특정 IP 차단 -->
<Valve className="org.apache.catalina.valves.RemoteAddrValve"
       deny="10\.0\.0\.1" />
```

### StuckThreadDetectionValve

```xml
<!-- 30초 이상 처리 중인 스레드 경고 로그 -->
<Valve className="org.apache.catalina.valves.StuckThreadDetectionValve"
       threshold="30"
       interruptThreadThreshold="60" />
```

### RemoteIpValve (X-Forwarded-For 처리)

```xml
<!-- Nginx/LB 뒤에 있을 때 실제 클라이언트 IP 처리 -->
<Valve className="org.apache.catalina.valves.RemoteIpValve"
       remoteIpHeader="X-Forwarded-For"
       protocolHeader="X-Forwarded-Proto"
       internalProxies="192\.168\..*|10\..*" />
```

---

## 실전 server.xml (최적화 버전)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Server port="-1" shutdown="SHUTDOWN">

  <Listener className="org.apache.catalina.startup.VersionLoggerListener" />
  <Listener className="org.apache.catalina.core.AprLifecycleListener" SSLEngine="on" />
  <Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />
  <Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener" />
  <Listener className="org.apache.catalina.core.ThreadLocalLeakPreventionListener" />

  <GlobalNamingResources>
    <Resource name="UserDatabase"
              auth="Container"
              type="org.apache.catalina.UserDatabase"
              factory="org.apache.catalina.users.MemoryUserDatabaseFactory"
              pathname="conf/tomcat-users.xml" />
  </GlobalNamingResources>

  <Service name="Catalina">

    <Connector port="8080"
               protocol="org.apache.coyote.http11.Http11NioProtocol"
               connectionTimeout="20000"
               keepAliveTimeout="15000"
               maxThreads="400"
               minSpareThreads="20"
               acceptCount="200"
               maxConnections="20000"
               compression="on"
               compressionMinSize="2048"
               compressibleMimeType="text/html,text/xml,text/plain,text/css,text/javascript,application/javascript,application/json"
               URIEncoding="UTF-8"
               server="Apache"
               redirectPort="8443" />

    <Engine name="Catalina" defaultHost="localhost">

      <Realm className="org.apache.catalina.realm.LockOutRealm">
        <Realm className="org.apache.catalina.realm.UserDatabaseRealm"
               resourceName="UserDatabase"/>
      </Realm>

      <Host name="localhost"
            appBase="webapps"
            unpackWARs="true"
            autoDeploy="false"
            deployOnStartup="true">

        <Valve className="org.apache.catalina.valves.RemoteIpValve"
               remoteIpHeader="X-Forwarded-For"
               protocolHeader="X-Forwarded-Proto" />

        <Valve className="org.apache.catalina.valves.AccessLogValve"
               directory="logs"
               prefix="localhost_access_log"
               suffix=".txt"
               pattern="%h %l %u %t &quot;%r&quot; %s %b %D"
               rotatable="true" />

        <Valve className="org.apache.catalina.valves.StuckThreadDetectionValve"
               threshold="30" />

      </Host>
    </Engine>
  </Service>
</Server>
```

# 08. 커넥터 (HTTP / AJP / HTTPS)

## Connector 개요

Connector는 외부 요청을 수신하여 Engine으로 전달하는 컴포넌트입니다.
프로토콜과 I/O 모델에 따라 여러 종류가 있습니다.

---

## HTTP/1.1 커넥터

### NIO (Non-blocking I/O) — 기본값, 권장

```xml
<Connector port="8080"
           protocol="HTTP/1.1"
           <!-- 또는 명시적으로: protocol="org.apache.coyote.http11.Http11NioProtocol" -->

           <!-- 타임아웃 -->
           connectionTimeout="20000"        <!-- 최초 연결 타임아웃 (ms) -->
           keepAliveTimeout="15000"         <!-- Keep-Alive 타임아웃 (ms, -1: connectionTimeout 사용) -->
           maxKeepAliveRequests="100"       <!-- Keep-Alive 당 최대 요청 수 (-1: 무제한) -->
           disableUploadTimeout="true"      <!-- 업로드 중 타임아웃 비활성화 -->

           <!-- 스레드 풀 -->
           maxThreads="200"                 <!-- 최대 Worker 스레드 수 -->
           minSpareThreads="10"             <!-- 최소 유휴 스레드 수 -->
           acceptCount="100"                <!-- 스레드 포화 시 소켓 대기 큐 크기 -->
           maxConnections="10000"           <!-- NIO: 최대 동시 연결 수 -->

           <!-- 요청/응답 크기 -->
           maxHttpHeaderSize="8192"         <!-- HTTP 헤더 최대 크기 (bytes) -->
           maxPostSize="2097152"            <!-- POST 최대 크기 (bytes, 기본 2MB, -1: 무제한) -->
           maxParameterCount="1000"         <!-- 쿼리 파라미터 최대 개수 -->

           <!-- 인코딩 -->
           URIEncoding="UTF-8"              <!-- URL 인코딩 -->
           useBodyEncodingForURI="false"    <!-- 요청 body 인코딩을 URI에도 적용 -->

           <!-- 압축 -->
           compression="on"                <!-- off, on, force -->
           compressionMinSize="2048"        <!-- 압축 최소 크기 (bytes) -->
           compressibleMimeType="text/html,text/xml,text/plain,text/css,application/json"
           noCompressionUserAgents=""       <!-- 압축 비활성화 UA 패턴 -->

           <!-- 보안 -->
           server="Apache"                  <!-- Server 헤더 값 (버전 노출 방지) -->

           redirectPort="8443" />
```

### NIO2 (Asynchronous I/O)

```xml
<Connector port="8080"
           protocol="org.apache.coyote.http11.Http11Nio2Protocol"
           connectionTimeout="20000"
           redirectPort="8443" />
```

---

## HTTP/2 설정

HTTP/2는 별도 Connector를 추가하지 않고 UpgradeProtocol로 설정합니다.

```xml
<Connector port="8443"
           protocol="org.apache.coyote.http11.Http11NioProtocol"
           SSLEnabled="true"
           maxThreads="200"
           scheme="https"
           secure="true"
           connectionTimeout="20000">

    <!-- HTTP/2 업그레이드 프로토콜 추가 -->
    <UpgradeProtocol className="org.apache.coyote.http2.Http2Protocol"
                     keepAliveTimeout="30000"
                     maxConcurrentStreams="200" />

    <SSLHostConfig>
        <Certificate certificateKeystoreFile="conf/keystore.jks"
                     certificateKeystorePassword="changeit"
                     type="RSA" />
    </SSLHostConfig>
</Connector>
```

---

## AJP 커넥터

AJP(Apache JServ Protocol)는 Apache HTTP Server 또는 Nginx(mod_proxy_ajp)와 연동할 때 사용합니다.
AJP는 바이너리 프로토콜로 HTTP보다 효율적입니다.

### 보안 주의사항 (CVE-2020-1938 GhostCat)

AJP 커넥터는 외부에 절대 노출하지 말아야 합니다.
반드시 `localhost` 또는 내부 IP에만 바인딩하세요.

```xml
<!-- AJP Connector (Tomcat 10.1 기준) -->
<Connector protocol="AJP/1.3"
           port="8009"
           address="127.0.0.1"         <!-- 반드시 로컬 또는 내부 IP만 -->
           secret="ajp-secret-key"      <!-- Tomcat 9.0.31+ 필수 시크릿 -->
           secretRequired="true"
           redirectPort="8443"
           maxThreads="200"
           connectionTimeout="20000" />
```

```xml
<!-- 보안 강화: 요청 허용 속성 제한 -->
<Connector protocol="AJP/1.3"
           port="8009"
           address="127.0.0.1"
           secret="ajp-secret-key"
           secretRequired="true"
           allowedRequestAttributesPattern="AJP_.*"
           redirectPort="8443" />
```

---

## Executor (공유 스레드 풀)

여러 Connector가 스레드 풀을 공유할 때 사용합니다.

```xml
<Service name="Catalina">

    <!-- 공유 스레드 풀 -->
    <Executor name="tomcatThreadPool"
              namePrefix="catalina-exec-"
              maxThreads="400"
              minSpareThreads="20"
              maxQueueSize="100"
              prestartminSpareThreads="true"
              maxIdleTime="60000" />

    <!-- Connector에서 공유 스레드 풀 참조 -->
    <Connector port="8080"
               protocol="HTTP/1.1"
               executor="tomcatThreadPool"
               connectionTimeout="20000"
               redirectPort="8443" />

    <Connector port="8443"
               protocol="org.apache.coyote.http11.Http11NioProtocol"
               executor="tomcatThreadPool"
               SSLEnabled="true"
               connectionTimeout="20000" />

</Service>
```

---

## I/O 모델 비교

| 모델 | 클래스 | 특징 | 권장 상황 |
|------|--------|------|----------|
| NIO | `Http11NioProtocol` | Java NIO 기반, 비블로킹 I/O | 일반 웹 서비스 (기본값) |
| NIO2 | `Http11Nio2Protocol` | Java NIO.2 (AIO) 기반, 완전 비동기 | 높은 동시성 필요 시 |
| APR | `Http11AprProtocol` | 네이티브 라이브러리 (libtcnative) 사용 | 최고 성능, SSL 오프로드 |

---

## Connector 모니터링

```bash
# Connector 상태 확인 (Manager App)
curl -u admin:password http://localhost:8080/manager/status/all

# JMX로 스레드 풀 상태 확인 (jconsole 또는 jmxterm 사용)
# Catalina:type=ThreadPool,name="http-nio-8080"
# - currentThreadCount: 현재 스레드 수
# - currentThreadsBusy: 처리 중인 스레드 수
# - maxThreads: 최대 스레드 수

# 리스닝 포트 확인
sudo ss -tlnp | grep java
```

---

## 포트 번호 정리

| 포트 | 프로토콜 | 용도 |
|------|---------|------|
| 8005 | TCP | Shutdown 포트 (비활성화 권장) |
| 8080 | HTTP/1.1 | 일반 웹 요청 |
| 8443 | HTTPS | SSL/TLS 웹 요청 |
| 8009 | AJP/1.3 | Apache/Nginx 연동 |

```bash
# 1024 이하 포트 사용 시 (80, 443) iptables 포트 포워딩 사용
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443

# 또는 authbind 사용
sudo apt install authbind
sudo touch /etc/authbind/byport/80
sudo chmod 500 /etc/authbind/byport/80
sudo chown tomcat /etc/authbind/byport/80
```

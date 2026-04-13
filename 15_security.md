# 15. 보안 설정

## 기본 보안 강화

### 1. 불필요한 앱 제거

```bash
# 운영 환경에서 기본 앱 제거
sudo rm -rf /opt/tomcat/webapps/examples
sudo rm -rf /opt/tomcat/webapps/docs
sudo rm -rf /opt/tomcat/webapps/host-manager  # 불필요 시

# ROOT 앱: 커스텀 앱으로 교체하거나 비워두기
sudo rm -rf /opt/tomcat/webapps/ROOT/*
```

### 2. Shutdown 포트 비활성화

```xml
<!-- server.xml -->
<!-- 기본: port="8005", shutdown="SHUTDOWN" -->
<!-- 비활성화 -->
<Server port="-1" shutdown="SHUTDOWN">
```

### 3. Server 헤더 숨기기

```xml
<!-- server.xml의 Connector에 server 속성 추가 -->
<Connector port="8080"
           protocol="HTTP/1.1"
           server="Apache"        <!-- 버전 정보 제거, 임의 문자열로 대체 -->
           ... />
```

### 4. 디렉토리 목록 비활성화

```xml
<!-- conf/web.xml의 DefaultServlet -->
<init-param>
    <param-name>listings</param-name>
    <param-value>false</param-value>
</init-param>
```

---

## tomcat-users.xml 보안

```xml
<!-- conf/tomcat-users.xml -->
<!-- 운영 환경에서는 Manager App 계정을 최소화 -->
<!-- 강력한 패스워드 사용 (digest 사용 권장) -->

<tomcat-users>
  <role rolename="manager-script"/>  <!-- API 접근만 허용 (gui 제외) -->
  <user username="deployer"
        password="강력한랜덤패스워드"
        roles="manager-script"/>
</tomcat-users>
```

```bash
# 패스워드 해시 생성 (SHA-256)
/opt/tomcat/bin/digest.sh -a SHA-256 -s 0 "mypassword"
# 출력: mypassword:해시값

# tomcat-users.xml에서 해시 사용
# passwordDigestEncoding="SHA-256" 속성 추가 필요 (MemoryRealm)
```

### Manager App IP 접근 제한

```xml
<!-- webapps/manager/META-INF/context.xml -->
<Context antiResourceLocking="false" privileged="true">
    <Valve className="org.apache.catalina.valves.RemoteAddrValve"
           allow="127\.\d+\.\d+\.\d+|::1|192\.168\.1\..*" />
</Context>
```

---

## AJP 커넥터 보안 (CVE-2020-1938 GhostCat)

```xml
<!-- server.xml -->
<!-- AJP 미사용 시: 완전히 주석 처리 -->
<!-- <Connector protocol="AJP/1.3" port="8009" ... /> -->

<!-- AJP 사용 시: 반드시 아래 보안 설정 적용 -->
<Connector protocol="AJP/1.3"
           port="8009"
           address="127.0.0.1"         <!-- localhost 또는 내부 IP만 -->
           secret="랜덤시크릿키"         <!-- 반드시 설정 -->
           secretRequired="true"        <!-- 시크릿 없는 연결 거부 -->
           redirectPort="8443" />
```

---

## HTTP 보안 헤더

Tomcat 레벨에서 보안 헤더를 추가하려면 Filter를 사용합니다.

### HttpHeaderSecurityFilter (내장)

```xml
<!-- web.xml -->
<filter>
    <filter-name>httpHeaderSecurity</filter-name>
    <filter-class>org.apache.catalina.filters.HttpHeaderSecurityFilter</filter-class>
    <init-param>
        <!-- HSTS (HTTPS 강제) -->
        <param-name>hstsEnabled</param-name>
        <param-value>true</param-value>
    </init-param>
    <init-param>
        <param-name>hstsMaxAgeSeconds</param-name>
        <param-value>31536000</param-value>  <!-- 1년 -->
    </init-param>
    <init-param>
        <param-name>hstsIncludeSubDomains</param-name>
        <param-value>true</param-value>
    </init-param>
    <init-param>
        <!-- X-Frame-Options: Clickjacking 방지 -->
        <param-name>antiClickJackingEnabled</param-name>
        <param-value>true</param-value>
    </init-param>
    <init-param>
        <param-name>antiClickJackingOption</param-name>
        <param-value>SAMEORIGIN</param-value>  <!-- DENY, SAMEORIGIN, ALLOW-FROM -->
    </init-param>
    <init-param>
        <!-- X-Content-Type-Options: MIME 스니핑 방지 -->
        <param-name>blockContentTypeSniffingEnabled</param-name>
        <param-value>true</param-value>
    </init-param>
    <init-param>
        <!-- X-XSS-Protection -->
        <param-name>xssProtectionEnabled</param-name>
        <param-value>true</param-value>
    </init-param>
</filter>

<filter-mapping>
    <filter-name>httpHeaderSecurity</filter-name>
    <url-pattern>/*</url-pattern>
    <dispatcher>REQUEST</dispatcher>
</filter-mapping>
```

### CSP (Content Security Policy) 헤더 추가

```java
// 커스텀 필터로 추가
public class SecurityHeaderFilter implements Filter {
    @Override
    public void doFilter(ServletRequest req, ServletResponse res, FilterChain chain)
            throws IOException, ServletException {
        HttpServletResponse response = (HttpServletResponse) res;
        response.setHeader("Content-Security-Policy",
            "default-src 'self'; script-src 'self' 'nonce-{random}'; style-src 'self'");
        response.setHeader("Referrer-Policy", "strict-origin-when-cross-origin");
        response.setHeader("Permissions-Policy", "camera=(), microphone=(), geolocation=()");
        chain.doFilter(req, res);
    }
}
```

---

## 요청 크기 제한

```xml
<!-- server.xml Connector -->
<Connector port="8080"
           ...
           maxHttpHeaderSize="8192"     <!-- HTTP 헤더 최대 8KB -->
           maxPostSize="10485760"       <!-- POST 최대 10MB -->
           maxParameterCount="100"      <!-- 파라미터 개수 제한 -->
/>
```

---

## 인증/인가 설정

### LockOutRealm (무차별 대입 공격 방지)

```xml
<!-- server.xml -->
<Engine ...>
    <Realm className="org.apache.catalina.realm.LockOutRealm"
           failureCount="5"           <!-- 실패 허용 횟수 -->
           lockOutTime="300">         <!-- 잠금 시간 (초) -->
        <Realm className="org.apache.catalina.realm.UserDatabaseRealm"
               resourceName="UserDatabase"/>
    </Realm>
</Engine>
```

### JDBCRealm (DB 기반 인증)

```xml
<Realm className="org.apache.catalina.realm.JDBCRealm"
       driverName="com.mysql.cj.jdbc.Driver"
       connectionURL="jdbc:mysql://localhost:3306/security_db"
       connectionName="secuser"
       connectionPassword="secpass"
       userTable="users"
       userNameCol="username"
       userCredCol="password"
       userRoleTable="user_roles"
       roleNameCol="role_name"
       digest="SHA-256" />
```

---

## SELinux 설정 (AL2023)

```bash
# SELinux 상태 확인
getenforce
sestatus

# Tomcat 관련 SELinux 정책 확인
sesearch --allow -s tomcat_t 2>/dev/null | head -20

# Tomcat이 네트워크 포트 바인딩 허용
sudo semanage port -a -t http_port_t -p tcp 8080
sudo semanage port -a -t http_port_t -p tcp 8443

# Tomcat이 네트워크 연결 허용 (DB 연결 등)
sudo setsebool -P tomcat_can_network_connect_db 1

# SELinux 감사 로그 확인
sudo ausearch -c java --raw | audit2allow -M tomcat-local
sudo semodule -i tomcat-local.pp
```

---

## 보안 점검 체크리스트

```
서버 설정
  [ ] Shutdown 포트 비활성화 (port="-1")
  [ ] Server 헤더 버전 정보 제거
  [ ] AJP 미사용 시 비활성화 또는 localhost 바인딩 + secret 설정
  [ ] HTTPS 사용 및 HTTP → HTTPS 리다이렉트

불필요한 앱 제거
  [ ] examples 앱 제거
  [ ] docs 앱 제거
  [ ] HOST Manager 불필요 시 제거

Manager App
  [ ] IP 접근 제한 설정
  [ ] 강력한 패스워드 사용
  [ ] manager-gui 대신 manager-script 역할만 부여

웹 앱 보안
  [ ] 디렉토리 목록 비활성화 (listings=false)
  [ ] 보안 헤더 추가 (X-Frame-Options, HSTS 등)
  [ ] POST 크기 제한 설정
  [ ] 세션 쿠키 HttpOnly, Secure 플래그

파일 권한
  [ ] conf/ 디렉토리 권한: 750 (tomcat 전용)
  [ ] tomcat-users.xml 권한: 640
  [ ] 로그 디렉토리 권한: 750
```

# 10. 세션 관리

## 세션 개요

HTTP는 상태 없는(Stateless) 프로토콜입니다.
Tomcat은 세션(HttpSession)을 통해 요청 간 상태를 유지합니다.

### 세션 식별 방법

| 방법 | 설명 | 기본값 |
|------|------|--------|
| **Cookie** | `JSESSIONID` 쿠키로 세션 ID 전달 | 권장 (기본) |
| **URL Rewriting** | URL에 `;jsessionid=xxx` 추가 | 쿠키 비활성 환경에서 사용 |
| **SSL Session ID** | SSL/TLS 세션 ID 활용 | HTTPS 전용 |

```xml
<!-- web.xml: 세션 추적 방식 설정 -->
<session-config>
    <session-timeout>30</session-timeout>
    <cookie-config>
        <http-only>true</http-only>
        <secure>true</secure>  <!-- HTTPS에서만 전송 -->
    </cookie-config>
    <tracking-mode>COOKIE</tracking-mode>  <!-- COOKIE, URL, SSL 또는 조합 -->
</session-config>
```

---

## Session Manager 종류

### StandardManager (기본)

메모리에 세션 저장. 서버 재시작 시 세션 유실(graceful shutdown 시 파일 저장).

```xml
<Context>
    <Manager className="org.apache.catalina.session.StandardManager"
             maxActiveSessions="-1"      <!-- 최대 세션 수 (-1: 무제한) -->
             sessionIdLength="32"        <!-- 세션 ID 길이 -->
             pathname="SESSIONS.ser" />  <!-- 재시작 시 저장 파일 (빈 문자열: 저장 안 함) -->
</Context>
```

### PersistentManager

세션을 파일 또는 DB에 저장. 재시작 후에도 세션 유지.

```xml
<Context>
    <Manager className="org.apache.catalina.session.PersistentManager"
             saveOnRestart="true"         <!-- 재시작 시 세션 저장 -->
             maxIdleBackup="60"           <!-- 60초 유휴 후 스토어에 백업 -->
             maxIdleSwap="600"            <!-- 600초 후 메모리에서 제거 -->
             minIdleSwap="60">

        <!-- 파일 기반 저장소 -->
        <Store className="org.apache.catalina.session.FileStore"
               directory="${catalina.base}/work/sessions" />
    </Manager>
</Context>
```

### DeltaManager (클러스터링용)

클러스터 내 모든 노드에 세션 변경분(Delta)을 복제합니다.
자세한 내용은 16_clustering.md 참조.

### BackupManager (클러스터링용)

세션을 하나의 백업 노드에만 복제합니다. DeltaManager보다 네트워크 트래픽이 적습니다.

---

## 세션 타임아웃

```xml
<!-- web.xml (분 단위) -->
<session-config>
    <session-timeout>30</session-timeout>  <!-- 30분 -->
</session-config>
```

```java
// 코드에서 설정
HttpSession session = request.getSession();
session.setMaxInactiveInterval(1800);  // 초 단위 (1800초 = 30분)
session.setMaxInactiveInterval(-1);    // 무제한
```

```bash
# Manager App으로 세션 정보 확인
curl -u admin:password \
  "http://localhost:8080/manager/text/sessions?path=/myapp"
```

---

## 세션 쿠키 설정

### context.xml에서 설정

```xml
<Context sessionCookieName="MYSESSID"
         sessionCookiePath="/"
         sessionCookieDomain=".example.com"
         sessionCookieHttpOnly="true"
         sessionCookieSecure="true"
         useHttpOnly="true">
</Context>
```

### web.xml에서 설정 (Servlet 3.0+)

```xml
<session-config>
    <cookie-config>
        <name>MYSESSID</name>
        <path>/</path>
        <domain>.example.com</domain>
        <http-only>true</http-only>
        <secure>true</secure>
        <max-age>1800</max-age>  <!-- 쿠키 만료 시간 (초) -->
    </cookie-config>
</session-config>
```

---

## 세션 보안

### 세션 고정 공격(Session Fixation) 방지

```java
// 로그인 성공 후 새 세션 발급 (반드시 구현)
HttpSession oldSession = request.getSession(false);
if (oldSession != null) {
    oldSession.invalidate();  // 기존 세션 무효화
}
HttpSession newSession = request.getSession(true);  // 새 세션 생성
newSession.setAttribute("user", user);
```

### 세션 ID 재생성

```java
// 권한 레벨 변경 시 세션 ID 갱신 (Servlet 3.1+)
request.changeSessionId();
```

### CSRF 토큰

```java
// 세션에 CSRF 토큰 저장
String csrfToken = UUID.randomUUID().toString();
session.setAttribute("csrfToken", csrfToken);

// 폼 요청 시 검증
String requestToken = request.getParameter("_csrf");
String sessionToken = (String) session.getAttribute("csrfToken");
if (!sessionToken.equals(requestToken)) {
    response.sendError(403, "CSRF token mismatch");
}
```

---

## 세션 직렬화

세션에 저장되는 객체는 `java.io.Serializable`을 구현해야 합니다.
(PersistentManager 또는 클러스터링 사용 시 필수)

```java
// Serializable 구현 필수
public class UserInfo implements Serializable {
    private static final long serialVersionUID = 1L;
    private String username;
    private String role;
    // getters, setters...
}

// 세션에 저장
session.setAttribute("userInfo", new UserInfo("alice", "admin"));
```

---

## 세션 모니터링

```bash
# Manager App으로 활성 세션 수 확인
curl -u admin:password \
  "http://localhost:8080/manager/text/sessions?path=/myapp"
# Default maximum session inactive interval 30 minutes
# Inactive for <10 minutes: 5 sessions
# Inactive for 10-20 minutes: 2 sessions

# JMX로 세션 상태 확인
# MBean: Catalina:type=Manager,context=/myapp,host=localhost
# - activeSessions: 현재 활성 세션 수
# - maxActive: 최대 동시 세션 수
# - sessionCounter: 총 생성된 세션 수
# - expiredSessions: 만료된 세션 수
# - rejectedSessions: 거부된 세션 수 (maxActiveSessions 초과)
```

---

## Redis를 이용한 세션 공유 (외부 라이브러리)

단순 클러스터링이 아닌 외부 Redis에 세션을 저장하려면
`tomcat-redis-session-manager` 등 서드파티 라이브러리를 사용합니다.

```xml
<!-- context.xml -->
<Context>
    <Valve className="com.orangefunction.tomcat.redissessions.RedisSessionHandlerValve" />
    <Manager className="com.orangefunction.tomcat.redissessions.RedisSessionManager"
             host="redis-host"
             port="6379"
             database="0"
             maxInactiveInterval="1800"
             sessionPersistPolicies="ALWAYS_SAVE_AFTER_REQUEST" />
</Context>
```

```bash
# 필요 JAR: lib/ 디렉토리에 배치
# tomcat-redis-session-manager-*.jar
# jedis-*.jar
# commons-pool2-*.jar
```

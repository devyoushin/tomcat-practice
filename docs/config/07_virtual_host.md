# 07. 가상 호스트 (Virtual Host)

## 개요

Tomcat의 가상 호스트는 하나의 Tomcat 인스턴스에서 여러 도메인을 처리할 수 있게 해줍니다.
`server.xml`의 `<Host>` 요소로 설정합니다.

---

## 기본 가상 호스트 설정

```xml
<!-- server.xml -->
<Engine name="Catalina" defaultHost="www.example.com">

    <!-- 첫 번째 가상 호스트 -->
    <Host name="www.example.com"
          appBase="/opt/apps/example"
          unpackWARs="true"
          autoDeploy="false">

        <Alias>example.com</Alias>  <!-- 도메인 별칭 -->

        <Valve className="org.apache.catalina.valves.AccessLogValve"
               directory="logs"
               prefix="example_access_log"
               suffix=".txt"
               pattern="%h %l %u %t &quot;%r&quot; %s %b %D" />
    </Host>

    <!-- 두 번째 가상 호스트 -->
    <Host name="api.example.com"
          appBase="/opt/apps/api"
          unpackWARs="true"
          autoDeploy="false">

        <Valve className="org.apache.catalina.valves.AccessLogValve"
               directory="logs"
               prefix="api_access_log"
               suffix=".txt"
               pattern="%h %l %u %t &quot;%r&quot; %s %b %D" />
    </Host>

    <!-- 관리용 호스트 -->
    <Host name="admin.example.com"
          appBase="/opt/apps/admin"
          unpackWARs="true"
          autoDeploy="false">

        <!-- IP 접근 제한 (내부망만 허용) -->
        <Valve className="org.apache.catalina.valves.RemoteAddrValve"
               allow="10\..*|192\.168\..*|127\..*" />
    </Host>

</Engine>
```

---

## Host 속성 상세

| 속성 | 기본값 | 설명 |
|------|--------|------|
| `name` | - | 가상 호스트 이름 (HTTP Host 헤더와 매핑) |
| `appBase` | `webapps` | 웹 앱 기본 디렉토리 |
| `unpackWARs` | `true` | WAR 파일 자동 압축 해제 |
| `autoDeploy` | `true` | 런타임 중 새 앱 자동 배포 감지 |
| `deployOnStartup` | `true` | 시작 시 appBase 내 앱 자동 배포 |
| `deployXML` | `true` | WAR/앱의 META-INF/context.xml 처리 여부 |
| `copyXML` | `false` | META-INF/context.xml을 conf/로 복사 여부 |
| `xmlBase` | - | Context XML 파일 검색 기준 디렉토리 |
| `workDir` | - | JSP 컴파일 결과 저장 디렉토리 |

---

## 요청 라우팅 로직

```
HTTP 요청 도착
Host: www.example.com

1. Engine의 Host 목록에서 name="www.example.com" 검색
2. 없으면 Alias 검색
3. 없으면 defaultHost로 라우팅
```

```bash
# 테스트: 특정 Host 헤더로 요청
curl -H "Host: www.example.com" http://localhost:8080/
curl -H "Host: api.example.com" http://localhost:8080/api/health
```

---

## 앱별 Context 설정 파일

각 가상 호스트는 `conf/Catalina/<호스트명>/` 디렉토리에서 개별 Context 설정을 가집니다.

```bash
# 디렉토리 구조
/opt/tomcat/conf/
└── Catalina/
    ├── localhost/
    │   ├── ROOT.xml         ← localhost 기본 앱
    │   └── myapp.xml        ← localhost의 myapp
    ├── www.example.com/
    │   ├── ROOT.xml         ← www.example.com 기본 앱
    │   └── shop.xml         ← www.example.com의 /shop
    └── api.example.com/
        └── ROOT.xml         ← api.example.com 기본 앱
```

```xml
<!-- conf/Catalina/www.example.com/ROOT.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<Context path=""
         docBase="/opt/apps/example/ROOT"
         reloadable="false">

    <Resource name="jdbc/shopdb"
              auth="Container"
              type="javax.sql.DataSource"
              .../>
</Context>
```

```xml
<!-- conf/Catalina/www.example.com/shop.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<Context path="/shop"
         docBase="/opt/apps/shop"
         reloadable="false">
</Context>
```

---

## 가상 호스트별 로그 분리

```xml
<!-- server.xml -->
<Host name="www.example.com" appBase="/opt/apps/example" ...>
    <Valve className="org.apache.catalina.valves.AccessLogValve"
           directory="${catalina.base}/logs"
           prefix="example_access"
           suffix=".log"
           pattern="%h %t &quot;%r&quot; %s %b %D"
           fileDateFormat="yyyy-MM-dd"
           rotatable="true" />
</Host>

<Host name="api.example.com" appBase="/opt/apps/api" ...>
    <Valve className="org.apache.catalina.valves.AccessLogValve"
           directory="${catalina.base}/logs"
           prefix="api_access"
           suffix=".log"
           pattern="%h %t &quot;%r&quot; %s %b %D"
           fileDateFormat="yyyy-MM-dd"
           rotatable="true" />
</Host>
```

---

## Host Manager App을 통한 동적 관리

```bash
# Host Manager App 활성화 (conf/tomcat-users.xml)
# admin-gui 역할 필요

# 새 가상 호스트 추가 (REST API)
curl -u admin:password \
  "http://localhost:8080/host-manager/text/add?name=new.example.com&aliases=&appBase=webapps2&manager=false"

# 호스트 제거
curl -u admin:password \
  "http://localhost:8080/host-manager/text/remove?name=new.example.com"

# 호스트 목록 조회
curl -u admin:password \
  "http://localhost:8080/host-manager/text/list"
```

---

## 실전 예시: 멀티 테넌트 구성

```xml
<!-- server.xml -->
<Engine name="Catalina" defaultHost="default.example.com">

    <!-- 고객 A 전용 -->
    <Host name="a.example.com"
          appBase="/opt/tenants/a"
          unpackWARs="true"
          autoDeploy="false">

        <Alias>customer-a.example.com</Alias>

        <!-- 고객 A용 DB 접근 제한 등은 context.xml에서 설정 -->
        <Valve className="org.apache.catalina.valves.AccessLogValve"
               prefix="tenant_a_access" suffix=".log"
               directory="${catalina.base}/logs"
               pattern="%h %t &quot;%r&quot; %s %b" />
    </Host>

    <!-- 고객 B 전용 -->
    <Host name="b.example.com"
          appBase="/opt/tenants/b"
          unpackWARs="true"
          autoDeploy="false">

        <Valve className="org.apache.catalina.valves.AccessLogValve"
               prefix="tenant_b_access" suffix=".log"
               directory="${catalina.base}/logs"
               pattern="%h %t &quot;%r&quot; %s %b" />
    </Host>

    <!-- 기본 호스트 (알 수 없는 도메인) -->
    <Host name="default.example.com"
          appBase="/opt/apps/default"
          unpackWARs="true"
          autoDeploy="false">
    </Host>

</Engine>
```

---

## 주의사항

1. **autoDeploy="false" 권장 (운영 환경)**
   - `true`이면 Tomcat이 `appBase` 디렉토리를 주기적으로 스캔 → 부하 발생 가능
   - 배포는 명시적으로 Manager App이나 Context XML 파일로 관리

2. **deployXML 보안**
   - WAR 내부의 `META-INF/context.xml`을 허용하면 임의의 Context 설정 가능
   - 보안이 중요한 환경에서는 `deployXML="false"` 설정

3. **Host 이름 대소문자**
   - HTTP Host 헤더와 `name` 속성은 대소문자를 구분하지 않음
   - 내부적으로 소문자로 정규화됨

# 19. 실전 예제

## 예제 1: Spring Boot WAR 배포

Spring Boot 앱을 내장 Tomcat이 아닌 외부 Tomcat에 배포합니다.

### pom.xml 수정

```xml
<!-- pom.xml -->
<packaging>war</packaging>

<dependencies>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    <!-- 내장 Tomcat 제외 -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-tomcat</artifactId>
        <scope>provided</scope>
    </dependency>
</dependencies>

<build>
    <finalName>myapp</finalName>
    <plugins>
        <plugin>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-maven-plugin</artifactId>
        </plugin>
    </plugins>
</build>
```

### SpringBootServletInitializer 상속

```java
// src/main/java/com/example/MyApplication.java
@SpringBootApplication
public class MyApplication extends SpringBootServletInitializer {

    public static void main(String[] args) {
        SpringApplication.run(MyApplication.class, args);
    }

    @Override
    protected SpringApplicationBuilder configure(SpringApplicationBuilder builder) {
        return builder.sources(MyApplication.class);
    }
}
```

### 빌드 및 배포

```bash
# WAR 빌드
mvn clean package -DskipTests

# Tomcat에 배포
sudo cp target/myapp.war /opt/tomcat/webapps/
sudo chown tomcat:tomcat /opt/tomcat/webapps/myapp.war

# 배포 확인 (자동 압축 해제)
ls /opt/tomcat/webapps/myapp/

# 접근 테스트
curl http://localhost:8080/myapp/api/health
```

---

## 예제 2: 다중 환경 배포 (Dev/Staging/Prod)

### Context XML으로 환경별 설정 분리

```bash
# 디렉토리 구조
/opt/tomcat/conf/Catalina/localhost/
├── myapp.xml      ← 환경별 Context 설정
```

```xml
<!-- prod: /opt/tomcat/conf/Catalina/localhost/myapp.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<Context path="/myapp" docBase="/opt/tomcat/webapps/myapp" reloadable="false">

    <!-- 운영 DB -->
    <Resource name="jdbc/mydb"
              auth="Container"
              type="javax.sql.DataSource"
              factory="org.apache.tomcat.jdbc.pool.DataSourceFactory"
              driverClassName="com.mysql.cj.jdbc.Driver"
              url="jdbc:mysql://prod-db:3306/mydb?useSSL=true"
              username="prod_user"
              password="prod_password"
              maxTotal="100"
              maxIdle="30"
              minIdle="10" />

    <!-- 환경 변수 -->
    <Environment name="spring.profiles.active"
                 value="production"
                 type="java.lang.String"
                 override="false" />
</Context>
```

---

## 예제 3: 무중단 배포 (Blue-Green)

```bash
#!/bin/bash
# deploy.sh

APP_NAME="myapp"
NEW_WAR="/tmp/${APP_NAME}.war"
TOMCAT_WEBAPPS="/opt/tomcat/webapps"
MANAGER_URL="http://localhost:8080/manager/text"
AUTH="admin:password"

# 1. 새 WAR 업로드
echo ">>> WAR 파일 복사"
sudo cp ${NEW_WAR} ${TOMCAT_WEBAPPS}/${APP_NAME}-new.war
sudo chown tomcat:tomcat ${TOMCAT_WEBAPPS}/${APP_NAME}-new.war

# 2. 새 앱 배포
echo ">>> 새 버전 배포"
curl -u ${AUTH} "${MANAGER_URL}/deploy?path=/${APP_NAME}-new&war=file:${TOMCAT_WEBAPPS}/${APP_NAME}-new.war"

# 3. 헬스체크
echo ">>> 헬스체크"
for i in {1..10}; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/${APP_NAME}-new/actuator/health)
    if [ "$STATUS" == "200" ]; then
        echo "새 버전 정상"
        break
    fi
    sleep 3
done

# 4. 기존 앱 중지, 새 앱을 기존 경로로 전환
echo ">>> 앱 전환"
curl -u ${AUTH} "${MANAGER_URL}/undeploy?path=/${APP_NAME}"
curl -u ${AUTH} "${MANAGER_URL}/undeploy?path=/${APP_NAME}-new"

sudo mv ${TOMCAT_WEBAPPS}/${APP_NAME}-new.war ${TOMCAT_WEBAPPS}/${APP_NAME}.war
curl -u ${AUTH} "${MANAGER_URL}/deploy?path=/${APP_NAME}&war=file:${TOMCAT_WEBAPPS}/${APP_NAME}.war"

echo ">>> 배포 완료"
```

---

## 예제 4: Nginx + Tomcat 클러스터 (2대)

### 아키텍처

```
클라이언트
    │
[Nginx :80/443]  ← SSL 종단, 정적 파일, 로드밸런싱
    │
    ├── [Tomcat-1 :8080]  (10.0.1.10)
    └── [Tomcat-2 :8080]  (10.0.1.11)
           │
    [MySQL DB :3306]
```

### Nginx 설정

```nginx
upstream tomcats {
    hash $cookie_JSESSIONID consistent;  # 세션 스티키

    server 10.0.1.10:8080 max_fails=3 fail_timeout=30s;
    server 10.0.1.11:8080 max_fails=3 fail_timeout=30s;

    keepalive 32;
}

server {
    listen 443 ssl http2;
    server_name app.example.com;

    ssl_certificate     /etc/letsencrypt/live/app.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/app.example.com/privkey.pem;

    # 정적 파일 직접 서빙
    location ~* \.(css|js|jpg|png|gif|ico|woff2)$ {
        root /opt/static;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # API 프록시
    location / {
        proxy_pass       http://tomcats;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 헬스체크 실패 시 다음 서버 시도
        proxy_next_upstream error timeout http_502 http_503;
        proxy_next_upstream_tries 2;

        proxy_read_timeout 60s;
    }

    # 헬스체크 엔드포인트 (로그 제외)
    location /actuator/health {
        proxy_pass http://tomcats;
        access_log off;
    }
}
```

### Tomcat 각 노드 server.xml 핵심 설정

```xml
<!-- Node 1: jvmRoute="worker1" -->
<Engine name="Catalina" defaultHost="localhost" jvmRoute="worker1">
    <Host name="localhost" appBase="webapps" unpackWARs="true" autoDeploy="false">
        <Valve className="org.apache.catalina.valves.RemoteIpValve"
               remoteIpHeader="X-Forwarded-For"
               protocolHeader="X-Forwarded-Proto" />
    </Host>
</Engine>

<!-- Node 2: jvmRoute="worker2" -->
<Engine name="Catalina" defaultHost="localhost" jvmRoute="worker2">
    ...
</Engine>
```

---

## 예제 5: 접근 로그 JSON 포맷

```xml
<!-- server.xml: JSON 형식 접근 로그 -->
<Valve className="org.apache.catalina.valves.AccessLogValve"
       directory="${catalina.base}/logs"
       prefix="access"
       suffix=".json"
       fileDateFormat="yyyy-MM-dd"
       pattern="{&quot;time&quot;:&quot;%{yyyy-MM-dd'T'HH:mm:ss.SSS'Z'}t&quot;,&quot;remote_ip&quot;:&quot;%a&quot;,&quot;method&quot;:&quot;%m&quot;,&quot;uri&quot;:&quot;%U%q&quot;,&quot;status&quot;:%s,&quot;bytes&quot;:%b,&quot;duration_ms&quot;:%D,&quot;user_agent&quot;:&quot;%{User-Agent}i&quot;}"
       rotatable="true" />
```

---

## 예제 6: 커스텀 에러 페이지 (전역)

```xml
<!-- conf/web.xml 또는 앱별 web.xml -->
<error-page>
    <error-code>404</error-code>
    <location>/error/404.html</location>
</error-page>
<error-page>
    <error-code>500</error-code>
    <location>/error/500.html</location>
</error-page>
<error-page>
    <exception-type>java.lang.Exception</exception-type>
    <location>/error/general.html</location>
</error-page>
```

```java
// 에러 페이지에서 오류 정보 표시
@WebServlet("/error/500")
public class ErrorServlet extends HttpServlet {
    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res)
            throws ServletException, IOException {
        Integer statusCode = (Integer) req.getAttribute("jakarta.servlet.error.status_code");
        Throwable throwable = (Throwable) req.getAttribute("jakarta.servlet.error.exception");
        String requestUri = (String) req.getAttribute("jakarta.servlet.error.request_uri");

        // 로그 기록
        log.error("Error {} at {}", statusCode, requestUri, throwable);

        res.setContentType("text/html;charset=UTF-8");
        res.getWriter().write("<h1>Internal Server Error</h1>");
    }
}
```

---

## 예제 7: WAR 배포 CI/CD (GitHub Actions)

```yaml
# .github/workflows/deploy.yml
name: Deploy to Tomcat

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up JDK 17
        uses: actions/setup-java@v3
        with:
          java-version: '17'
          distribution: 'corretto'

      - name: Build WAR
        run: mvn clean package -DskipTests

      - name: Deploy to Tomcat
        run: |
          curl -u "${{ secrets.TOMCAT_USER }}:${{ secrets.TOMCAT_PASSWORD }}" \
            --upload-file target/myapp.war \
            "http://${{ secrets.TOMCAT_HOST }}:8080/manager/text/deploy?path=/myapp&update=true"
```

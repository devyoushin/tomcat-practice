# 05. web.xml 설정

## web.xml 종류

Tomcat에서 `web.xml`은 두 군데에 존재합니다.

| 위치 | 범위 | 설명 |
|------|------|------|
| `conf/web.xml` | 전역 | Tomcat에 배포된 모든 웹 앱에 적용 |
| `webapps/myapp/WEB-INF/web.xml` | 앱별 | 해당 웹 앱에만 적용 (전역을 오버라이드) |

---

## 전역 web.xml 핵심 내용

### DefaultServlet (정적 파일 서빙)

```xml
<!-- conf/web.xml -->
<servlet>
    <servlet-name>default</servlet-name>
    <servlet-class>org.apache.catalina.servlets.DefaultServlet</servlet-class>
    <init-param>
        <param-name>debug</param-name>
        <param-value>0</param-value>
    </init-param>
    <init-param>
        <!-- 디렉토리 목록 표시 여부 (보안상 false 권장) -->
        <param-name>listings</param-name>
        <param-value>false</param-value>
    </init-param>
    <init-param>
        <!-- 정적 파일 읽기 버퍼 크기 -->
        <param-name>input</param-name>
        <param-value>2048</param-value>
    </init-param>
    <init-param>
        <!-- 정적 파일 출력 버퍼 크기 -->
        <param-name>output</param-name>
        <param-value>2048</param-value>
    </init-param>
    <load-on-startup>1</load-on-startup>
</servlet>

<!-- 매핑: URL이 다른 서블릿과 매칭되지 않을 때 DefaultServlet이 처리 -->
<servlet-mapping>
    <servlet-name>default</servlet-name>
    <url-pattern>/</url-pattern>
</servlet-mapping>
```

### JspServlet (JSP 처리)

```xml
<servlet>
    <servlet-name>jsp</servlet-name>
    <servlet-class>org.apache.jasper.servlet.JspServlet</servlet-class>
    <init-param>
        <!-- JSP 변경 감지 주기 (-1: 비활성화, 운영 환경 권장) -->
        <param-name>checkInterval</param-name>
        <param-value>0</param-value>
    </init-param>
    <init-param>
        <!-- JSP 컴파일 시 디버그 정보 포함 여부 -->
        <param-name>classdebuginfo</param-name>
        <param-value>false</param-value>
    </init-param>
    <init-param>
        <!-- 개발 모드: true면 JSP 변경 시 자동 재컴파일 -->
        <param-name>development</param-name>
        <param-value>false</param-value>  <!-- 운영: false -->
    </init-param>
    <load-on-startup>3</load-on-startup>
</servlet>

<servlet-mapping>
    <servlet-name>jsp</servlet-name>
    <url-pattern>*.jsp</url-pattern>
</servlet-mapping>

<servlet-mapping>
    <servlet-name>jsp</servlet-name>
    <url-pattern>*.jspx</url-pattern>
</servlet-mapping>
```

---

## 앱별 web.xml 설정

### 기본 구조

```xml
<?xml version="1.0" encoding="UTF-8"?>
<web-app xmlns="https://jakarta.ee/xml/ns/jakartaee"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="https://jakarta.ee/xml/ns/jakartaee
                             https://jakarta.ee/xml/ns/jakartaee/web-app_6_0.xsd"
         version="6.0">

    <display-name>My Application</display-name>
    <description>My Web Application</description>

</web-app>
```

> Tomcat 9: `javax.servlet` / Tomcat 10+: `jakarta.servlet` 네임스페이스 사용

### 서블릿 등록

```xml
<!-- 서블릿 클래스 등록 -->
<servlet>
    <servlet-name>HelloServlet</servlet-name>
    <servlet-class>com.example.HelloServlet</servlet-class>
    <init-param>
        <param-name>greeting</param-name>
        <param-value>Hello, World!</param-value>
    </init-param>
    <!-- 양수: 시작 시 즉시 초기화, 숫자가 낮을수록 먼저 초기화 -->
    <!-- 음수: 첫 요청 시 지연 초기화 (기본) -->
    <load-on-startup>1</load-on-startup>
</servlet>

<!-- URL 매핑 -->
<servlet-mapping>
    <servlet-name>HelloServlet</servlet-name>
    <url-pattern>/hello</url-pattern>
</servlet-mapping>

<!-- 와일드카드 매핑 -->
<servlet-mapping>
    <servlet-name>HelloServlet</servlet-name>
    <url-pattern>/api/*</url-pattern>
</servlet-mapping>
```

### 필터(Filter) 등록

```xml
<!-- 인코딩 필터 -->
<filter>
    <filter-name>encodingFilter</filter-name>
    <filter-class>org.springframework.web.filter.CharacterEncodingFilter</filter-class>
    <init-param>
        <param-name>encoding</param-name>
        <param-value>UTF-8</param-value>
    </init-param>
    <init-param>
        <param-name>forceEncoding</param-name>
        <param-value>true</param-value>
    </init-param>
</filter>

<filter-mapping>
    <filter-name>encodingFilter</filter-name>
    <url-pattern>/*</url-pattern>
</filter-mapping>
```

### 리스너(Listener) 등록

```xml
<!-- 서블릿 컨텍스트 리스너 (애플리케이션 시작/종료 시 실행) -->
<listener>
    <listener-class>com.example.AppContextListener</listener-class>
</listener>

<!-- Spring ContextLoaderListener 예시 -->
<listener>
    <listener-class>org.springframework.web.context.ContextLoaderListener</listener-class>
</listener>
```

### 세션 설정

```xml
<session-config>
    <!-- 세션 타임아웃 (분 단위, 0 또는 음수: 무제한) -->
    <session-timeout>30</session-timeout>

    <cookie-config>
        <!-- 세션 쿠키 이름 -->
        <name>JSESSIONID</name>
        <!-- JavaScript에서 쿠키 접근 불가 (XSS 방지) -->
        <http-only>true</http-only>
        <!-- HTTPS에서만 전송 -->
        <secure>true</secure>
        <!-- 쿠키 적용 경로 -->
        <path>/</path>
    </cookie-config>

    <!-- 세션 추적 방식 -->
    <tracking-mode>COOKIE</tracking-mode>  <!-- COOKIE, URL, SSL -->
</session-config>
```

### Welcome 파일 설정

```xml
<welcome-file-list>
    <welcome-file>index.html</welcome-file>
    <welcome-file>index.jsp</welcome-file>
    <welcome-file>index.htm</welcome-file>
</welcome-file-list>
```

### 에러 페이지 설정

```xml
<!-- HTTP 상태 코드별 에러 페이지 -->
<error-page>
    <error-code>404</error-code>
    <location>/error/404.html</location>
</error-page>

<error-page>
    <error-code>500</error-code>
    <location>/error/500.html</location>
</error-page>

<!-- Java 예외 타입별 에러 페이지 -->
<error-page>
    <exception-type>java.lang.NullPointerException</exception-type>
    <location>/error/general.html</location>
</error-page>
```

### MIME 타입 추가

```xml
<!-- 기본 MIME 타입에 추가 -->
<mime-mapping>
    <extension>json</extension>
    <mime-type>application/json</mime-type>
</mime-mapping>

<mime-mapping>
    <extension>woff2</extension>
    <mime-type>font/woff2</mime-type>
</mime-mapping>
```

### 보안 제약 설정

```xml
<!-- URL 접근 제어 -->
<security-constraint>
    <web-resource-collection>
        <web-resource-name>Admin Area</web-resource-name>
        <url-pattern>/admin/*</url-pattern>
        <http-method>GET</http-method>
        <http-method>POST</http-method>
    </web-resource-collection>
    <auth-constraint>
        <role-name>admin</role-name>
    </auth-constraint>
    <user-data-constraint>
        <!-- NONE, INTEGRAL, CONFIDENTIAL -->
        <transport-guarantee>CONFIDENTIAL</transport-guarantee>
    </user-data-constraint>
</security-constraint>

<!-- 로그인 방식 설정 -->
<login-config>
    <!-- BASIC, DIGEST, FORM, CLIENT-CERT -->
    <auth-method>FORM</auth-method>
    <realm-name>My Application</realm-name>
    <form-login-config>
        <form-login-page>/login.jsp</form-login-page>
        <form-error-page>/login-error.jsp</form-error-page>
    </form-login-config>
</login-config>

<!-- 역할 정의 -->
<security-role>
    <role-name>admin</role-name>
</security-role>
```

### 컨텍스트 파라미터 (전역 설정값)

```xml
<!-- 앱 전체에서 사용할 파라미터 -->
<context-param>
    <param-name>spring.profiles.active</param-name>
    <param-value>production</param-value>
</context-param>

<context-param>
    <param-name>contextConfigLocation</param-name>
    <param-value>/WEB-INF/spring/applicationContext.xml</param-value>
</context-param>
```

### JNDI 리소스 참조

```xml
<!-- DB 커넥션 풀 참조 (실제 설정은 context.xml에서) -->
<resource-ref>
    <description>DB Connection Pool</description>
    <res-ref-name>jdbc/mydb</res-ref-name>
    <res-type>javax.sql.DataSource</res-type>
    <res-auth>Container</res-auth>
</resource-ref>
```

---

## URL 패턴 매칭 규칙

서블릿 매핑 URL 패턴의 우선순위 (높은 순):

```
1. 완전 일치 (Exact Match)       /myapp/users/list
2. 경로 패턴 (Path Mapping)      /myapp/users/*
3. 확장자 패턴 (Extension)       *.do
4. 기본 서블릿 (Default)         /
```

```xml
<!-- 우선순위 예시 -->
<!-- /hello 요청: HelloServlet (완전 일치) -->
<servlet-mapping>
    <servlet-name>HelloServlet</servlet-name>
    <url-pattern>/hello</url-pattern>
</servlet-mapping>

<!-- /api/users, /api/orders 등: ApiServlet (경로 패턴) -->
<servlet-mapping>
    <servlet-name>ApiServlet</servlet-name>
    <url-pattern>/api/*</url-pattern>
</servlet-mapping>

<!-- 나머지 모든 요청: DefaultServlet -->
<servlet-mapping>
    <servlet-name>default</servlet-name>
    <url-pattern>/</url-pattern>
</servlet-mapping>
```

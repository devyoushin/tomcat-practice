# 17. Nginx / Apache HTTP Server 연동

## 연동 방식 비교

| 방식 | 프로토콜 | 설명 |
|------|---------|------|
| **Nginx + HTTP Proxy** | HTTP/1.1 | Nginx → Tomcat HTTP, 가장 간단 |
| **Nginx + AJP** | AJP/1.3 | ngx_http_ajp_module 필요 (비표준) |
| **Apache + mod_proxy** | HTTP/1.1 | Apache HTTP Server 역방향 프록시 |
| **Apache + mod_jk** | AJP/1.3 | 전통적 방식, 로드밸런싱 기능 포함 |
| **Apache + mod_proxy_ajp** | AJP/1.3 | 표준 Apache AJP 프록시 |

> **권장 구성**: Nginx + HTTP Reverse Proxy (간단, 높은 성능, 표준적)

---

## Nginx + HTTP Reverse Proxy (권장)

### Tomcat 설정

```xml
<!-- server.xml: Tomcat은 localhost에서만 HTTP 서비스 -->
<Connector port="8080"
           protocol="HTTP/1.1"
           address="127.0.0.1"    <!-- 외부 직접 접근 차단 -->
           connectionTimeout="20000"
           redirectPort="8443" />
```

```xml
<!-- server.xml: RemoteIpValve로 실제 클라이언트 IP 처리 -->
<Host name="localhost" ...>
    <Valve className="org.apache.catalina.valves.RemoteIpValve"
           remoteIpHeader="X-Forwarded-For"
           protocolHeader="X-Forwarded-Proto"
           internalProxies="127\.0\.0\.1|::1" />
</Host>
```

### Nginx 설정

```nginx
# /etc/nginx/conf.d/tomcat.conf

upstream tomcat {
    server 127.0.0.1:8080;
    keepalive 32;  # Nginx ↔ Tomcat Keep-Alive 유지
}

server {
    listen 80;
    server_name www.example.com;

    # HTTP → HTTPS 리다이렉트
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name www.example.com;

    # SSL 설정
    ssl_certificate     /etc/letsencrypt/live/www.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/www.example.com/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    # 정적 파일은 Nginx가 직접 서빙
    location ~* \.(html|css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot)$ {
        root /opt/apps/myapp/static;
        expires 30d;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # 동적 요청은 Tomcat으로 전달
    location / {
        proxy_pass http://tomcat;

        # 실제 클라이언트 IP 전달
        proxy_set_header Host               $host;
        proxy_set_header X-Real-IP          $remote_addr;
        proxy_set_header X-Forwarded-For    $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto  $scheme;
        proxy_set_header X-Forwarded-Port   $server_port;

        # 타임아웃 설정
        proxy_connect_timeout  10s;
        proxy_read_timeout     60s;
        proxy_send_timeout     60s;

        # 버퍼 설정
        proxy_buffering         on;
        proxy_buffer_size       4k;
        proxy_buffers           8 4k;
        proxy_busy_buffers_size 8k;

        # Keep-Alive
        proxy_http_version 1.1;
        proxy_set_header   Connection "";
    }
}
```

---

## 다중 Tomcat 로드밸런싱

```nginx
upstream tomcats {
    # 로드밸런싱 방식 (기본: Round Robin)
    # least_conn;      # 최소 연결 수
    # ip_hash;         # 소스 IP 기반 (세션 스티키)
    # hash $cookie_JSESSIONID consistent;  # 쿠키 기반 스티키

    server 10.0.1.10:8080 weight=2;    # 가중치 설정
    server 10.0.1.11:8080 weight=1;
    server 10.0.1.12:8080 backup;      # 백업 서버

    keepalive 32;
}
```

### Sticky Session (JSESSIONID 쿠키 기반)

```nginx
# nginx.conf에 sticky 모듈 필요 (nginx-plus 또는 openresty)
# 또는 ip_hash / hash 사용

upstream tomcats {
    hash $cookie_JSESSIONID consistent;  # JSESSIONID 쿠키 기반 스티키

    server 10.0.1.10:8080;
    server 10.0.1.11:8080;
}
```

---

## Apache HTTP Server + mod_proxy_ajp

### AJP Connector 설정 (Tomcat)

```xml
<!-- server.xml -->
<Connector protocol="AJP/1.3"
           port="8009"
           address="127.0.0.1"
           secret="ajp-secret"
           secretRequired="true"
           redirectPort="8443" />
```

### Apache 설정

```apache
# /etc/httpd/conf.d/tomcat.conf
<VirtualHost *:80>
    ServerName www.example.com

    # AJP 프록시 설정
    ProxyRequests Off
    ProxyPreserveHost On

    <Location />
        ProxyPass ajp://127.0.0.1:8009/ secret=ajp-secret
        ProxyPassReverse ajp://127.0.0.1:8009/
    </Location>

    # 정적 파일은 Apache가 직접 서빙
    Alias /static /opt/apps/static
    <Directory /opt/apps/static>
        Options -Indexes
        Require all granted
    </Directory>

    ProxyPassMatch ^/static !  # 정적 파일 Tomcat으로 전달 제외
</VirtualHost>
```

---

## Apache + mod_jk (전통적 방식)

### mod_jk 설치

```bash
sudo dnf install -y mod_jk
```

### workers.properties

```properties
# /etc/httpd/conf.d/workers.properties
worker.list=worker1,worker2,loadbalancer

worker.worker1.type=ajp13
worker.worker1.host=10.0.1.10
worker.worker1.port=8009
worker.worker1.secret=ajp-secret
worker.worker1.lbfactor=1

worker.worker2.type=ajp13
worker.worker2.host=10.0.1.11
worker.worker2.port=8009
worker.worker2.secret=ajp-secret
worker.worker2.lbfactor=1

worker.loadbalancer.type=lb
worker.loadbalancer.balance_workers=worker1,worker2
worker.loadbalancer.sticky_session=true         # 세션 스티키
worker.loadbalancer.sticky_session_force=false  # 스티키 실패 시 다른 노드 허용
```

### Apache httpd.conf 설정

```apache
# /etc/httpd/conf.d/mod_jk.conf
LoadModule jk_module modules/mod_jk.so

JkWorkersFile /etc/httpd/conf.d/workers.properties
JkLogFile /var/log/httpd/mod_jk.log
JkLogLevel info
JkShmFile /run/httpd/mod_jk.shm

<VirtualHost *:80>
    ServerName www.example.com
    JkMount /* loadbalancer
    JkUnMount /static/* loadbalancer  # 정적 파일 제외
</VirtualHost>
```

---

## 연동 구성 확인

```bash
# Nginx → Tomcat 연결 테스트
curl -v http://localhost/
curl -v -H "Host: www.example.com" http://localhost/

# Tomcat 직접 접근 차단 확인 (외부에서 8080 접근 불가해야 함)
curl http://서버IP:8080/  # 방화벽에서 막혀야 함

# X-Forwarded-For 헤더 확인
curl -v http://www.example.com/ | grep -i "x-forwarded"

# Nginx 에러 로그 확인
tail -f /var/log/nginx/error.log

# Tomcat catalina.out에서 연결 로그 확인
tail -f /opt/tomcat/logs/catalina.out
```

---

## Keep-Alive 성능 최적화

```nginx
upstream tomcat {
    server 127.0.0.1:8080;
    keepalive 32;              # Nginx ↔ Tomcat 유지 연결 수
    keepalive_requests 100;    # 연결당 최대 요청 수
    keepalive_timeout  60s;    # 유지 연결 타임아웃
}

location / {
    proxy_pass http://tomcat;
    proxy_http_version  1.1;   # HTTP/1.1 필수 (Keep-Alive용)
    proxy_set_header Connection "";  # upstream으로 "Connection: close" 전달 방지
}
```

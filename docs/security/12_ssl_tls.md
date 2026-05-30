# 12. SSL/TLS 설정

## 개요

Tomcat에서 HTTPS를 설정하는 방법은 크게 두 가지입니다.

1. **Java Keystore (JKS/PKCS12)**: Java 내장 SSL 구현
2. **APR/OpenSSL**: 네이티브 OpenSSL 라이브러리 사용 (성능 우수)

> 운영 환경에서는 Tomcat에서 직접 SSL을 처리하기보다 Nginx를 SSL 종단점으로 사용하고
> Tomcat과는 HTTP/AJP로 통신하는 구조가 일반적입니다.

---

## 인증서 준비

### 자체 서명 인증서 생성 (개발용)

```bash
# Java keytool로 JKS 키스토어 생성
keytool -genkeypair \
  -alias tomcat \
  -keyalg RSA \
  -keysize 2048 \
  -validity 365 \
  -keystore /opt/tomcat/conf/keystore.jks \
  -storepass changeit \
  -keypass changeit \
  -dname "CN=localhost, OU=Dev, O=Example, L=Seoul, ST=Seoul, C=KR"

# 생성된 키스토어 확인
keytool -list -v -keystore /opt/tomcat/conf/keystore.jks -storepass changeit
```

### PKCS12 형식으로 변환 (권장)

```bash
# JKS → PKCS12
keytool -importkeystore \
  -srckeystore /opt/tomcat/conf/keystore.jks \
  -srcstorepass changeit \
  -destkeystore /opt/tomcat/conf/keystore.p12 \
  -deststoretype PKCS12 \
  -deststorepass changeit

# 또는 처음부터 PKCS12로 생성
keytool -genkeypair \
  -alias tomcat \
  -keyalg RSA \
  -keysize 2048 \
  -storetype PKCS12 \
  -keystore /opt/tomcat/conf/keystore.p12 \
  -storepass changeit \
  -validity 365 \
  -dname "CN=localhost, OU=Dev, O=Example, L=Seoul, ST=Seoul, C=KR"
```

### Let's Encrypt 인증서 사용

```bash
# Certbot 설치 (AL2023)
sudo dnf install -y certbot

# 인증서 발급 (standalone 방식, 80 포트 필요)
sudo certbot certonly --standalone \
  -d www.example.com \
  -d example.com \
  --email admin@example.com \
  --agree-tos

# 발급된 파일
# /etc/letsencrypt/live/www.example.com/fullchain.pem  (인증서 + 체인)
# /etc/letsencrypt/live/www.example.com/privkey.pem    (개인 키)

# PEM → PKCS12 변환
openssl pkcs12 -export \
  -in /etc/letsencrypt/live/www.example.com/fullchain.pem \
  -inkey /etc/letsencrypt/live/www.example.com/privkey.pem \
  -out /opt/tomcat/conf/keystore.p12 \
  -name tomcat \
  -passout pass:changeit

# Tomcat 소유권 설정
sudo chown tomcat:tomcat /opt/tomcat/conf/keystore.p12
sudo chmod 600 /opt/tomcat/conf/keystore.p12
```

---

## HTTPS Connector 설정 (PKCS12)

### 기본 HTTPS Connector

```xml
<!-- server.xml -->
<Connector port="8443"
           protocol="org.apache.coyote.http11.Http11NioProtocol"
           SSLEnabled="true"
           maxThreads="200"
           scheme="https"
           secure="true"
           connectionTimeout="20000">

    <SSLHostConfig
        honorCipherOrder="true"
        protocols="TLSv1.2+TLSv1.3"          <!-- TLS 1.0, 1.1 비활성화 -->
        ciphers="TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_AES_256_GCM_SHA384,TLS_CHACHA20_POLY1305_SHA256">

        <Certificate
            certificateKeystoreFile="conf/keystore.p12"
            certificateKeystorePassword="changeit"
            certificateKeystoreType="PKCS12"
            type="RSA" />
    </SSLHostConfig>
</Connector>
```

### PEM 파일 직접 사용 (Tomcat 8.5.6+)

```xml
<Connector port="8443"
           protocol="org.apache.coyote.http11.Http11NioProtocol"
           SSLEnabled="true"
           scheme="https"
           secure="true">

    <SSLHostConfig protocols="TLSv1.2+TLSv1.3">
        <Certificate
            certificateFile="conf/fullchain.pem"
            certificateKeyFile="conf/privkey.pem"
            type="RSA" />
    </SSLHostConfig>
</Connector>
```

---

## HTTP → HTTPS 리다이렉트

### 방법 1: web.xml (Servlet 규격)

```xml
<!-- WEB-INF/web.xml -->
<security-constraint>
    <web-resource-collection>
        <web-resource-name>Redirect</web-resource-name>
        <url-pattern>/*</url-pattern>
    </web-resource-collection>
    <user-data-constraint>
        <transport-guarantee>CONFIDENTIAL</transport-guarantee>
    </user-data-constraint>
</security-constraint>
```

```xml
<!-- server.xml HTTP Connector에 redirectPort 설정 -->
<Connector port="8080" ... redirectPort="8443" />
```

### 방법 2: RewriteValve

```xml
<!-- conf/Catalina/localhost/ROOT.xml -->
<Context>
    <Valve className="org.apache.catalina.valves.rewrite.RewriteValve" />
</Context>
```

```
# conf/Catalina/localhost/rewrite.config
RewriteCond %{HTTP:X-Forwarded-Proto} ^http$
RewriteRule ^/(.*)$ https://www.example.com/$1 [R=301,L]
```

---

## SSLHostConfig 주요 속성

| 속성 | 설명 | 권장값 |
|------|------|--------|
| `protocols` | 허용 TLS 버전 | `TLSv1.2+TLSv1.3` |
| `honorCipherOrder` | 서버 사이퍼 우선순위 적용 | `true` |
| `disableSessionTickets` | 세션 티켓 비활성화 | `true` (PFS 보장) |
| `certificateVerification` | 클라이언트 인증서 검증 | `none`, `optional`, `required` |
| `truststoreFile` | 클라이언트 인증서 CA 저장소 (mTLS용) | - |
| `sessionTimeout` | SSL 세션 캐시 타임아웃 (초) | `86400` |

---

## mTLS (상호 인증)

```xml
<SSLHostConfig
    protocols="TLSv1.2+TLSv1.3"
    certificateVerification="required"          <!-- 클라이언트 인증서 필수 -->
    truststoreFile="conf/client-truststore.p12" <!-- 허용할 클라이언트 CA -->
    truststorePassword="changeit">

    <Certificate
        certificateKeystoreFile="conf/server-keystore.p12"
        certificateKeystorePassword="changeit"
        type="RSA" />
</SSLHostConfig>
```

---

## 인증서 갱신 (Let's Encrypt)

```bash
# 인증서 갱신 (certbot)
sudo certbot renew --pre-hook "systemctl stop tomcat" \
                   --post-hook "systemctl start tomcat"

# 또는 Nginx를 앞단에 두고 Tomcat은 재시작 없이 Nginx만 재로드
sudo certbot renew --post-hook "systemctl reload nginx"

# cron으로 자동 갱신 (90일 만료, 30일 전 갱신 시도)
echo "0 0 * * * root certbot renew --quiet" | sudo tee /etc/cron.d/certbot
```

---

## SSL 설정 검증

```bash
# Tomcat SSL 연결 테스트
curl -v https://localhost:8443/ --insecure  # 자체 서명 인증서

# 인증서 정보 확인
echo "" | openssl s_client -connect localhost:8443 -servername localhost 2>/dev/null \
  | openssl x509 -noout -dates -subject -issuer

# TLS 버전 및 사이퍼 확인
nmap --script ssl-enum-ciphers -p 8443 localhost

# SSL Labs 테스트 (공인 도메인)
# https://www.ssllabs.com/ssltest/
```

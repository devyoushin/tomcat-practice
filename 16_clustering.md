# 16. 클러스터링 & 세션 복제

## 개요

Tomcat 클러스터링은 여러 Tomcat 인스턴스 간에 세션을 복제하여
특정 인스턴스가 다운되어도 사용자 세션이 유지되도록 합니다.

```
       [로드밸런서]
       /           \
[Tomcat-1]      [Tomcat-2]
세션 A ←복제→ 세션 A
세션 B ←복제→ 세션 B
```

---

## 클러스터링 방식 비교

| 방식 | 설명 | 장점 | 단점 |
|------|------|------|------|
| **DeltaManager** | 변경분을 모든 노드에 복제 | 간단한 설정 | 노드 수 증가 시 네트워크 트래픽 증가 |
| **BackupManager** | 하나의 백업 노드에만 복제 | 네트워크 트래픽 감소 | 로드밸런서가 세션 라우팅 지원 필요 |
| **외부 세션 저장소** | Redis, DB 등 외부 저장소 사용 | 확장성 우수 | 외부 의존성 추가 |

---

## DeltaManager 설정

모든 노드에 세션 변경분을 멀티캐스트로 브로드캐스팅합니다.

### server.xml 설정 (각 노드 동일)

```xml
<!-- server.xml -->
<Engine name="Catalina" defaultHost="localhost" jvmRoute="worker1">
    <!-- jvmRoute: 각 노드마다 고유 값 (worker1, worker2, ...) -->

    <Cluster className="org.apache.catalina.ha.tcp.SimpleTcpCluster"
             channelSendOptions="8">

        <!-- 세션 복제 관리자 -->
        <Manager className="org.apache.catalina.ha.session.DeltaManager"
                 expireSessionsOnShutdown="false"
                 notifyListenersOnReplication="true" />

        <!-- 채널 설정 (노드 간 통신) -->
        <Channel className="org.apache.catalina.tribes.group.GroupChannel">

            <!-- 멤버십: 멀티캐스트로 클러스터 멤버 발견 -->
            <Membership
                className="org.apache.catalina.tribes.membership.McastService"
                address="228.0.0.4"           <!-- 멀티캐스트 주소 -->
                port="45564"                   <!-- 멀티캐스트 포트 -->
                frequency="500"                <!-- 하트비트 주기 (ms) -->
                dropTime="3000" />             <!-- 응답 없으면 제거 (ms) -->

            <!-- 수신: 다른 노드로부터 데이터 수신 -->
            <Receiver
                className="org.apache.catalina.tribes.transport.nio.NioReceiver"
                address="auto"                 <!-- 또는 명시적 IP -->
                port="4000"                    <!-- 노드 간 통신 포트 -->
                autoBind="100"
                selectorTimeout="5000"
                maxThreads="6" />

            <!-- 발신: 다른 노드로 데이터 전송 -->
            <Sender
                className="org.apache.catalina.tribes.transport.ReplicationTransmitter">
                <Transport
                    className="org.apache.catalina.tribes.transport.nio.PooledParallelSender" />
            </Sender>

            <!-- 인터셉터 체인 -->
            <Interceptor className="org.apache.catalina.tribes.group.interceptors.TcpFailureDetector" />
            <Interceptor className="org.apache.catalina.tribes.group.interceptors.MessageDispatchInterceptor" />
        </Channel>

        <!-- 세션 복제 Valve (변경된 세션 감지 후 복제) -->
        <Valve className="org.apache.catalina.ha.tcp.ReplicationValve"
               filter="" />

        <!-- 정적 멤버십 Valve -->
        <Valve className="org.apache.catalina.ha.session.JvmRouteBinderValve" />

        <!-- 리스너 -->
        <Deployer className="org.apache.catalina.ha.deploy.FarmWarDeployer"
                  tempDir="/tmp/war-temp/"
                  deployDir="/tmp/war-deploy/"
                  watchDir="/tmp/war-listen/"
                  watchEnabled="false" />

        <ClusterListener className="org.apache.catalina.ha.session.ClusterSessionListener" />
    </Cluster>

    <Host name="localhost" appBase="webapps" ...>
    </Host>
</Engine>
```

### 노드2 차이점

```xml
<!-- worker2의 server.xml: jvmRoute만 다르게 -->
<Engine name="Catalina" defaultHost="localhost" jvmRoute="worker2">
    <!-- 나머지 클러스터 설정 동일 -->
```

---

## BackupManager 설정

하나의 백업 노드에만 세션을 복제합니다 (Primary-Backup 구조).

```xml
<Cluster className="org.apache.catalina.ha.tcp.SimpleTcpCluster"
         channelSendOptions="6">

    <Manager className="org.apache.catalina.ha.session.BackupManager"
             expireSessionsOnShutdown="false"
             notifyListenersOnReplication="true"
             mapSendOptions="6" />

    <Channel className="org.apache.catalina.tribes.group.GroupChannel">
        <Membership className="org.apache.catalina.tribes.membership.McastService"
                    address="228.0.0.4"
                    port="45564"
                    frequency="500"
                    dropTime="3000" />

        <Receiver className="org.apache.catalina.tribes.transport.nio.NioReceiver"
                  address="auto"
                  port="4001"
                  selectorTimeout="100"
                  maxThreads="6" />

        <Sender className="org.apache.catalina.tribes.transport.ReplicationTransmitter">
            <Transport className="org.apache.catalina.tribes.transport.nio.PooledParallelSender" />
        </Sender>

        <Interceptor className="org.apache.catalina.tribes.group.interceptors.TcpFailureDetector" />
        <Interceptor className="org.apache.catalina.tribes.group.interceptors.MessageDispatchInterceptor" />
        <Interceptor className="org.apache.catalina.tribes.group.interceptors.ThroughputInterceptor" />
    </Channel>

    <Valve className="org.apache.catalina.ha.tcp.ReplicationValve" filter=".*\.gif|.*\.js|.*\.jpg|.*\.png|.*\.htm|.*\.css|.*\.txt" />
    <ClusterListener className="org.apache.catalina.ha.session.ClusterSessionListener" />
</Cluster>
```

---

## 세션 스티키(Sticky Session) — Nginx 설정

```nginx
# nginx.conf
upstream tomcats {
    ip_hash;  # 동일 IP는 동일 서버로 (세션 스티키)

    server tomcat1:8080;
    server tomcat2:8080;
}

server {
    listen 80;
    location / {
        proxy_pass http://tomcats;

        # jvmRoute 기반 세션 스티키
        proxy_cookie_path / /;
        sticky cookie JSESSIONID path=/;  # nginx-sticky-module 사용 시
    }
}
```

---

## 정적 멤버십 (멀티캐스트 불가 환경)

AWS, 컨테이너 환경에서는 멀티캐스트를 지원하지 않을 수 있습니다.
정적 멤버십을 사용합니다.

```xml
<Channel className="org.apache.catalina.tribes.group.GroupChannel">

    <!-- McastService 대신 StaticMembershipService 사용 -->
    <Membership className="org.apache.catalina.tribes.membership.cloud.CloudMembershipService"
                membershipProviderClassName="org.apache.catalina.tribes.membership.StaticMembershipProvider" />

    <Receiver className="org.apache.catalina.tribes.transport.nio.NioReceiver"
              address="10.0.1.10"    <!-- 자신의 IP -->
              port="4000" />

    <Sender className="org.apache.catalina.tribes.transport.ReplicationTransmitter">
        <Transport className="org.apache.catalina.tribes.transport.nio.PooledParallelSender" />
    </Sender>

    <!-- 다른 노드를 정적으로 명시 -->
    <Interceptor className="org.apache.catalina.tribes.group.interceptors.StaticMembershipInterceptor">
        <Member className="org.apache.catalina.tribes.membership.StaticMember"
                port="4000"
                securePort="-1"
                host="10.0.1.11"         <!-- 노드2 IP -->
                domain="tomcat-cluster"
                uniqueId="{0,1,2,3,4,5,6,7,8,9,0,1,2,3,4,5}" />
    </Interceptor>
    <Interceptor className="org.apache.catalina.tribes.group.interceptors.TcpFailureDetector" />
    <Interceptor className="org.apache.catalina.tribes.group.interceptors.MessageDispatchInterceptor" />
</Channel>
```

---

## 클러스터링 요구사항

### 애플리케이션 요구사항

```java
// 1. 세션에 저장되는 객체는 Serializable 구현 필수
public class UserSession implements Serializable {
    private static final long serialVersionUID = 1L;
    // ...
}

// 2. 세션 변경 후 setAttribute 호출 (DeltaManager가 감지)
User user = (User) session.getAttribute("user");
user.setLastAccess(new Date());
session.setAttribute("user", user);  // 변경 반드시 명시
```

### 방화벽 포트

```bash
# 클러스터 노드 간 포트 허용
sudo firewall-cmd --permanent --add-port=4000/tcp  # Receiver 포트
sudo firewall-cmd --permanent --add-port=45564/udp # Membership 멀티캐스트
sudo firewall-cmd --reload
```

---

## 클러스터링 확인

```bash
# 클러스터 로그 확인
grep -i "cluster\|member\|replicate" /opt/tomcat/logs/catalina.out

# Manager App에서 세션 분포 확인
curl -u admin:password http://localhost:8080/manager/text/sessions?path=/myapp
```

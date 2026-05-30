#!/bin/bash

export JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto
export CATALINA_HOME=/opt/tomcat
export CATALINA_BASE=/opt/tomcat
export CATALINA_PID=/opt/tomcat/temp/tomcat.pid

export CATALINA_OPTS="\
  -server \
  -Xms2g \
  -Xmx2g \
  -XX:MetaspaceSize=256m \
  -XX:MaxMetaspaceSize=512m \
  -XX:+UseG1GC \
  -XX:MaxGCPauseMillis=200 \
  -Xlog:gc*:file=/opt/tomcat/logs/gc.log:time,uptime,tags:filecount=5,filesize=50m \
  -XX:+HeapDumpOnOutOfMemoryError \
  -XX:HeapDumpPath=/opt/tomcat/logs/heapdump-%p.hprof \
  -XX:ErrorFile=/opt/tomcat/logs/hs_err_%p.log \
  -Djava.awt.headless=true \
  -Dfile.encoding=UTF-8 \
  -Duser.timezone=Asia/Seoul \
"

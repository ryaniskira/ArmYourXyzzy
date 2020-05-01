FROM arm64v8/tomcat:8.5.54-jdk11-openjdk as base

# MAVEN
ENV MAVEN_VERSION 3.5.4
ENV USER_HOME_DIR /root
ENV SHA ce50b1c91364cb77efe3776f756a6d92b76d9038b0a0782f7d53acf1e997a14d
ENV BASE_URL https://apache.osuosl.org/maven/maven-3/${MAVEN_VERSION}/binaries
ENV MAVEN_HOME /usr/share/maven
ENV MAVEN_CONFIG "$USER_HOME_DIR/.m2"

RUN apt install curl tar procps \
 && mkdir -p /usr/share/maven/ref \
 && curl -fsSL -o /tmp/apache-maven.tar.gz "${BASE_URL}/apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
 && echo "${SHA} /tmp/apache-maven.tar.gz" | sha256sum -c - || true \
 && tar -xzf /tmp/apache-maven.tar.gz -C /usr/share/maven --strip-components=1 \
 && rm -f /tmp/apache-maven.tar.gz \
 && ln -s /usr/share/maven/bin/mvn /usr/bin/mvn

ADD ./overrides/settings-docker.xml /usr/share/maven/ref/
ADD overrides /overrides
ADD scripts/entrypoint.sh /

# PYX
ENV GIT_BRANCH master
VOLUME /app /output

# OVERRIDE:
# Specify geoip2 version until https://github.com/ajanata/PretendYoureXyzzy/pull/228
RUN apt install openssh-client \
 && git clone -b $GIT_BRANCH https://github.com/ajanata/PretendYoureXyzzy.git /project \
 && cd /project \
 && cp build.properties.example build.properties \
 && mvn versions:use-dep-version \
  -Dincludes=com.maxmind.geoip2:geoip2 \
  -DdepVersion=2.8.1 \
  -DforceVersion=true \
 && mvn clean package war:war \
  -Dhttps.protocols=TLSv1.2 \
  -Dmaven.buildNumber.doCheck=false \
  -Dmaven.buildNumber.doUpdate=false

ENTRYPOINT ["/entrypoint.sh"]

WORKDIR /project

CMD mvn clean package war:exploded jetty:run -Dhttps.protocols=TLSv1.2 -Dmaven.buildNumber.doCheck=false -Dmaven.buildNumber.doUpdate=false

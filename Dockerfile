# This Dockerfile is used to build an headles vnc image based on Debian

FROM debian:11

ENV REFRESHED_AT 2023-01-27

LABEL io.k8s.description="Headless VNC Container with IceWM window manager, firefox and chromium" \
      io.k8s.display-name="Headless VNC Container based on Debian" \
      io.openshift.expose-services="6901:http,5901:xvnc" \
      io.openshift.tags="vnc, debian, icewm" \
      io.openshift.non-scalable=true

## Connection ports for controlling the UI:
# VNC port:5901
# noVNC webport, connect via http://IP:6901/?password=vncpassword
ENV DISPLAY=:1 \
    VNC_PORT=5901 \
    NO_VNC_PORT=6901
EXPOSE $VNC_PORT $NO_VNC_PORT

### Envrionment config
ENV HOME=/headless \
    TERM=xterm \
    STARTUPDIR=/dockerstartup \
    INST_SCRIPTS=/headless/install \
    NO_VNC_HOME=/headless/noVNC \
    DEBIAN_FRONTEND=noninteractive \
    VNC_COL_DEPTH=24 \
    VNC_RESOLUTION=1280x1024 \
    VNC_PW=vncpassword \
    VNC_VIEW_ONLY=false
WORKDIR $HOME

### Add all install scripts for further steps
ADD ./src/common/install/ $INST_SCRIPTS/
ADD ./src/debian/install/ $INST_SCRIPTS/

### Install some common tools
RUN $INST_SCRIPTS/tools.sh
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

### Install custom fonts
RUN $INST_SCRIPTS/install_custom_fonts.sh

### Install xvnc-server & noVNC - HTML5 based VNC viewer
RUN $INST_SCRIPTS/tigervnc.sh
RUN $INST_SCRIPTS/no_vnc.sh

### Install firefox and chrome browser
RUN $INST_SCRIPTS/firefox.sh
RUN $INST_SCRIPTS/chrome.sh

### Install IceWM UI
RUN $INST_SCRIPTS/icewm_ui.sh
ADD ./src/debian/icewm/ $HOME/

### configure startup
RUN $INST_SCRIPTS/libnss_wrapper.sh
ADD ./src/common/scripts $STARTUPDIR
RUN $INST_SCRIPTS/set_user_permission.sh $STARTUPDIR $HOME

### Install Minecraft
RUN apt-get -y update && apt-get -y upgrade
RUN apt-get install -y curl wget unzip openjdk-17-jdk
RUN mkdir minecraftforge && cd minecraftforge && \
wget "https://maven.minecraftforge.net/net/minecraftforge/forge/1.18.2-40.2.0/forge-1.18.2-40.2.0-mdk.zip" -O temp.zip && \
unzip temp.zip && rm temp.zip && ./gradlew genEclipseRun

### Create desktop file for minecraft
RUN touch minecraft.desktop
RUN echo [Desktop Entry] \
Encoding=UTF-8 \
Version=1.0 \
Type=Application \
Terminal=false \
Exec= ~/minecraftforge/./gradlew runClient \
Name=Minecraft \
Icon=/path/to/icon \ >> minecraft.desktop && mv minecraft.desktop /usr/share/applications/

RUN wget "https://download-cdn.jetbrains.com/idea/ideaIC-2021.2.3.tar.gz" && tar xvf ideaIC-2021.2.3.tar.gz && mv idea-IC-212.5457.46/ /opt/idea && rm ideaIC-2021.2.3.tar.gz 

ENTRYPOINT ["/dockerstartup/vnc_startup.sh"]
CMD ["--wait"]

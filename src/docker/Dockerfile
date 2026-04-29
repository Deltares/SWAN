FROM centos:7

RUN mkdir /data
COPY SWANNC8 /opt/SWANNC8
COPY test /data

ENV SWANEXE=swan.exe \
	SWANDIR=/opt/SWANNC8

ENV LD_LIBRARY_PATH=$SWANDIR \
	PATH=$SWANDIR:$PATH \
	INPUT=

COPY run_docker_NZ.sh /opt/run_docker.sh
WORKDIR /data

CMD /opt/run_docker.sh $INPUT

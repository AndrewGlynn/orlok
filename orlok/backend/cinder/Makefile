FRAMEWORKS= -framework Carbon -framework Cocoa -framework OpenGL -framework QuickTime -framework QTKit -framework Accelerate -framework AudioToolbox -framework AudioUnit -framework CoreAudio -framework CoreVideo
CINDER_PATH= cinder_0.8.4_mac

CFLAGS= -arch i386 -I$(CINDER_PATH)/include -I$(CINDER_PATH)/boost -L$(CINDER_PATH)/lib -Wall -O2 -DNDEBUG
LFLAGS= -arch i386 -L$(CINDER_PATH)/lib -lcinder $(FRAMEWORKS)

CC=g++ $(CFLAGS) $(LFLAGS)
OBJS= cinder_backend.o

.PHONY: all clean

all: cinder_backend.h cinder_backend.cpp
	$(CC) -c cinder_backend.cpp
	ar -r orlok_cinder_backend.a cinder_backend.o
	mkdir -p ../../../_build/build/orlok
	cp orlok_cinder_backend.a ../../../_build/build/orlok
	cp $(CINDER_PATH)/lib/libcinder.a ../../../_build/build/orlok
	
clean:
	rm -f $(OBJS) orlok_cinder_backend.a

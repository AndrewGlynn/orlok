MELANGE = ../opendylan/melange/_build/bin/melange
ORLOK = orlok/_build/lib/liborlok.dylib
LIBCINDER = orlok/backend/cinder/libcinder.a
ORLOK_CINDER_BACKEND = orlok/backend/cinder/orlok_cinder_backend.a


.PHONY: clean all orlok examples simple-app sampler bricks

all: examples
orlok: $(ORLOK)
examples: simple-app sampler bricks

$(ORLOK_CINDER_BACKEND): orlok/backend/cinder/cinder_backend.h orlok/backend/cinder/cinder_backend.cpp
	cd orlok/backend/cinder; make

orlok/cinder-backend.dylan: orlok/cinder-backend.intr
	$(MELANGE) orlok/cinder-backend.intr orlok/cinder-backend.dylan

$(ORLOK): orlok/cinder-backend.dylan $(ORLOK_CINDER_BACKEND)
	dylan-compiler -build orlok

simple-app: $(ORLOK)
	dylan-compiler -build simple-app
	cp _build/bin/simple-app examples/simple-app/simple-app.app/Contents/MacOS
	cp _build/lib/*.dylib examples/simple-app/simple-app.app/Contents/lib

sampler: $(ORLOK)
	dylan-compiler -build sampler
	cp _build/bin/sampler examples/sampler/sampler.app/Contents/MacOS
	cp _build/lib/*.dylib examples/sampler/sampler.app/Contents/lib

bricks: $(ORLOK)
	dylan-compiler -build bricks
	cp _build/bin/bricks examples/bricks/bricks.app/Contents/MacOS
	cp _build/lib/*.dylib examples/bricks/bricks.app/Contents/lib

clean:
	rm -rf _build
	rm -f orlok/cinder-backend.dylan
	cd orlok/backend/cinder; make clean

library:      orlok
files:        library
              color
              orlok-core
              key-ids
              vector-graphics
              full-screen-effects
              cinder-backend
              spatial-2d
              visual
              standard-behaviors
              image
              text-field
              visual-app
c-object-files: libcinder.a
                orlok_cinder_backend.a
c-libraries:  orlok_cinder_backend.a
              libcinder.a
              -lstdc++
              -framework Carbon
              -framework Cocoa
              -framework OpenGL
              -framework QuickTime
              -framework QTKit
              -framework Accelerate
              -framework AudioToolbox
              -framework AudioUnit
              -framework CoreAudio
              -framework CoreVideo

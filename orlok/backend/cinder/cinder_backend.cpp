#include "cinder/app/AppBasic.h"
#include "cinder/cairo/Cairo.h"
#include "cinder/Rand.h"
#include "cinder/Utilities.h"
#include "cinder/audio/Output.h"
#include "cinder/audio/Io.h"
#include "cinder/Font.h"
#include "cinder/ip/Fill.h"
#include "cinder/ip/Flip.h"
#include "cinder/ip/Premultiply.h"
#include "cinder/ip/Resize.h"
#include "cinder/gl/gl.h"
#include "cinder/gl/Texture.h"
#include "cinder/gl/TextureFont.h"
#include "cinder/gl/GlslProg.h"
#include "cinder/gl/Fbo.h"
#include <algorithm>

using namespace ci;
using namespace ci::app;

// In order to use fonts with the cairo API while also having high performance
// when using OpenGL we maintain both a normal Font and a TextureFont for each
// font.
struct FontT
{
    Font*               font;
    gl::TextureFontRef  textureFont;
};


// This is the cinder app that provides the Orlok backend functionality.
class CinderBackendApp : public AppBasic
{
public:
    CinderBackendApp();

    // Overrides:

    void prepareSettings(Settings *settings);
    void setup();
    void shutdown();
    
    void keyDown(KeyEvent event);
    void keyUp(KeyEvent event);
    void mouseDown(MouseEvent event);
    void mouseUp(MouseEvent event);
    void mouseMove(MouseEvent event);
    void mouseDrag(MouseEvent event);
    void resize(ResizeEvent event);
    
    void update();
    void draw();

public:
    cairo::GradientLinear m_linearGradient;
    cairo::GradientRadial m_radialGradient;
    cairo::Gradient* m_activeGradient;

    cairo::Context m_fontContext; // context required to get font metrics
};

// C interface (wrapped via Dylan C-FFI)

extern "C"
{

static int cinder_w = 800;
static int cinder_h = 600;
static int cinder_resizable = 1;
static int cinder_fullscreen = 0;
static int cinder_frames_per_second = 60;
static CinderBackendApp* cinder_app = 0;

// Note: The following functions are callable from Dylan, as c-functions.

void cinder_run(int width, int height,
                int appWidth, int appHeight,
                int forceAppAspectRatio,
                int fullscreen, int frames_per_second)
{
    cinder_w = width;
    cinder_h = height;
    cinder_resizable = 1; // ???
    cinder_fullscreen = fullscreen;
    cinder_frames_per_second = frames_per_second;

    // TODO: get real argc and argv (what are they used for?)

    int argc = 0;
    char** argv = 0;

    cinder::app::AppBasic::prepareLaunch();
    cinder_app = new CinderBackendApp;

    cinder::app::Renderer* ren = new RendererGl;
    cinder::app::AppBasic::executeLaunch(cinder_app, ren, "", argc, argv);
    cinder::app::AppBasic::cleanupLaunch();
}

void cinder_quit()
{
    cinder_app->quit();
}

void cinder_set_full_screen(int fullscreen)
{
    cinder_fullscreen = fullscreen;
    cinder_app->setFullScreen(fullscreen);
}

float cinder_audio_get_master_volume()
{
    return audio::Output::getVolume();
}

void cinder_audio_set_master_volume(float v)
{
    audio::Output::setVolume(v);
}


void* cinder_audio_load_sound(const char* resourceName)
{
    audio::SourceRef* src =
        new audio::SourceRef(audio::load(loadResource(resourceName)));

    if (src->get() == 0)
    {
        delete src;
        return 0;
    }
    else
    {
      return src;
    }
}

void cinder_audio_free_sound(void* soundPtr)
{
    delete static_cast<audio::SourceRef*>(soundPtr);
}

void cinder_audio_play_sound(void* soundPtr, float volume)
{
    audio::SourceRef* src = static_cast<audio::SourceRef*>(soundPtr);
    audio::TrackRef track = audio::Output::addTrack(*src);
    track->play();
    track->setVolume(volume);
}

void* cinder_audio_load_music(const char* resourceName)
{
    audio::TrackRef* track = new audio::TrackRef(
      audio::Output::addTrack(audio::load(loadResource(resourceName))));

    if (track->get() == 0)
    {
        delete track;
        return 0;
    }

    (*track)->stop();
    return track;
}

void cinder_audio_free_music(void* musicPtr)
{
    audio::TrackRef* track = static_cast<audio::TrackRef*>(musicPtr);
    delete track;
}

void cinder_audio_play_music(void* musicPtr, int loop, int restart)
{
    audio::TrackRef* track = static_cast<audio::TrackRef*>(musicPtr);

    if (restart)
    {
        (*track)->setTime(0.0);
    }

    (*track)->play();
    (*track)->setLooping(loop);
}

void cinder_audio_stop_music(void* musicPtr)
{
    audio::TrackRef* track = static_cast<audio::TrackRef*>(musicPtr);
    (*track)->stop();
}

void cinder_audio_set_music_volume(void* musicPtr, float volume)
{
    audio::TrackRef* track = static_cast<audio::TrackRef*>(musicPtr);
    (*track)->setVolume(volume);
}

float cinder_audio_get_music_volume(void* musicPtr)
{
    audio::TrackRef* track = static_cast<audio::TrackRef*>(musicPtr);
    return (*track)->getVolume();
}

float cinder_get_average_fps()
{
    return cinder_app->getAverageFps();
}

// Surface (aka Bitmap) stuff

void* cinder_surface_create(int width, int height)
{
    cairo::SurfaceImage* surf = new cairo::SurfaceImage(width, height, true);
    // TODO: error checking?

    return surf;
}

void cinder_surface_free(void* surfacePtr)
{
    delete static_cast<cairo::SurfaceImage*>(surfacePtr);
}

void* cinder_load_surface(char* resourceName, int* width, int* height)
{
    cairo::SurfaceImage* surf =
        new cairo::SurfaceImage(loadImage(loadResource(resourceName)));
    // TODO: error checking?

    *width = surf->getWidth();
    *height = surf->getHeight();
    return surf;
}

void cinder_surface_copy_pixels(void* srcPtr, int srcX, int srcY, int w, int h,
                                void* destPtr, int destX, int destY)
{
    cairo::SurfaceImage* src = static_cast<cairo::SurfaceImage*>(srcPtr);
    cairo::SurfaceImage* dest = static_cast<cairo::SurfaceImage*>(destPtr);

    Area area(srcX, srcY, srcX + w, srcY + h);
    Vec2i offset(destX - srcX, destY - srcY);

    dest->getSurface().copyFrom(src->getSurface(), area, offset);
    dest->markDirty();
}

void cinder_surface_fill(void* ptr, float r, float g, float b, float a,
                         int x, int y, int w, int h)
{
  cairo::SurfaceImage* si = static_cast<cairo::SurfaceImage*>(ptr);
  ColorA color(r, g, b, a);
  Area area(x, y, x + w, y + h);

  cinder::ip::fill(&si->getSurface(), color, area);
}

void cinder_surface_premultiply(void* ptr)
{
  cairo::SurfaceImage* si = static_cast<cairo::SurfaceImage*>(ptr);
  cinder::ip::premultiply(&si->getSurface());
}

void cinder_surface_unpremultiply(void* ptr)
{
  cairo::SurfaceImage* si = static_cast<cairo::SurfaceImage*>(ptr);
  cinder::ip::unpremultiply(&si->getSurface());
}

void cinder_surface_flip_vertical(void* ptr)
{
  cairo::SurfaceImage* si = static_cast<cairo::SurfaceImage*>(ptr);
  cinder::ip::flipVertical(&si->getSurface());
}

void* cinder_surface_resize(void* ptr, int width, int height, int filter)
{
    cairo::SurfaceImage* si = static_cast<cairo::SurfaceImage*>(ptr);

    Area area(0, 0, si->getWidth(), si->getHeight());
    Vec2i size(width, height);

    Surface surf;

    switch(filter)
    {
    case 0:
      surf = cinder::ip::resizeCopy(si->getSurface(), area, size, FilterBox());
      break;
    case 1:
      surf = cinder::ip::resizeCopy(si->getSurface(), area, size, FilterTriangle());
      break;
    case 2:
      surf = cinder::ip::resizeCopy(si->getSurface(), area, size, FilterGaussian());
      break;
    default:
      // TODO: error message about bad filter type
      return 0;
    }

    cairo::SurfaceImage* result = new cairo::SurfaceImage(surf);

    return result;
}

// OpenGL stuff

void cinder_gl_set_viewport(int x, int y, int width, int height)
{
    Area viewport(x, y, width, height);
    gl::setViewport(viewport);
}

void cinder_gl_set_matrices_window(int width, int height)
{
    gl::setMatricesWindow(width, height);
}

void cinder_gl_set_blend(int mode)
{
    switch (mode)
    {
        case 0:
            gl::enableAlphaBlending();
            break;
        case 1:
            gl::enableAdditiveBlending();
            break;
    }
}

void* cinder_gl_create_texture(int width, int height)
{
    try
    {
        gl::Texture* tex = new gl::Texture(width, height);
        return tex;
    }
    catch (const gl::TextureDataExc& ex)
    {
        // TODO: return more info?
        return 0;
    }
}

void cinder_gl_free_texture(void* texPtr)
{
    gl::Texture* tex = static_cast<gl::Texture*>(texPtr);
    delete tex;
}

void cinder_gl_update_texture(void* texPtr, void* surfPtr,
                              int x1, int y1, int x2, int y2)
{
    gl::Texture* tex = static_cast<gl::Texture*>(texPtr);
    cairo::SurfaceImage* surf = static_cast<cairo::SurfaceImage*>(surfPtr);
    Area area(x1, y1, x2, y2);

    tex->update(surf->getSurface(), area);
}

void* cinder_gl_create_texture_from_surface(void* surfPtr, int x, int y, int w, int h)
{
    cairo::SurfaceImage* surf = static_cast<cairo::SurfaceImage*>(surfPtr);

    try
    {
        if (w != surf->getSurface().getWidth() || h != surf->getSurface().getHeight())
        {
            // TODO: Not particularly efficient, but cinder doesn't provide a
            //       Texture constructor taking a Surface and an Area, so we have
            //       to construct first, and then update the texture data.
            gl::Texture* tex = new gl::Texture(w, h);
            cinder_gl_update_texture(tex, surf, x, y, x + w, y + h);
            return tex;
        }
        else
        {
            gl::Texture* tex = new gl::Texture(surf->getSurface());
            return tex;
        }
    }
    catch (const gl::TextureDataExc& ex)
    {
        // TODO: return more info?
        return 0;
    }
}

void cinder_gl_bind_texture(void* texPtr)
{
    gl::Texture* tex = static_cast<gl::Texture*>(texPtr);
    tex->enableAndBind();
}

void cinder_gl_unbind_texture(void* texPtr)
{
    gl::Texture* tex = static_cast<gl::Texture*>(texPtr);
    tex->unbind();
}

void cinder_gl_push_modelview_matrix()
{
    gl::pushModelView();
}

void cinder_gl_pop_modelview_matrix()
{
    gl::popModelView();
}

void cinder_gl_update_transform(float sx, float shy, float shx, float sy, float tx, float ty)
{
    static Matrix44f m;

    m.set(sx,   shx,  0.0f, tx,
          shy,  sy,   0.0f, ty,
          0.0f, 0.0f, 1.0f, 0.0f,
          0.0f, 0.0f, 0.0f, 1.0f, true);

    gl::multModelView(m);
}


void cinder_gl_clear(float r, float g, float b, float a, int depth)
{
    gl::clear(ColorA(r, g, b, a), depth);
}

void cinder_gl_draw_rect(float x1, float y1, float x2, float y2,
                         float u1, float v1, float u2, float v2)
{
#if 0
    gl::drawSolidRect(Rectf(x1, y1, x2, y2));
#else
    // NOTE: Copied from gl::drawSolidRect, except that this will actually
    // flip the texture coordinates if required.
    glEnableClientState( GL_VERTEX_ARRAY );
    GLfloat verts[8];
    glVertexPointer( 2, GL_FLOAT, 0, verts );
    glEnableClientState( GL_TEXTURE_COORD_ARRAY );
    GLfloat texCoords[8];
    glTexCoordPointer( 2, GL_FLOAT, 0, texCoords );
    verts[0*2+0] = x2; texCoords[0*2+0] = u2;
    verts[0*2+1] = y1; texCoords[0*2+1] = v1;
    verts[1*2+0] = x1; texCoords[1*2+0] = u1;
    verts[1*2+1] = y1; texCoords[1*2+1] = v1;
    verts[2*2+0] = x2; texCoords[2*2+0] = u2;
    verts[2*2+1] = y2; texCoords[2*2+1] = v2;
    verts[3*2+0] = x1; texCoords[3*2+0] = u1;
    verts[3*2+1] = y2; texCoords[3*2+1] = v2;

    //glColor3f(1.0f, 0.0f, 0.0f);

    glDrawArrays( GL_TRIANGLE_STRIP, 0, 4 );

    glDisableClientState( GL_VERTEX_ARRAY );
    glDisableClientState( GL_TEXTURE_COORD_ARRAY );	
#endif
}

void cinder_gl_draw_text(char* text, float r, float g, float b, float a,
                         float x, float y, void* fontPtr)
{
    gl::TextureFontRef texFont = static_cast<FontT*>(fontPtr)->textureFont;

    // TODO: Color ignored!
    texFont->drawString(text, Vec2f(x, y));
    //gl::drawString(text, Vec2f(x, y), ColorA(r, g, b, a), *static_cast<FontT*>(fontPtr)->font);
}

void cinder_gl_draw_line(float x1, float y1, float x2, float y2,
                         float r, float g, float b, float a,
                         float width)
{
    static float lineWidth = -1.0f;

    if (width != lineWidth)
    {
        glLineWidth(width);
    }

    // TODO: add color stack?
    glColor4f(r, g, b, a);
    gl::drawLine(Vec2f(x1, y1), Vec2f(x2, y2));
    glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
}

void* cinder_gl_load_shader_program(char* vertShader, char* fragShader,
                                    const char** outErrorMsg)
{
    try
    {
        gl::GlslProg* prog = new gl::GlslProg(loadResource(vertShader),
                                              loadResource(fragShader));
        return prog;
    }
    catch (gl::GlslProgCompileExc& exc)
    {
        *outErrorMsg = exc.what();
        return 0;
    }
    catch (...)
    {
        *outErrorMsg = "error loading shader program";
        return 0;
    }
}

void* cinder_gl_create_shader_program(char* vertShaderSource, char* fragShaderSource,
                                      const char** outErrorMsg)
{
    try
    {
        gl::GlslProg* prog = new gl::GlslProg(vertShaderSource, fragShaderSource);
        return prog;
    }
    catch (gl::GlslProgCompileExc& exc)
    {
        *outErrorMsg = exc.what();
        return 0;
    }
}

void cinder_gl_free_shader_program(void* progPtr)
{
    gl::GlslProg* prog = static_cast<gl::GlslProg*>(progPtr);
    delete prog;
}

void cinder_gl_set_uniform_1i(void* progPtr, const char* name, int value)
{
    gl::GlslProg* prog = static_cast<gl::GlslProg*>(progPtr);
    prog->uniform(name, value);
}

void cinder_gl_set_uniform_1f(void* progPtr, const char* name, float value)
{
    gl::GlslProg* prog = static_cast<gl::GlslProg*>(progPtr);
    prog->uniform(name, value);
}

void cinder_gl_set_uniform_2f(void* progPtr, const char* name, float v1, float v2)
{
    gl::GlslProg* prog = static_cast<gl::GlslProg*>(progPtr);
    prog->uniform(name, Vec2f(v1, v2));
}

void cinder_gl_set_uniform_4f(void* progPtr, const char* name,
                              float v1, float v2, float v3, float v4)
{
    gl::GlslProg* prog = static_cast<gl::GlslProg*>(progPtr);
    prog->uniform(name, Vec4f(v1, v2, v3, v4));
}

void cinder_gl_use_shader_program(void* progPtr)
{
    if (progPtr)
    {
        gl::GlslProg* prog = static_cast<gl::GlslProg*>(progPtr);
        prog->bind();
    }
    else
    {
        gl::GlslProg::unbind();
    }
}

void* cinder_gl_create_framebuffer(int width, int height, void** texturePtr,
                                   const char** outErrorMsg)
{
    try
    {
        // TODO: support reading depth later, I suppose
        gl::Fbo* fbo = new gl::Fbo(width, height, true, true, false);
        fbo->getTexture().setFlipped(true);
        *texturePtr = &fbo->getTexture();
        return fbo;
    }
    catch (gl::FboExceptionInvalidSpecification& ex)
    {
        *outErrorMsg = ex.what();
        return 0;
    }
    catch (...)
    {
        *outErrorMsg = "error creating framebuffer";
        return 0;
    }
}

void cinder_gl_free_framebuffer(void* ptr)
{
    delete static_cast<gl::Fbo*>(ptr);
}

void cinder_gl_bind_framebuffer(void* ptr)
{
    gl::Fbo* fbo = static_cast<gl::Fbo*>(ptr);
    fbo->bindFramebuffer();
}

void cinder_gl_unbind_framebuffer()
{
    gl::Fbo::unbindFramebuffer();
}

// vector graphics stuff

void* cinder_vg_make_context(void* surfPtr)
{
    cairo::SurfaceImage* surf = static_cast<cairo::SurfaceImage*>(surfPtr);
    cairo::Context* ctx = new cairo::Context(*surf);
    return ctx;
}

void cinder_vg_free_context(void* ctxPtr)
{
    cairo::Context* ctx = static_cast<cairo::Context*>(ctxPtr);
    delete ctx;
}

void cinder_vg_set_matrix(void* ptr, float xx, float yx, float xy,
                          float yy, float x0, float y0)
{
    cairo::Context& ctx = *static_cast<cairo::Context*>(ptr);

    cairo::Matrix m(static_cast<double>(xx), static_cast<double>(yx),
                    static_cast<double>(xy), static_cast<double>(yy),
                    static_cast<double>(x0), static_cast<double>(y0));

    ctx.setMatrix(m);
}

void cinder_vg_set_solid_paint(void* ptr, float r, float g, float b, float a)
{
    cairo::Context& ctx = *static_cast<cairo::Context*>(ptr);

    ctx.setSourceRgba(static_cast<double>(r),
                      static_cast<double>(g),
                      static_cast<double>(b),
                      static_cast<double>(a));
}

void cinder_vg_set_linear_gradient(float startX, float startY,
                                   float endX, float endY,
                                   int extend)
{
    // TODO: How expensive is it to destroy/create gradients every time?
    //       (Ditto for radial)
    cinder_app->m_linearGradient =
        cairo::GradientLinear(startX, startY, endX, endY);
    cinder_app->m_linearGradient.setExtend(extend);
    cinder_app->m_activeGradient = &cinder_app->m_linearGradient;
}

void cinder_vg_set_radial_gradient(float startCenterX, float startCenterY,
                                   float startRadius,
                                   float endCenterX, float endCenterY,
                                   float endRadius,
                                   int extend)
{
    cinder_app->m_radialGradient =
        cairo::GradientRadial(startCenterX, startCenterY, startRadius,
                              endCenterX, endCenterY, endRadius);
    cinder_app->m_radialGradient.setExtend(extend);
    cinder_app->m_activeGradient = &cinder_app->m_radialGradient;
}

void cinder_vg_gradient_add_color_stop(float offset,
                                       float r, float g, float b, float a)
{
    // better hope this has been set!
    cinder_app->m_activeGradient->addColorStopRgba(static_cast<double>(offset),
                                                   static_cast<double>(r),
                                                   static_cast<double>(g),
                                                   static_cast<double>(b),
                                                   static_cast<double>(a));
}

void cinder_vg_apply_gradient(void* ptr)
{
    cairo::Context& ctx = *static_cast<cairo::Context*>(ptr);
    ctx.setSource(*cinder_app->m_activeGradient);
}

void cinder_vg_set_surface_paint(void* ptr, void* surface)
{
    cairo::Context& ctx = *static_cast<cairo::Context*>(ptr);
    cairo::SurfaceImage* surf = static_cast<cairo::SurfaceImage*>(surface);
    ctx.setSourceSurface(*surf, 0, 0);
}

void cinder_vg_set_stroke_parameters(void* ptr, 
                                     int lineCap, int lineJoin, float lineWidth)
{
    cairo::Context& ctx = *static_cast<cairo::Context*>(ptr);

    // convert from orlok's enum values to cairo's (in fact, they are
    // currently the same)

    switch(lineCap)
    {
    case 0: // butt
        ctx.setLineCap(0);
        break;
    case 1: // round
        ctx.setLineCap(1);
        break;
    case 2: // square
        ctx.setLineCap(2);
        break;
    default:
        // TODO: error?
        break;
    }

    switch(lineJoin)
    {
    case 0: // miter
        ctx.setLineJoin(0);
        break;
    case 1: // round
        ctx.setLineJoin(1);
        break;
    case 2: // bevel
        ctx.setLineJoin(2);
        break;
    default:
        // TODO: error?
        break;
    }

    ctx.setLineWidth(static_cast<double>(lineWidth));
}

void cinder_vg_clear_with_brush(void* ptr)
{
    cairo::Context& ctx = *static_cast<cairo::Context*>(ptr);
    ctx.paint();
}

void cinder_vg_draw_rect(void* ptr, float left, float top,
                         float width, float height)
{
    cairo::Context& ctx = *static_cast<cairo::Context*>(ptr);
    ctx.rectangle(left, top, width, height);
}

void cinder_vg_draw_circle(void* ptr, float centerX, float centerY, float radius)
{
    cairo::Context& ctx = *static_cast<cairo::Context*>(ptr);
    ctx.circle(centerX, centerY, radius);
}

void cinder_vg_clear_path(void* ptr)
{
    cairo::Context& ctx = *static_cast<cairo::Context*>(ptr);
    ctx.newPath();
}

void cinder_vg_path_move_to(void* ptr, float x, float y)
{
    cairo::Context& ctx = *static_cast<cairo::Context*>(ptr);
    ctx.newPath();
    ctx.moveTo(static_cast<double>(x), static_cast<double>(y));
}

void cinder_vg_path_line_to(void* ptr, float x, float y)
{
    cairo::Context& ctx = *static_cast<cairo::Context*>(ptr);
    ctx.lineTo(static_cast<double>(x), static_cast<double>(y));
}

void cinder_vg_path_quad_to(void* ptr, float x1, float y1, float x2, float y2)
{
    cairo::Context& ctx = *static_cast<cairo::Context*>(ptr);
    ctx.quadTo(static_cast<double>(x1), static_cast<double>(y1),
               static_cast<double>(x2), static_cast<double>(y2));
}

void cinder_vg_path_curve_to(void* ptr, float x1, float y1,
                             float x2, float y2, float x3, float y3)
{
    cairo::Context& ctx = *static_cast<cairo::Context*>(ptr);
    ctx.curveTo(static_cast<double>(x1), static_cast<double>(y1),
                static_cast<double>(x2), static_cast<double>(y2),
                static_cast<double>(x3), static_cast<double>(y3));
}

void cinder_vg_path_close(void* ptr)
{
    cairo::Context& ctx = *static_cast<cairo::Context*>(ptr);
    ctx.closePath();
}

/*
void cinder_set_path(int numCommands, int* commands, float* coords,
                     int closed)
{
    cairo::Context& ctx = cinder_app->m_offscreenContext;

    // Note: coords is an array of alternating x/y values. Different commands
    // will consume different numbers of coordinates.

    // first coordinates are the start point for the path
    ctx.moveTo(static_cast<double>(coords[0]),
               static_cast<double>(coords[1]));

    int nextCoord = 2;

    for(int i = 0; i < numCommands; i++)
    {
        switch(commands[i])
        {
        case 0:
            ctx.lineTo(static_cast<double>(coords[nextCoord]),
                       static_cast<double>(coords[nextCoord+1]));
            nextCoord += 2;
            break;
        case 1:
            ctx.quadTo(static_cast<double>(coords[nextCoord]),
                       static_cast<double>(coords[nextCoord+1]),
                       static_cast<double>(coords[nextCoord+2]),
                       static_cast<double>(coords[nextCoord+3]));
            nextCoord += 4;
            break;
        case 2:
            ctx.curveTo(static_cast<double>(coords[nextCoord]),
                        static_cast<double>(coords[nextCoord+1]),
                        static_cast<double>(coords[nextCoord+2]),
                        static_cast<double>(coords[nextCoord+3]),
                        static_cast<double>(coords[nextCoord+4]),
                        static_cast<double>(coords[nextCoord+5]));
            nextCoord += 6;
            break;
        default:
            // TODO: error?
            break;
        }
    }

    if (closed == 0)
    {
        ctx.closePath();
    }
}
*/

void cinder_vg_stroke_path(void* ptr)
{
    // stroke, and don't clear path
    cairo::Context& ctx = *static_cast<cairo::Context*>(ptr);
    ctx.strokePreserve();
}

void cinder_vg_fill_path(void* ptr)
{
    // fill, and don't clear path
    cairo::Context& ctx = *static_cast<cairo::Context*>(ptr);
    ctx.fillPreserve();
}

void cinder_vg_draw_text(void* ptr, void* fontPtr, char* text,
                         float x, float y, int isFill)
{
    cairo::Context& ctx = *static_cast<cairo::Context*>(ptr);
    Font& font = *static_cast<FontT*>(fontPtr)->font;

    ctx.setFont(font);
    ctx.newPath();

    ctx.save();
    ctx.translate(x, y);

    if(isFill)
    {
        // use faster showText method
        ctx.showText(text);
    }
    else
    {
        // if stroking, just generate the path and we will stroke it later
        ctx.textPath(text);
    }

    ctx.restore();
}


// Font stuff

void* cinder_load_font(char* resourceName, float size)
{
    try
    {
        FontT* f = new FontT;
        f->font = new Font(loadResource(resourceName), size);
        f->textureFont = gl::TextureFont::create(*f->font);
        return f;
    }
    catch(...)
    {
        return 0;
    }
}

void cinder_free_font(void* fontPtr)
{
    FontT* f = static_cast<FontT*>(fontPtr);
    delete f->font;
    delete f;
}


void cinder_get_font_info(void* fontPtr, const char** name, float* size,
                          float* ascent, float* descent, float* leading)
{
    Font& font = *static_cast<FontT*>(fontPtr)->font;

    *name = font.getName().c_str();
    *size = font.getSize();
    *ascent = font.getAscent();
    *descent = font.getDescent();
    *leading = font.getLeading();
}

void cinder_get_font_extents(void* fontPtr, char* text,
                             float* x, float* y, float* w, float* h)
{
    cairo::Context& ctx = cinder_app->m_fontContext;
    Font& font = *static_cast<FontT*>(fontPtr)->font;

    ctx.setFont(font);
    
    cairo::TextExtents extents = ctx.textExtents(text);

    *x = extents.xBearing();
    *y = extents.yBearing();
    *w = extents.width();
    *h = extents.height();
}

// These functions are defined in Dylan as c-callable-wrappers.

extern void cinder_startup();
extern void cinder_shutdown();
extern void cinder_update();
extern void cinder_draw();
extern void cinder_resize(int new_width, int new_height, int full_screen);
extern void cinder_key_down(int key_id);
extern void cinder_key_up(int key_id);
extern void cinder_mouse_down(int btn_id,
                              int x,
                              int y,
                              int is_left_btn_down,
                              int is_right_btn_down,
                              int is_middle_btn_down);
extern void cinder_mouse_up(int btn_id,
                            int x,
                            int y,
                            int is_left_btn_down,
                            int is_right_btn_down,
                            int is_middle_btn_down);
extern void cinder_mouse_move(int x,
                              int y,
                              int is_left_btn_down,
                              int is_right_btn_down,
                              int is_middle_btn_down);
} // extern "C"


CinderBackendApp::CinderBackendApp() :
    m_linearGradient(0, 0, 0, 0),
    m_radialGradient(0, 0, 0, 0, 0, 0),
    m_activeGradient(&m_linearGradient)
{
}

void CinderBackendApp::prepareSettings(Settings *settings)
{
    settings->setWindowSize(cinder_w, cinder_h);
    settings->setResizable(cinder_resizable);
    settings->setFullScreen(cinder_fullscreen);
}

void CinderBackendApp::setup()
{
    setFrameRate(static_cast<double>(cinder_frames_per_second));

    // Create a dummy cairo context, just for getting certain font metrics.
    cairo::SurfaceImage surf(10, 10);
    m_fontContext = cairo::Context(surf);

    gl::enableAlphaBlending();

    cinder_startup();
}

void CinderBackendApp::shutdown()
{
    cinder_shutdown();
}

void CinderBackendApp::keyDown(KeyEvent event)
{
    cinder_key_down(event.getCode());
}

void CinderBackendApp::keyUp(KeyEvent event)
{
    cinder_key_up(event.getCode());
}

void CinderBackendApp::mouseDown(MouseEvent event)
{
    int btn = event.isLeft() ? 0 : (event.isRight() ? 1 : 2);

    cinder_mouse_down(btn,
                      event.getX(),
                      event.getY(),
                      event.isLeftDown(),
                      event.isRightDown(),
                      event.isMiddleDown());
}

void CinderBackendApp::mouseUp(MouseEvent event)
{
    int btn = event.isLeft() ? 0 : (event.isRight() ? 1 : 2);

    // Note: For reasons beyond my understanding, a mouse-up event for
    // button X also claims that button X is down. Hence the logic below:
    // for an up event on X, override the isXDown() function to return the
    // correct value.

    cinder_mouse_up(btn,
                    event.getX(),
                    event.getY(),
                    event.isLeft() ? false : event.isLeftDown(),
                    event.isRight() ? false : event.isRightDown(),
                    event.isMiddle() ? false :event.isMiddleDown());
}

void CinderBackendApp::mouseMove(MouseEvent event)
{
    cinder_mouse_move(event.getX(),
                      event.getY(),
                      event.isLeftDown(),
                      event.isRightDown(),
                      event.isMiddleDown());
}

void CinderBackendApp::mouseDrag(MouseEvent event)
{
    mouseMove(event);
}

void CinderBackendApp::resize(ResizeEvent event)
{
    cinder_resize(event.getWidth(), event.getHeight(),
                  cinder_app->isFullScreen());
}

void CinderBackendApp::update()
{
    cinder_update();
}

void CinderBackendApp::draw()
{
    cinder_draw();
}

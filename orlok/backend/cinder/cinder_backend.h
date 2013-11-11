#ifndef orlok_cinder_backend_h
#define orlok_cinder_backend_h

/*
Extracted the Dylan-callable C functions from cinder_callback.cpp so that
they can be processed by Melange.
*/


/*
Using this typedef to enable automated mapping from Dylan <boolean> where
appropriate.
*/
typedef int BOOL;


/* Application setup and miscellaneous functions */

void cinder_run(int width, int height,
                int appWidth, int appHeight,
                BOOL forceAppAspectRatio,
                BOOL fullscreen,
                int frames_per_second);
void cinder_quit();
/* TODO: remove? void cinder_set_app_size(int width, int height, BOOL forceAspectRatio); */
void cinder_set_full_screen(BOOL fullscreen);
float cinder_get_average_fps();
void cinder_set_cursor_visible(BOOL visible);

/* Audio */

float cinder_audio_get_master_volume();
void cinder_audio_set_master_volume(float v);
void* cinder_audio_load_sound(const char* resourceName);
void cinder_audio_free_sound(void* soundPtr);
void cinder_audio_play_sound(void* soundPtr, float volume);
void* cinder_audio_load_music(const char* resourceName);
void cinder_audio_free_music(void* musicPtr);
void cinder_audio_play_music(void* musicPtr, BOOL loop, BOOL restart);
void cinder_audio_stop_music(void* musicPtr);
void cinder_audio_set_music_volume(void* musicPtr, float volume);
float cinder_audio_get_music_volume(void* musicPtr);

/* Surfaces (aka Bitmaps) */

void* cinder_surface_create(int width, int height);
void* cinder_load_surface(char* resourceName, int* width, int* height);
void cinder_surface_free(void* surfacePtr);
void cinder_surface_copy_pixels(void* srcPtr, int srcX, int srcY, int w, int h,
                                void* destPtr, int destX, int destY);
void cinder_surface_fill(void* ptr, float r, float g, float b, float a,
                         int x, int y, int w, int h);
void cinder_surface_premultiply(void* ptr);
void cinder_surface_unpremultiply(void* ptr);
void cinder_surface_flip_vertical(void* ptr);
void* cinder_surface_resize(void* ptr, int width, int height, int filter);

/* OpenGL Rendering */

void cinder_gl_set_viewport(int x, int y, int width, int height);
void cinder_gl_set_matrices_window(int width, int height);
void cinder_gl_set_color(float r, float g, float b, float a);
void cinder_gl_set_blend(int mode);

void* cinder_gl_create_texture(int width, int height);
void cinder_gl_free_texture(void* texPtr);
void cinder_gl_update_texture(void* texPtr, void* surfPtr,
                              int x1, int y1, int x2, int y2);
void* cinder_gl_create_texture_from_surface(void* surfPtr, int x, int y,
                                            int w, int h);
void cinder_gl_bind_texture(void* texPtr);
void cinder_gl_unbind_texture(void* texPtr);
void cinder_gl_push_modelview_matrix();
void cinder_gl_pop_modelview_matrix();
void cinder_gl_update_transform(float sx, float shy, float shx,
                                float sy, float tx, float ty);
void cinder_gl_clear(float r, float g, float b, float a, BOOL depth);
void cinder_gl_draw_rect(float x1, float y1, float x2, float y2,
                         float u1, float v1, float u2, float v2);
void cinder_gl_draw_text(char* text, float r, float g, float b, float a,
                         float x, float y, void* fontPtr);
void cinder_gl_draw_line(float x1, float y1, float x2, float y2, float width);
void* cinder_gl_load_shader_program(char* vertShader, char* fragShader,
                                    const char** outErrorMsg);
void* cinder_gl_create_shader_program(char* vertShaderSource, char* fragShaderSource,
                                      const char** outErrorMsg);
void cinder_gl_free_shader_program(void* progPtr);
void cinder_gl_set_uniform_1i(void* progPtr, const char* name, int value);
void cinder_gl_set_uniform_1f(void* progPtr, const char* name, float value);
void cinder_gl_set_uniform_2f(void* progPtr, const char* name, float v1, float v2);
void cinder_gl_set_uniform_4f(void* progPtr, const char* name,
                              float v1, float v2, float v3, float v4);
void cinder_gl_use_shader_program(void* progPtr);
void* cinder_gl_create_framebuffer(int width, int height, void** texturePtr,
                                   const char** outErrorMsg);
void cinder_gl_free_framebuffer(void* ptr);
void cinder_gl_bind_framebuffer(void* ptr);
void cinder_gl_unbind_framebuffer();

/* Vector Graphics */

void* cinder_vg_make_context(void* surfPtr);
void cinder_vg_free_context(void* ctxPtr);
void cinder_vg_set_matrix(void* ptr, float xx, float yx, float xy,
                          float yy, float x0, float y0);
void cinder_vg_set_solid_paint(void* ptr, float r, float g, float b, float a);
void cinder_vg_set_linear_gradient(float startX, float startY,
                                   float endX, float endY,
                                   int extend);
void cinder_vg_set_radial_gradient(float startCenterX, float startCenterY,
                                   float startRadius,
                                   float endCenterX, float endCenterY,
                                   float endRadius,
                                   int extend);
void cinder_vg_gradient_add_color_stop(float offset,
                                       float r, float g, float b, float a);
void cinder_vg_apply_gradient(void* ptr);
void cinder_vg_set_surface_paint(void* ptr, void* surface);
void cinder_vg_set_stroke_parameters(void* ptr, 
                                     int lineCap,
                                     int lineJoin,
                                     float lineWidth);
void cinder_vg_clear_with_brush(void* ptr);
void cinder_vg_draw_rect(void* ptr, float left, float top,
                         float width, float height);
void cinder_vg_draw_circle(void* ptr, float centerX, float centerY,
                           float radius);
void cinder_vg_clear_path(void* ptr);
void cinder_vg_path_move_to(void* ptr, float x, float y);
void cinder_vg_path_line_to(void* ptr, float x, float y);
void cinder_vg_path_quad_to(void* ptr, float x1, float y1, float x2, float y2);
void cinder_vg_path_curve_to(void* ptr, float x1, float y1,
                             float x2, float y2, float x3, float y3);
void cinder_vg_path_close(void* ptr);
void cinder_vg_stroke_path(void* ptr);
void cinder_vg_fill_path(void* ptr);
void cinder_vg_draw_text(void* ptr, void* fontPtr, char* text,
                         float x, float y, BOOL isFill);

/* Fonts */

void* cinder_load_font(char* resourceName, float size);
void cinder_free_font(void* fontPtr);
void cinder_get_font_info(void* fontPtr, const char** name, float* size,
                          float* ascent, float* descent, float* leading);
void cinder_get_font_extents(void* fontPtr, char* text,
                             float* x, float* y, float* w, float* h);

#endif


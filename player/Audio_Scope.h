// Simple audio waveform scope in a window, using SDL multimedia library

#ifndef AUDIO_SCOPE_H
#define AUDIO_SCOPE_H

#include "SDL.h"
#include "blargg_err.h"

static const int scope_err_offset = 64;

enum {
	ERR_SDL_CREATE_WINDOW = scope_err_offset,
	ERR_SDL_CREATE_RENDERER
};

static const char* const scope_errmsg[] = {
	"Couldn't create output window",
	"Couldn't create renderer for output window"
};

inline const char* scope_strerror( blargg_err_t err ) {
	return scope_errmsg[err - scope_err_offset];
}

class Audio_Scope {
public:
	// Initialize scope window of specified size. Height must be 16384 or less.
	// If result is not 0, it is an error enum value
	blargg_err_t init( int width, int height );

	// Draw at most 'count' samples from 'in', skipping 'step' samples after
	// each sample drawn. Step should be 2 but wouldn't be hard to adapt
	// to be 1.
	blargg_err_t draw( const short* in, long count, int step = 2 );

	Audio_Scope();
	~Audio_Scope();

	void set_caption( const char* caption );

private:
	typedef unsigned char byte;
	SDL_Window* window;
	SDL_Renderer* window_renderer;
	SDL_Point* scope_lines = nullptr; // lines to be drawn each frame
	int buf_size;
	int scope_height;
	int sample_shift;
	int v_offset;

	void render( short const* in, long count, int step );
};

#endif

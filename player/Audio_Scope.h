// Simple audio waveform scope in a window, using SDL multimedia library

#ifndef AUDIO_SCOPE_H
#define AUDIO_SCOPE_H

#include <SDL2/SDL_render.h>
#include <SDL2/SDL_video.h>

#include <string>

class Audio_Scope {
public:
	// Initialize scope window of specified size. Height must be 16384 or less.
	// If result is not an empty string, it is an error message
	std::string init( int width, int height );

	// Draw at most 'count' samples from 'in', skipping 'step' samples after
	// each sample drawn. Step should be 2 but wouldn't be hard to adapt
	// to be 1.
	const char* draw( const short* in, uint32_t count, int step = 2 );

	Audio_Scope();
	~Audio_Scope();

	void set_caption( const char* caption );

private:
	typedef unsigned char byte;
	SDL_Window* window;
	SDL_Renderer* window_renderer;
	SDL_Point* scope_lines = nullptr; // lines to be drawn each frame
	unsigned int buf_size;
	int scope_height;
	int sample_shift;
	int v_offset;

	void render( short const* in, uint32_t count, int step );
};

#endif

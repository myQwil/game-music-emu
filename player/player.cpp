/* How to play game music files with Music_Player (requires SDL library)

Run program with path to a game music file.

Left/Right  Change track
Space       Pause/unpause
E           Normal/slight stereo echo/more stereo echo
D           Toggle echo processing
A           Enable/disable accurate emulation
H           Show help message
L           Toggle track looping (infinite playback)
-/=         Adjust tempo
1-9         Toggle channel on/off
0           Reset tempo and turn channels back on */

// Make ISO C99 symbols available for snprintf, define must be set before any
// system header includes
#define _ISOC99_SOURCE 1

static int const scope_width = 1024;
static int const scope_height = 512;

#include "Music_Player.h"
#include "Audio_Scope.h"
#include <algorithm>

#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <SDL2/SDL.h>
#include <math.h>

static const char *usage = R"(
Left/Right  Change track
Up/Down     Seek to one second forward/backward (if possible)
Space       Pause/unpause
E           Normal/slight stereo echo/more stereo echo
D           Toggle echo processing
A           Enable/disable accurate emulation
H           Show help message
L           Toggle track looping (infinite playback)
-/=         Adjust tempo
1-9         Toggle channel on/off
0           Reset tempo and turn channels back on */
)";

static void handle_error( gme_err_t );

static bool paused;
static Audio_Scope* scope;
static Music_Player* player;
static short scope_buf [scope_width * 2];

static void init( void )
{
	// Start SDL
	if ( SDL_Init( SDL_INIT_VIDEO | SDL_INIT_AUDIO ) < 0 )
		exit( EXIT_FAILURE );
	atexit( SDL_Quit );

	// Init scope
	scope = new Audio_Scope;
	if ( !scope )
		handle_error( ERR_OUT_OF_MEMORY );
	handle_error( scope->init( scope_width, scope_height ) );
	memset( scope_buf, 0, sizeof scope_buf );

	// Create player
	player = new Music_Player;
	if ( !player )
		handle_error( ERR_OUT_OF_MEMORY );
	handle_error( player->init() );
	player->set_scope_buffer( scope_buf, scope_width * 2 );
}

static void update_window_title(  int track, const char* path, int dB )
{
	long seconds = player->track_info().length / 1000;
	const char* game = player->track_info().game;
	if ( !*game )
	{
		// extract filename
		game = strrchr( path, '\\' ); // DOS
		if ( !game )
			game = strrchr( path, '/' ); // UNIX
		if ( !game )
			game = path;
		else
			game++; // skip path separator
	}

	char decibel [12];
	if (dB <= -60)
		memcpy(decibel, "-∞", 4);
	else
		snprintf(decibel, sizeof decibel, "%+d", dB);

	char title [512];
	if ( 0 < snprintf( title, sizeof title, "%s: %d/%d %s (%ld:%02ld) %s dB",
			game, track, player->track_count(), player->track_info().song,
			seconds / 60, seconds % 60, decibel ) )
	{
		scope->set_caption( title );
	}
}

static void start_track( int track, const char* path, int dB )
{
	paused = false;
	handle_error( player->start_track( track - 1 ) );
	update_window_title( track, path, dB );
}

int main( int argc, char** argv )
{
	init();

	bool by_mem = false;
	const char* path = "test.nsf";

	for ( int i = 1; i < argc; ++i )
	{
		if ( SDL_strcmp( "-m", argv[i] ) == 0 )
			by_mem = true;
		else
			path = argv[i];
	}

	// Set volume
	int dB = -20;
	const double k = log( 10 ) / 20;
	player->set_volume( exp( k * dB ) );

	// Load file
	handle_error( player->load_file( path, by_mem ) );
	start_track( 1, path, dB );

	// Main loop
	int track = 1;
	double tempo = 1.0;
	bool running = true;
	double stereo_depth = 0.0;
	bool accurate = false;
	bool echo_disabled = false;
	bool fading_out = true;
	int muting_mask = 0;
	while ( running )
	{
		// Update scope
		scope->draw( scope_buf, scope_width, 2 );

		// Automatically go to next track when current one ends
		if ( player->track_ended() )
		{
			if ( track < player->track_count() )
				start_track( ++track, path, dB );
			else
				player->pause( paused = true );
		}

		// Handle keyboard input
		SDL_Event e;
		while ( SDL_PollEvent( &e ) )
		{
			switch ( e.type )
			{
			case SDL_QUIT:
				running = false;
				break;

			case SDL_KEYDOWN:
				int key = e.key.keysym.scancode;
				switch ( key )
				{
				case SDL_SCANCODE_Q:
				case SDL_SCANCODE_ESCAPE: // quit
					running = false;
					break;

				case SDL_SCANCODE_LEFT: // prev track
					if ( !paused && !--track )
						track = 1;
					start_track( track, path, dB );
					break;

				case SDL_SCANCODE_RIGHT: // next track
					if ( track < player->track_count() )
						start_track( ++track, path, dB );
					break;

				case SDL_SCANCODE_MINUS: // reduce tempo
					tempo -= 0.1;
					if ( tempo < 0.1 )
						tempo = 0.1;
					player->set_tempo( tempo );
					break;

				case SDL_SCANCODE_EQUALS: // increase tempo
					tempo += 0.1;
					if ( tempo > 2.0 )
						tempo = 2.0;
					player->set_tempo( tempo );
					break;

				case SDL_SCANCODE_SPACE: // toggle pause
					paused = !paused;
					player->pause( paused );
					break;

				case SDL_SCANCODE_A: // toggle accurate emulation
					accurate = !accurate;
					player->enable_accuracy( accurate );
					break;

				case SDL_SCANCODE_E: // toggle echo
					stereo_depth += 0.2;
					if ( stereo_depth > 0.5 )
						stereo_depth = 0;
					player->set_stereo_depth( stereo_depth );
					break;

				case SDL_SCANCODE_D: // toggle echo on/off
					echo_disabled = !echo_disabled;
					player->set_echo_disable(echo_disabled);
					printf( "%s\n", echo_disabled ? "SPC echo is disabled" : "SPC echo is enabled" );
					fflush( stdout );
					break;

				case SDL_SCANCODE_L: // toggle loop
					player->set_fadeout( fading_out = !fading_out );
					printf( "%s\n", fading_out ? "Will stop at track end" : "Playing forever" );
					fflush( stdout );
					break;

				case SDL_SCANCODE_0: // reset tempo and muting
					tempo = 1.0;
					muting_mask = 0;
					player->set_tempo( tempo );
					player->mute_voices( muting_mask );
					break;

				case SDL_SCANCODE_DOWN: // Volume down
					dB = std::max(-60, dB - 1);
					player->set_volume( dB <= -60 ? 0 : exp( k * dB ) );
					update_window_title( track, path, dB );
					break;

				case SDL_SCANCODE_UP: // Volume up
					dB = std::min(dB + 1, 0);
					player->set_volume( exp( k * dB ) );
					update_window_title( track, path, dB );
					break;

				case SDL_SCANCODE_H: // help
					printf( "%s\n", usage );
					fflush( stdout );
					break;

				default:
					if ( SDL_SCANCODE_1 <= key && key <= SDL_SCANCODE_9 ) // toggle muting
					{
						muting_mask ^= 1 << (key - SDL_SCANCODE_1);
						player->mute_voices( muting_mask );
					}
				}
			}
		}

		SDL_Delay( 1000 / 100 ); // Sets 'frame rate'
	}

	// Cleanup
	delete player;
	delete scope;

	return 0;
}

static void handle_error( gme_err_t err )
{
	if ( err )
	{
		// put error in window title
		const char* error = ( err < 0 )  ? SDL_GetError()
			: ( err >= arc_err_offset )   ? arc_strerror( err )
			: ( err >= scope_err_offset ) ? scope_strerror( err )
			: gme_strerror( err );

		char str [256];
		sprintf( str, "Error: %s", error );
		fprintf( stderr, "%s\n", str );
		scope->set_caption( str );

		// wait for keyboard or mouse activity
		SDL_Event e;
		do
		{
			while ( !SDL_PollEvent( &e ) ) { }
		}
		while ( e.type != SDL_QUIT && e.type != SDL_KEYDOWN && e.type != SDL_MOUSEBUTTONDOWN );

		exit( EXIT_FAILURE );
	}
}

// C++ example that opens a game music file and records 10 seconds to "out.wav"

#include "gme/Music_Emu.h"

#include "Wave_Writer.h"
#include <stdlib.h>
#include <stdio.h>

void handle_error( int );

int main(int argc, char *argv[])
{
	const char *filename = "test.nsf"; /* Default file to open */
	if ( argc >= 2 )
		filename = argv[1];

	long sample_rate = 44100; // number of samples per second
	// index of track to play (0 = first)
	int track = argc >= 3 ? atoi(argv[2]) : 0;

	// Determine file type
	gme_type_t file_type;
	handle_error( gme_identify_file( filename, &file_type ) );
	if ( !file_type )
		handle_error( "Unsupported music type" );

	// Create emulator and set sample rate
	Music_Emu* emu = file_type->new_emu();
	if ( !emu )
		handle_error( "Out of memory" );
	handle_error( emu->set_sample_rate( sample_rate ) );

	// Load music file into emulator
	handle_error( emu->load_file( filename ) );

	// Start track
	handle_error( emu->start_track( track ) );

	// Begin writing to wave file
	Wave_Writer wave( sample_rate, "out.wav" );
	wave.enable_stereo();

	// Record 10 seconds of track
	while ( emu->tell() < 10 * 1000L )
	{
		// Sample buffer
		const long size = 1024; // can be any multiple of 2
		short buf [size];

		// Fill buffer
		handle_error( emu->play( size, buf ) );

		// Write samples to wave file
		wave.write( buf, size );
	}

	// Cleanup
	delete emu;

	return 0;
}

void handle_error( int err )
{
	if ( err )
	{
		printf( "Error: %s\n", gme_strerror( err ) ); getchar();
		exit( EXIT_FAILURE );
	}
}

// YM2612 FM sound chip emulator interface

// Game_Music_Emu https://bitbucket.org/mpyne/game-music-emu/
#ifndef YM2612_EMU_H
#define YM2612_EMU_H

#include "blargg_err.h"

typedef void Ym2612_Nuked_Impl;

class Ym2612_Nuked_Emu  {
	Ym2612_Nuked_Impl* impl;
	double prev_sample_rate;
	double prev_clock_rate;
public:
	Ym2612_Nuked_Emu();
	~Ym2612_Nuked_Emu();

	// Set output sample rate and chip clock rates, in Hz. Returns non-zero
	// if error.
	blargg_err_t set_rate( double sample_rate, double clock_rate );

	// Reset to power-up state
	void reset();

	// Mute voice n if bit n (1 << n) of mask is set
	enum { channel_count = 6 };
	void mute_voices( int mask );

	// Write addr to register 0 then data to register 1
	void write0( int addr, int data );

	// Write addr to register 2 then data to register 3
	void write1( int addr, int data );

	// Run and add pair_count samples into current output buffer contents
	typedef short sample_t;
	enum { out_chan_count = 2 }; // stereo
	void run( int pair_count, sample_t* out );
};

#endif


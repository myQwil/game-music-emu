const Result = c_uint;
pub const Reader = ?*const fn (*anyopaque, *anyopaque, c_int) callconv(.C) Result;
pub const Cleanup = ?*const fn (*anyopaque) callconv(.C) void;
pub const info_only = -1;

// valgrind takes issue with std.mem.len
const strlen = @cImport({ @cInclude("string.h"); }).strlen;

/// Determine likely game music type based on first four bytes of file.
/// Returns string containing proper file suffix (i.e. "NSF", "SPC", etc.)
/// or "" if file header is not recognized.
pub fn identifyHeader(header: *const anyopaque) [:0]const u8 {
	const s = gme_identify_header(header);
	return s[0..strlen(s) :0];
}
extern fn gme_identify_header(header: *const anyopaque) [*:0]const u8;

pub const Error = error {
	AddressInvalidInit,
	AddressInvalidMusic,
	AddressInvalidPlay,
	BlipbufResize,
	DigimusicNotSupported,
	EmuInstructionIllegal,
	EndOfFile,
	FastplayValueInvalid,
	FileCantGetSize,
	FileCantOpen,
	FileCantRead,
	FileCantSeek,
	FileCorrupt,
	FileDataMissing,
	FileNotLoaded,
	FileWrongType,
	GymPackedNotSupported,
	GzCantRead,
	GzCantSeek,
	M3uPlaylistInvalid,
	M3uTrackInvalid,
	MultichannelNotSupported,
	OutOfMemory,
	PlayerTypeNotSupported,
	ReadFail,
	RomDataMissing,
	SpcEmulation,
	TrackCountInvalid,
	TrackDataMissing,
	TrackInvalid,
	TrackSingleOnly,
	UseFullEmulatorForPlayback,
	Ym2413FmNotSupported,
	NewEmu,
};

const error_list = [_]Error {
	Error.AddressInvalidInit,
	Error.AddressInvalidMusic,
	Error.AddressInvalidPlay,
	Error.BlipbufResize,
	Error.DigimusicNotSupported,
	Error.EmuInstructionIllegal,
	Error.EndOfFile,
	Error.FastplayValueInvalid,
	Error.FileCantGetSize,
	Error.FileCantOpen,
	Error.FileCantRead,
	Error.FileCantSeek,
	Error.FileCorrupt,
	Error.FileDataMissing,
	Error.FileNotLoaded,
	Error.FileWrongType,
	Error.GymPackedNotSupported,
	Error.GzCantRead,
	Error.GzCantSeek,
	Error.M3uPlaylistInvalid,
	Error.M3uTrackInvalid,
	Error.MultichannelNotSupported,
	Error.OutOfMemory,
	Error.PlayerTypeNotSupported,
	Error.ReadFail,
	Error.RomDataMissing,
	Error.SpcEmulation,
	Error.TrackCountInvalid,
	Error.TrackDataMissing,
	Error.TrackInvalid,
	Error.TrackSingleOnly,
	Error.UseFullEmulatorForPlayback,
	Error.Ym2413FmNotSupported,
};

fn toError(e: Result) Error {
	return error_list[e - 1];
}

pub const Warning = enum(c_int) {
	AddressInvalid = 1,
	AddressInvalidLoadInitPlay,
	BankDataMissing,
	BankInvalid,
	DataBadBlockSize,
	DataHeaderMissing,
	DataSizeExcessive,
	EmuInstructionIllegal,
	ExpansionHardwareNotSupported,
	FileDataBlockInvalid,
	FileDataMissing,
	FileExtraData,
	FileVersionUnknown,
	FmNotSupported,
	HeaderDataUnknown,
	M3uAtLine,
	MultipleDataNotSupported,
	ScanlineInterruptNotSupported,
	SizeInvalid,
	StreamEndEventMissing,
	StreamEventUnknown,
	TimerModeInvalid,
};

pub const Equalizer = struct {
	treble: f64,
	bass: f64,
	d2: f64,
	d3: f64,
	d4: f64,
	d5: f64,
	d6: f64,
	d7: f64,
	d8: f64,
	d9: f64,
};

pub const Type = opaque {
	const Self = @This();

	/// Create new emulator and set sample rate.
	/// Returns an error if out of memory.
	pub fn emu(self: *const Self, sample_rate: u32) Error!*Emu {
		return gme_new_emu(self, @intCast(sample_rate)) orelse Error.NewEmu;
	}
	extern fn gme_new_emu(*const Self, c_int) ?*Emu;

	/// Create new multichannel emulator and set sample rate.
	/// Returns an error if out of memory.
	pub fn emuMultiChannel(self: *const Self, sample_rate: u32) Error!*Emu {
		return gme_new_emu_multi_channel(self, @intCast(sample_rate)) orelse Error.NewEmu;
	}
	extern fn gme_new_emu_multi_channel(*const Self, c_int) ?*Emu;

	/// Create an info-only emulator.
	pub fn emuInfo(self: *const Self) !*Emu {
		return gme_new_emu(self, info_only) orelse Error.NewEmu;
	}

	/// Get corresponding music type for file path or extension passed in.
	pub fn fromExtension(path_or_extension: [*:0]const u8) ?*const Self {
		return gme_identify_extension(path_or_extension);
	}
	extern fn gme_identify_extension([*:0]const u8) ?*const Self;

	/// Get corresponding music type from a file's extension or header
	/// (if extension isn't recognized).
	/// Returns type, or null if unrecognized or error.
	pub fn fromFile(path: [*:0]const u8) Error!?*const Self {
		var type_out: ?*const Self = undefined;
		const err = gme_identify_file(path, &type_out);
		return if (err != 0) toError(err) else type_out;
	}
	extern fn gme_identify_file([*:0]const u8, *?*const Self) Result;

	/// Name of game system for this music file type.
	pub fn system(self: *const Self) [:0]const u8 {
		const s = gme_type_system(self);
		return s[0..strlen(s) :0];
	}
	extern fn gme_type_system(*const Self) [*:0]const u8;

	/// True if this music file type supports multiple tracks.
	pub fn isMultiTrack(self: *const Self) bool {
		return (gme_type_multitrack(self) != 0);
	}
	extern fn gme_type_multitrack(*const Self) c_int;

	/// Get typical file extension for a given music type.  This is not a replacement
	/// for a file content identification library (but see `identifyHeader()`).
	pub fn extension(music_type: *const Self) [:0]const u8 {
		const s = gme_type_extension(music_type);
		return s[0..strlen(s) :0];
	}
	extern fn gme_type_extension(music_type: *const Self) [*:0]const u8;

	/// Return the fixed track count of an emu file type.
	pub fn trackCount(self: *const Self) u32 {
		return @intCast(gme_fixed_track_count(self));
	}
	extern fn gme_fixed_track_count(*const Self) c_int;

	pub const ay = &gme_ay_type;
	pub const gbs = &gme_gbs_type;
	pub const gym = &gme_gym_type;
	pub const hes = &gme_hes_type;
	pub const kss = &gme_kss_type;
	pub const nsf = &gme_nsf_type;
	pub const nsfe = &gme_nsfe_type;
	pub const sap = &gme_sap_type;
	pub const spc = &gme_spc_type;
	pub const vgm = &gme_vgm_type;
	pub const vgz = &gme_vgz_type;
};

pub extern const gme_ay_type: *const Type;
pub extern const gme_gbs_type: *const Type;
pub extern const gme_gym_type: *const Type;
pub extern const gme_hes_type: *const Type;
pub extern const gme_kss_type: *const Type;
pub extern const gme_nsf_type: *const Type;
pub extern const gme_nsfe_type: *const Type;
pub extern const gme_sap_type: *const Type;
pub extern const gme_spc_type: *const Type;
pub extern const gme_vgm_type: *const Type;
pub extern const gme_vgz_type: *const Type;

pub const Info = extern struct {
	const Self = @This();

	length: c_int,
	intro_length: c_int,
	loop_length: c_int,
	play_length: c_int,
	fade_length: c_int,
	i5: c_int,
	i6: c_int,
	i7: c_int,
	i8: c_int,
	i9: c_int,
	i10: c_int,
	i11: c_int,
	i12: c_int,
	i13: c_int,
	i14: c_int,
	i15: c_int,
	system: [*:0]const u8,
	game: [*:0]const u8,
	song: [*:0]const u8,
	author: [*:0]const u8,
	copyright: [*:0]const u8,
	comment: [*:0]const u8,
	dumper: [*:0]const u8,
	s7: [*:0]const u8,
	s8: [*:0]const u8,
	s9: [*:0]const u8,
	s10: [*:0]const u8,
	s11: [*:0]const u8,
	s12: [*:0]const u8,
	s13: [*:0]const u8,
	s14: [*:0]const u8,
	s15: [*:0]const u8,

	/// Frees track information.
	pub const free = gme_free_info;
	extern fn gme_free_info(*Self) void;
};

pub const Emu = opaque {
	const Self = @This();

	/// Finish using emulator and free memory.
	pub const delete = gme_delete;
	extern fn gme_delete(*Self) void;

	/// Clear any loaded m3u playlist and any internal playlist
	/// that the music format supports (NSFE for example).
	pub const clearPlaylist = gme_clear_playlist;
	extern fn gme_clear_playlist(*Self) void;

	/// Adjust stereo echo depth, where 0.0 = off and 1.0 = maximum.
	/// Has no effect for GYM, SPC, and Sega Genesis VGM music.
	pub const setStereoDepth = gme_set_stereo_depth;
	extern fn gme_set_stereo_depth(*Self, depth: f64) void;

	/// Adjust song tempo, where 1.0 = normal, 0.5 = half speed, 2.0 = double speed.
	/// Track length as returned by `trackInfo()` assumes a tempo of 1.0.
	pub const setTempo = gme_set_tempo;
	extern fn gme_set_tempo(*Self, tempo: f64) void;

	/// Get current frequency equalizater parameters.
	pub const equalizer = gme_equalizer;
	extern fn gme_equalizer(*const Self, out: *Equalizer) void;

	/// Change frequency equalizer parameters.
	pub const setEqualizer = gme_set_equalizer;
	extern fn gme_set_equalizer(*Self, eq: *const Equalizer) void;

	/// Type of this emulator.
	pub const toType = gme_type;
	extern fn gme_type(*const Self) *const Type;

	/// Set pointer to data you want to associate with this emulator.
	/// You can use this for whatever you want.
	pub const setUserData = gme_set_user_data;
	extern fn gme_set_user_data(*Self, new_user_data: *anyopaque) void;

	/// Get pointer to user data associated with this emulator.
	pub const userData = gme_user_data;
	extern fn gme_user_data(*const Self) ?*anyopaque;

	/// Register cleanup function to be called when deleting emulator,
	/// or `null` to clear it. Passes user_data to cleanup function.
	pub const setUserCleanup = gme_set_user_cleanup;
	extern fn gme_set_user_cleanup(*Self, func: Cleanup) void;

	/// Returns an emulator with game music file/data loaded into it.
	pub fn fromFile(path: [*:0]const u8, srate: i32) Error!*Self {
		var self: ?*Self = null;
		const err = gme_open_file(path, &self, @intCast(srate));
		return if (err != 0) toError(err) else self.?;
	}
	extern fn gme_open_file([*:0]const u8, *?*Self, c_int) Result;

	/// Same as `fromFile()`, but uses file data already in memory. Makes copy of data.
	pub fn fromData(data: []const anyopaque, srate: i32) Error!*Self {
		var self: ?*Self = null;
		const err = gme_open_data(data.ptr, data.len, &self, @intCast(srate));
		return if (err != 0) toError(err) else self.?;
	}
	extern fn gme_open_data(*const anyopaque, c_long, *?*Self, c_int) Result;

	/// Number of tracks available.
	pub fn trackCount(self: *const Self) u32 {
		return @intCast(gme_track_count(self));
	}
	extern fn gme_track_count(*const Self) c_int;

	/// Start a track, where 0 is the first track.
	pub fn startTrack(self: *Self, index: u32) Error!void {
		const err = gme_start_track(self, @intCast(index));
		if (err != 0)
			return toError(err);
	}
	extern fn gme_start_track(*Self, c_int) Result;

	/// Generate 16-bit signed samples into `out`. Output is in stereo.
	pub fn play(self: *Self, out: []i16) Error!void {
		const err = gme_play(self, @intCast(out.len), @ptrCast(out.ptr));
		if (err != 0)
			return toError(err);
	}
	extern fn gme_play(*Self, c_int, [*]c_short) Result;

	/// Set fade-out start time and duration. Once fade ends `trackEnded()` returns true.
	/// Fade time can be changed while track is playing.
	pub fn setFade(self: *Self, start_msec: i32, length_msec: u32) void {
		gme_set_fade_msecs(self, @intCast(start_msec), @intCast(length_msec));
	}
	extern fn gme_set_fade_msecs(*Self, c_int, c_int) void;

	/// Set time to start fading track out. Once fade ends `trackEnded()` returns true.
	/// Fade time can be changed while track is playing.
	pub fn setFadeStart(self: *Self, start_msec: u32) void {
		gme_set_fade(self, @intCast(start_msec));
	}
	extern fn gme_set_fade(*Self, c_int) void;

	/// If true, then automatically load track length
	/// metadata (if present) and terminate playback once the track length has been
	/// reached. Otherwise playback will continue for an arbitrary period of time
	/// until a prolonged period of silence is detected.
	///
	/// Not all individual emulators support this setting.
	///
	/// By default, playback limits are loaded and applied.
	pub fn setAutoloadPlaybackLimit(self: *Self, state: bool) void {
		gme_set_autoload_playback_limit(self, @intFromBool(state));
	}
	extern fn gme_set_autoload_playback_limit(*Self, c_int) void;

	/// Get the state of autoload playback limit. See `setAutoloadPlaybackLimit()`.
	pub fn autoloadPlaybackLimit(self: *const Self) bool {
		return (gme_autoload_playback_limit(self) != 0);
	}
	extern fn gme_autoload_playback_limit(*const Self) c_int;

	/// True if a track has reached its end.
	pub fn trackEnded(self: *const Self) bool {
		return (gme_track_ended(self) != 0);
	}
	extern fn gme_track_ended(*const Self) c_int;

	/// Number of milliseconds (1000 = one second) played since beginning of track.
	pub fn tell(self: *const Self) u32 {
		return @intCast(gme_tell(self));
	}
	extern fn gme_tell(*const Self) c_int;

	/// Number of samples generated since beginning of track.
	pub fn tellSamples(self: *const Self) u32 {
		return @intCast(gme_tell_samples(self));
	}
	extern fn gme_tell_samples(*const Self) c_int;

	/// Seek to new time in track. Seeking backwards or far forward can take a while.
	pub fn seek(self: *Self, msec: u32) Error!void {
		const err = gme_seek(self, @intCast(msec));
		if (err != 0)
			return toError(err);
	}
	extern fn gme_seek(*Self, c_int) Result;

	/// Equivalent to restarting track then skipping n samples
	pub fn seekSamples(self: *Self, samples: u32) Error!void {
		const err = gme_seek_samples(self, @intCast(samples));
		if (err != 0)
			return toError(err);
	}
	extern fn gme_seek_samples(*Self, c_int) Result;

	/// Most recent warning string, or null if none.
	/// Clears current warning after returning.
	/// Warning is also cleared when loading a file and starting a track.
	pub fn warning(self: *Self) ?[:0]const u8 {
		const warn = gme_warning(self);
		return if (warn) |s| s[0..strlen(s)] else null;
	}
	extern fn gme_warning(*Self) ?[*:0]const u8;

	/// Load m3u playlist file (must be done after loading music).
	pub fn loadM3u(self: *Self, path: [*:0]const u8) Error!void {
		const err = gme_load_m3u(self, path);
		if (err != 0)
			return toError(err);
	}
	extern fn gme_load_m3u(*Self, [*:0]const u8) Result;

	/// Gets information for a particular track (length, name, author, etc.).
	/// Must be freed after use.
	pub fn trackInfo(self: *const Self, track: u32) Error!*Info {
		var info: ?*Info = null;
		const err = gme_track_info(self, &info, @intCast(track));
		return if (err != 0) toError(err) else info.?;
	}
	extern fn gme_track_info(*const Self, *?*Info, c_int) Result;

	/// Disable automatic end-of-track detection and skipping of silence at beginning.
	pub fn ignoreSilence(self: *Self, ignore: bool) void {
		gme_ignore_silence(self, @intFromBool(ignore));
	}
	extern fn gme_ignore_silence(*Self, c_int) void;

	/// Number of voices used by currently loaded file.
	pub fn voiceCount(self: *const Self) u32 {
		return @intCast(gme_voice_count(self));
	}
	extern fn gme_voice_count(*const Self) c_int;

	/// Name of voice i, from 0 to `voiceCount()` - 1
	pub fn voiceName(self: *const Self, i: u32) [:0]const u8 {
		const s = gme_voice_name(self, @intCast(i));
		return s[0..strlen(s)];
	}
	extern fn gme_voice_name(*const Self, c_int) [*:0]const u8;

	pub fn muteVoice(self: *Self, index: u32, mute: bool) void {
		gme_mute_voice(self, @intCast(index), @intFromBool(mute));
	}
	extern fn gme_mute_voice(*Self, c_int, c_int) void;

	/// Mute/unmute voice i, where voice 0 is first voice.
	pub fn muteVoices(self: *Self, muting_mask: u32) void {
		gme_mute_voices(self, @intCast(muting_mask));
	}
	extern fn gme_mute_voices(*Self, c_uint) void;

	/// Disable/Enable echo effect for SPC files.
	pub fn disableEcho(self: *Self, disable: bool) void {
		gme_disable_echo(self, @intFromBool(disable));
	}
	extern fn gme_disable_echo(*Self, c_int) void;

	/// Enables/disables most accurate sound emulation options.
	pub fn enableAccuracy(self: *Self, enable: bool) void {
		gme_enable_accuracy(self, @intFromBool(enable));
	}
	extern fn gme_enable_accuracy(*Self, c_int) void;

	/// whether the pcm output retrieved by gme_play() will have all 8 voices
	/// rendered to their individual stereo channel or (if false) these voices
	/// get mixed into one single stereo channel.
	pub fn isMultiChannel(self: *const Self) bool {
		return (gme_multi_channel(self) != 0);
	}
	extern fn gme_multi_channel(*const Self) c_int;

	/// Load music file into emulator.
	pub fn loadFile(self: *Self, path: [*:0]const u8) Error!void {
		const err = gme_load_file(self, path);
		if (err != 0)
			return toError(err);
	}
	extern fn gme_load_file(*Self, [*:0]const u8) Result;

	/// Load music file from memory into emulator. Makes a copy of data passed.
	pub fn loadData(self: *Self, data: []const u8) Error!void {
		const err = gme_load_data(self, data.ptr, @intCast(data.len));
		if (err != 0)
			return toError(err);
	}
	extern fn gme_load_data(*Self, *const anyopaque, c_long) Result;

	/// Load multiple single-track music files from memory into emulator.
	pub fn loadTracks(self: *Self, data: [*]const u8, sizes: []usize) Error!void {
		const err = gme_load_tracks(self, data, @ptrCast(sizes.ptr), @intCast(sizes.len));
		if (err != 0)
			return toError(err);
	}
	extern fn gme_load_tracks(*Self, [*]const u8, [*]c_long, c_uint) Result;

	/// Load music file using custom data reader function that will be called to
	/// read file data. Most emulators load the entire file in one read call.
	pub fn loadCustom(self: *Self, func: Reader, data: []anyopaque) Error!void {
		const err = gme_load_custom(self, func, data.len, data.ptr);
		if (err != 0)
			return toError(err);
	}
	extern fn gme_load_custom(*Self, Reader, c_long, *anyopaque) Result;

	/// Load m3u playlist file from memory (must be done after loading music).
	pub fn loadM3uData(self: *Self, data: []const anyopaque) Error!void {
		const err = gme_load_m3u_data(self, data.ptr, data.len);
		if (err != 0)
			return toError(err);
	}
	extern fn gme_load_m3u_data(*Self, *const anyopaque, c_long) Result;
};

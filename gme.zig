const std = @import("std");

pub const Reader = ?*const fn (
	in: [*]u8,
	out: [*]u8,
	count: c_int
) callconv(.c) c_uint;

pub const Cleanup = ?*const fn (user_data: *anyopaque) callconv(.c) void;

/// Determine likely game music type based on first four bytes of file.
/// Returns string containing proper file suffix (i.e. "NSF", "SPC", etc.)
/// or "" if file header is not recognized.
pub const identifyHeader = gme_identify_header;
extern fn gme_identify_header(header: [*]const u8) [*:0]const u8;

const err_offset = 1;
const warn_offset = 1;

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

inline fn wrap(result: c_uint) Error!void {
	const success = 0;
	if (result != success) {
		return error_list[result - err_offset];
	}
}

/// Convert the error number into a string.
pub fn strError(err: Error) ?[*:0]const u8 {
	for (0..error_list.len) |i| {
		if (error_list[i] == err) {
			return gme_strerror(@intCast(i + err_offset));
		}
	}
	return null;
}
extern fn gme_strerror(c_uint) ?[*:0]const u8;

pub const Warning = enum(c_uint) {
	AddressInvalid = warn_offset,
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

pub const strWarn = gme_strwarn;
extern fn gme_strwarn(Warning) ?[*:0]const u8;

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
	pub const emu = Emu.init;
	pub const emuInfo = Emu.initInfo;
	pub const emuMultiChannel = Emu.initMultiChannel;

	/// Get corresponding music type for file path or extension passed in.
	pub const fromExtension = gme_identify_extension;
	extern fn gme_identify_extension([*:0]const u8) ?*const Type;

	/// Get corresponding music type from a file's extension or header
	/// (if extension isn't recognized).
	/// Returns type, or null if unrecognized, or error.
	pub fn fromFile(path: [*:0]const u8) Error!?*const Type {
		var type_out: ?*const Type = undefined;
		try wrap(gme_identify_file(path, &type_out));
		return type_out;
	}
	extern fn gme_identify_file([*:0]const u8, *?*const Type) c_uint;

	/// Name of game system for this music file type.
	pub const system = gme_type_system;
	extern fn gme_type_system(*const Type) [*:0]const u8;

	/// True if this music file type supports multiple tracks.
	pub fn isMultiTrack(self: *const Type) bool {
		return (gme_type_multitrack(self) != 0);
	}
	extern fn gme_type_multitrack(*const Type) c_uint;

	/// Get typical file extension for a given music type.  This is not a replacement
	/// for a file content identification library (but see `identifyHeader()`).
	pub const extension = gme_type_extension;
	extern fn gme_type_extension(*const Type) [*:0]const u8;

	/// Return the fixed track count of an emu file type.
	pub const trackCount = gme_fixed_track_count;
	extern fn gme_fixed_track_count(*const Type) c_uint;

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

pub const emu = Emu.init;
pub const emuInfo = Emu.initInfo;
pub const emuMultiChannel = Emu.initMultiChannel;

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

	/// Gets information for a particular track (length, name, author, etc.).
	/// Must be freed after use.
	pub fn init(em: *const Emu, track: c_uint) Error!*Info {
		var info: ?*Info = null;
		try wrap(gme_track_info(em, &info, track));
		return info.?;
	}
	extern fn gme_track_info(*const Emu, *?*Info, c_uint) c_uint;

	/// Frees track information.
	pub const deinit = gme_free_info;
	extern fn gme_free_info(*Info) void;
};

pub const Emu = opaque {
	pub const trackInfo = Info.init;

	/// Create new emulator and set sample rate.
	/// Returns an error if out of memory.
	pub fn init(self: *const Type, sample_rate: c_uint) Error!*Emu {
		return gme_new_emu(self, @intCast(sample_rate)) orelse Error.NewEmu;
	}
	extern fn gme_new_emu(*const Type, c_int) ?*Emu;

	/// Create new multichannel emulator and set sample rate.
	/// Returns an error if out of memory.
	pub fn initMultiChannel(self: *const Type, sample_rate: c_uint) Error!*Emu {
		return gme_new_emu_multi_channel(self, sample_rate) orelse Error.NewEmu;
	}
	extern fn gme_new_emu_multi_channel(*const Type, c_uint) ?*Emu;

	/// Create an info-only emulator.
	pub fn initInfo(self: *const Type) Error!*Emu {
		return gme_new_emu(self, -1) orelse Error.NewEmu;
	}

	/// Finish using emulator and free memory.
	pub const deinit = gme_delete;
	extern fn gme_delete(*Emu) void;

	/// Clear any loaded m3u playlist and any internal playlist
	/// that the music format supports (NSFE for example).
	pub const clearPlaylist = gme_clear_playlist;
	extern fn gme_clear_playlist(*Emu) void;

	/// Adjust stereo echo depth, where 0.0 = off and 1.0 = maximum.
	/// Has no effect for GYM, SPC, and Sega Genesis VGM music.
	pub const setStereoDepth = gme_set_stereo_depth;
	extern fn gme_set_stereo_depth(*Emu, depth: f64) void;

	/// Adjust song tempo, where 1.0 = normal, 0.5 = half speed, 2.0 = double speed.
	/// Track length as returned by `trackInfo()` assumes a tempo of 1.0.
	pub const setTempo = gme_set_tempo;
	extern fn gme_set_tempo(*Emu, tempo: f64) void;

	/// Get current frequency equalizater parameters.
	pub const equalizer = gme_equalizer;
	extern fn gme_equalizer(*const Emu, out: *Equalizer) void;

	/// Change frequency equalizer parameters.
	pub const setEqualizer = gme_set_equalizer;
	extern fn gme_set_equalizer(*Emu, eq: *const Equalizer) void;

	/// Type of this emulator.
	pub const toType = gme_type;
	extern fn gme_type(*const Emu) *const Type;

	/// Set pointer to data you want to associate with this emulator.
	/// You can use this for whatever you want.
	pub const setUserData = gme_set_user_data;
	extern fn gme_set_user_data(*Emu, new_user_data: *anyopaque) void;

	/// Get pointer to user data associated with this emulator.
	pub const userData = gme_user_data;
	extern fn gme_user_data(*const Emu) ?*anyopaque;

	/// Register cleanup function to be called when deleting emulator,
	/// or `null` to clear it. Passes user_data to cleanup function.
	pub const setUserCleanup = gme_set_user_cleanup;
	extern fn gme_set_user_cleanup(*Emu, func: Cleanup) void;

	/// Returns an emulator with game music file/data loaded into it.
	pub fn fromFile(path: [*:0]const u8, samplerate: c_uint) Error!*Emu {
		var self: ?*Emu = null;
		try wrap(gme_open_file(path, &self, samplerate));
		return self.?;
	}
	extern fn gme_open_file([*:0]const u8, *?*Emu, c_uint) c_uint;

	/// Same as `fromFile()`, but uses file data already in memory. Makes copy of data.
	pub fn fromData(data: []const u8, samplerate: c_uint) Error!*Emu {
		var self: ?*Emu = null;
		try wrap(gme_open_data(data.ptr, data.len, &self, samplerate));
		return self.?;
	}
	extern fn gme_open_data(*const u8, c_ulong, *?*Emu, c_uint) c_uint;

	/// Number of tracks available.
	pub const trackCount = gme_track_count;
	extern fn gme_track_count(*const Emu) c_uint;

	/// Start a track, where 0 is the first track.
	pub fn startTrack(self: *Emu, index: c_uint) Error!void {
		try wrap(gme_start_track(self, index));
	}
	extern fn gme_start_track(*Emu, c_uint) c_uint;

	/// Generate 16-bit signed samples into `out`. Output is in stereo.
	pub fn play(self: *Emu, out: []i16) Error!void {
		try wrap(gme_play(self, @intCast(out.len), @ptrCast(out.ptr)));
	}
	extern fn gme_play(*Emu, c_uint, [*]c_short) c_uint;

	/// Set fade-out start time and duration. Once fade ends `trackEnded()` returns true.
	/// Fade time can be changed while track is playing.
	/// Set `start_msec` to -1 to prevent fading and play forever
	pub const setFade = gme_set_fade_msecs;
	extern fn gme_set_fade_msecs(*Emu, start_msec: c_int, length_msec: c_uint) void;

	/// Set time to start fading track out. Once fade ends `trackEnded()` returns true.
	/// Fade time can be changed while track is playing.
	/// Set `start_msec` to -1 to prevent fading and play forever
	pub const setFadeStart = gme_set_fade;
	extern fn gme_set_fade(*Emu, c_int) void;

	/// If true, then automatically load track length
	/// metadata (if present) and terminate playback once the track length has been
	/// reached. Otherwise playback will continue for an arbitrary period of time
	/// until a prolonged period of silence is detected.
	///
	/// Not all individual emulators support this setting.
	///
	/// By default, playback limits are loaded and applied.
	pub fn setAutoloadPlaybackLimit(self: *Emu, state: bool) void {
		gme_set_autoload_playback_limit(self, @intFromBool(state));
	}
	extern fn gme_set_autoload_playback_limit(*Emu, c_uint) void;

	/// Get the state of autoload playback limit. See `setAutoloadPlaybackLimit()`.
	pub fn autoloadPlaybackLimit(self: *const Emu) bool {
		return (gme_autoload_playback_limit(self) != 0);
	}
	extern fn gme_autoload_playback_limit(*const Emu) c_uint;

	/// True if a track has reached its end.
	pub fn trackEnded(self: *const Emu) bool {
		return (gme_track_ended(self) != 0);
	}
	extern fn gme_track_ended(*const Emu) c_uint;

	/// Number of milliseconds (1000 = one second) played since beginning of track.
	pub const tell = gme_tell;
	extern fn gme_tell(*const Emu) c_uint;

	/// Number of samples generated since beginning of track.
	pub const tellSamples = gme_tell_samples;
	extern fn gme_tell_samples(*const Emu) c_uint;

	/// Seek to new time in track. Seeking backwards or far forward can take a while.
	pub fn seek(self: *Emu, msec: c_uint) Error!void {
		try wrap(gme_seek(self, msec));
	}
	extern fn gme_seek(*Emu, c_uint) c_uint;

	/// Equivalent to restarting track then skipping n samples
	pub fn seekSamples(self: *Emu, samples: c_uint) Error!void {
		try wrap(gme_seek_samples(self, samples));
	}
	extern fn gme_seek_samples(*Emu, c_uint) c_uint;

	/// Seek to new time in track (scaled with tempo).
	pub fn seekScaled(self: *Emu, msec: c_uint) Error!void {
		try wrap(gme_seek_scaled(self, msec));
	}
	extern fn gme_seek_scaled(*Emu, c_uint) c_uint;

	/// Most recent warning string, or null if none.
	/// Clears current warning after returning.
	/// Warning is also cleared when loading a file and starting a track.
	pub const warning = gme_warning;
	extern fn gme_warning(*Emu) Warning;

	/// Load m3u playlist file (must be done after loading music).
	pub fn loadM3u(self: *Emu, path: [*:0]const u8) Error!void {
		try wrap(gme_load_m3u(self, path));
	}
	extern fn gme_load_m3u(*Emu, [*:0]const u8) c_uint;

	/// Disable automatic end-of-track detection and skipping of silence at beginning.
	pub fn ignoreSilence(self: *Emu, ignore: bool) void {
		gme_ignore_silence(self, @intFromBool(ignore));
	}
	extern fn gme_ignore_silence(*Emu, c_uint) void;

	/// Number of voices used by currently loaded file.
	pub const voiceCount = gme_voice_count;
	extern fn gme_voice_count(*const Emu) c_uint;

	/// Name of voice i, from 0 to `voiceCount()` - 1
	pub const voiceName = gme_voice_name;
	extern fn gme_voice_name(*const Emu, c_uint) [*:0]const u8;

	pub fn muteVoice(self: *Emu, index: c_uint, mute: bool) void {
		gme_mute_voice(self, index, @intFromBool(mute));
	}
	extern fn gme_mute_voice(*Emu, c_uint, c_uint) void;

	/// Mute/unmute voice i, where voice 0 is first voice.
	pub const muteVoices = gme_mute_voices;
	extern fn gme_mute_voices(*Emu, muting_mask: c_uint) void;

	/// Disable/Enable echo effect for SPC files.
	pub fn disableEcho(self: *Emu, disable: bool) void {
		gme_disable_echo(self, @intFromBool(disable));
	}
	extern fn gme_disable_echo(*Emu, c_uint) void;

	/// Enables/disables most accurate sound emulation options.
	pub fn enableAccuracy(self: *Emu, enable: bool) void {
		gme_enable_accuracy(self, @intFromBool(enable));
	}
	extern fn gme_enable_accuracy(*Emu, c_uint) void;

	/// whether the pcm output retrieved by gme_play() will have all 8 voices
	/// rendered to their individual stereo channel or (if false) these voices
	/// get mixed into one single stereo channel.
	pub fn isMultiChannel(self: *const Emu) bool {
		return (gme_multi_channel(self) != 0);
	}
	extern fn gme_multi_channel(*const Emu) c_uint;

	/// Load music file into emulator.
	pub fn loadFile(self: *Emu, path: [*:0]const u8) Error!void {
		try wrap(gme_load_file(self, path));
	}
	extern fn gme_load_file(*Emu, [*:0]const u8) c_uint;

	/// Load music file from memory into emulator. Makes a copy of data passed.
	pub fn loadData(self: *Emu, data: []const u8) Error!void {
		try wrap(gme_load_data(self, data.ptr, @intCast(data.len)));
	}
	extern fn gme_load_data(*Emu, [*]const u8, c_ulong) c_uint;

	/// Load multiple single-track music files from memory into emulator.
	pub fn loadTracks(
		self: *Emu,
		data: [*]const u8,
		sizes: []c_ulong,
	) Error!void {
		try wrap(gme_load_tracks(self, data, sizes.ptr, @intCast(sizes.len)));
	}
	extern fn gme_load_tracks(*Emu, [*]const u8, [*]c_ulong, c_uint) c_uint;

	/// Load music file using custom data reader function that will be called to
	/// read file data. Most emulators load the entire file in one read call.
	pub fn loadCustom(self: *Emu, func: Reader, data: []u8) Error!void {
		try wrap(gme_load_custom(self, func, data.len, data.ptr));
	}
	extern fn gme_load_custom(*Emu, Reader, c_ulong, [*]u8) c_uint;

	/// Load m3u playlist file from memory (must be done after loading music).
	pub fn loadM3uData(self: *Emu, data: []const u8) Error!void {
		try wrap(gme_load_m3u_data(self, data.ptr, @intCast(data.len)));
	}
	extern fn gme_load_m3u_data(*Emu, [*]const u8, c_ulong) c_uint;
};

//! opens a game music file and records 10 seconds to "out.wav"
const std = @import("std");
const gme = @import("gme");

const header_size = 44;
const duration_secs = 10;
const channel_count = 2;
const sample_rate = 48000;

const Sample = i16;

pub fn main(init: std.process.Init) !void {
	const arena: std.mem.Allocator = init.arena.allocator();
	const args = try init.minimal.args.toSlice(arena);

	const filename = if (args.len > 1) args[1] else "test.nsf";
	const track = if (args.len > 2) try std.fmt.parseInt(u32, args[2], 10) else 0;

	// Open music file in new emulator
	const emu = try gme.Emu.fromFile(filename.ptr, sample_rate);
	defer emu.deinit();

	// Start track
	try emu.startTrack(track);

	// Create buffer
	const buf_size = 4000;
	var buf: [buf_size]Sample = undefined;
	const bytes = @as([*]u8, @ptrCast(&buf))[0..buf_size * @sizeOf(Sample)];

	// Create a wave file
	const io = init.io;
	const file = try std.Io.Dir.cwd().createFile(io, "out.wav", .{});
	defer file.close(io);

	var wbuf: [1024]u8 = undefined;
	var w = file.writer(io, &wbuf);

	// Record 10 seconds of track
	try w.seekTo(header_size);
	const total_samples = duration_secs * channel_count * sample_rate;
	while (emu.tellSamples() < total_samples) {
		try emu.play(&buf);
		try w.interface.writeAll(bytes);
	}

	// Write the header
	try w.seekTo(0);
	const data_size = emu.tellSamples() * @sizeOf(Sample);
	const file_size = header_size + data_size - 8;
	const frame_size = channel_count * @sizeOf(Sample);
	const bytes_per_second = sample_rate * frame_size;

	try w.interface.writeAll("RIFF");
	try w.interface.writeInt(u32, file_size, .little);
	try w.interface.writeAll("WAVE");

	try w.interface.writeAll("fmt ");
	try w.interface.writeInt(u32, 16, .little); // size of section following this number
	try w.interface.writeInt(u16, 1, .little); // 1 = PCM
	try w.interface.writeInt(u16, channel_count, .little);
	try w.interface.writeInt(u32, sample_rate, .little);
	try w.interface.writeInt(u32, bytes_per_second, .little);
	try w.interface.writeInt(u16, frame_size, .little);
	try w.interface.writeInt(u16, @bitSizeOf(Sample), .little);

	try w.interface.writeAll("data");
	try w.interface.writeInt(u32, data_size, .little);
	try w.interface.flush();
}

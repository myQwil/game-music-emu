//! opens a game music file and records 10 seconds to "out.wav"
const std = @import("std");
const gme = @import("gme");

const header_size = 44;
const duration_secs = 10;
const channel_count = 2;
const sample_rate = 48000;

const Sample = i16;

pub fn main() !void {
	var args = std.process.args();
	_ = args.skip();
	const filename = args.next() orelse "test.nsf";
	const track = if (args.next()) |arg| try std.fmt.parseInt(u32, arg, 10) else 0;

	// Open music file in new emulator
	const emu = try gme.Emu.fromFile(filename.ptr, sample_rate);
	defer emu.deinit();

	// Start track
	try emu.startTrack(track);

	// Create a wave file
	const file = try std.fs.cwd().createFile("out.wav", .{});
	defer file.close();
	const writer = file.writer();

	// Create buffer
	const buf_size = 4000;
	var buf: [buf_size]Sample = undefined;
	const bytes = @as([*]u8, @ptrCast(&buf))[0..buf_size * @sizeOf(Sample)];

	// Record 10 seconds of track
	try file.seekTo(header_size);
	const total_samples = duration_secs * channel_count * sample_rate;
	while (emu.tellSamples() < total_samples) {
		try emu.play(&buf);
		try writer.writeAll(bytes);
	}

	// Write the header
	try file.seekTo(0);
	const data_size = emu.tellSamples() * @sizeOf(Sample);
	const file_size = header_size + data_size - 8;
	const frame_size = channel_count * @sizeOf(Sample);
	const bytes_per_second = sample_rate * frame_size;

	try writer.writeAll("RIFF");
	try writer.writeInt(u32, file_size, .little);
	try writer.writeAll("WAVE");

	try writer.writeAll("fmt ");
	try writer.writeInt(u32, 16, .little); // size of section following this number
	try writer.writeInt(u16, 1, .little); // 1 = PCM
	try writer.writeInt(u16, channel_count, .little);
	try writer.writeInt(u32, sample_rate, .little);
	try writer.writeInt(u32, bytes_per_second, .little);
	try writer.writeInt(u16, frame_size, .little);
	try writer.writeInt(u16, @bitSizeOf(Sample), .little);

	try writer.writeAll("data");
	try writer.writeInt(u32, data_size, .little);
}

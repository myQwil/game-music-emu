const std = @import("std");
const LinkMode = std.builtin.LinkMode;

const Ym2612Emu = enum {
	mame,
	nuked,
	gens,
};

const Options = struct {
	// Default emulators to build (all of them! ;)
	ay: bool = true,
	gbs: bool = true,
	gym: bool = true,
	hes: bool = true,
	kss: bool = true,
	nsf: bool = true,
	nsfe: bool = true,
	sap: bool = true,
	spc: bool = true,
	vgm: bool = true,

	linkage: LinkMode = .static,
	ym2612_emu: Ym2612Emu = .mame,
	spc_isolated_echo_buffer: bool = false,
};

fn addSteps(
	b: *std.Build, exe: *std.Build.Step.Compile, name: []const u8, desc: []const u8,
) void {
	const install = b.addInstallArtifact(exe, .{});
	const step_install = b.step(name, b.fmt("Build {s}", .{desc}));
	step_install.dependOn(&install.step);

	const run = b.addRunArtifact(exe);
	run.step.dependOn(&install.step);
	const step_run = b.step(
		b.fmt("run_{s}", .{name}), b.fmt("Build and run {s}", .{desc}) );
	step_run.dependOn(&run.step);
	if (b.args) |args| {
		run.addArgs(args);
	}
}

pub fn build(b: *std.Build) !void {
	const target = b.standardTargetOptions(.{});
	const optimize = b.standardOptimizeOption(.{});

	const defaults = Options{};
	var opt = Options{
		.ay = b.option(bool, "ay",
			"Enable support for Spectrum ZX music emulation") orelse defaults.ay,
		.gbs = b.option(bool, "gbs",
			"Enable support for Game Boy music emulation") orelse defaults.gbs,
		.gym = b.option(bool, "gym",
			"Enable Sega MegaDrive/Genesis music emulation") orelse defaults.gym,
		.hes = b.option(bool, "hes",
			"Enable PC Engine/TurboGrafx-16 music emulation") orelse defaults.hes,
		.kss = b.option(bool, "kss",
			"Enable MSX or other Z80 systems music emulation") orelse defaults.kss,
		.nsf = b.option(bool, "nsf",
			"Enable NES NSF music emulation") orelse defaults.nsf,
		.nsfe = b.option(bool, "nsfe",
			"Enable NES NSFE and NSF music emulation") orelse defaults.nsfe,
		.sap = b.option(bool, "sap",
			"Enable Atari SAP music emulation") orelse defaults.sap,
		.spc = b.option(bool, "spc",
			"Enable SNES SPC music emulation") orelse defaults.spc,
		.vgm = b.option(bool, "vgm",
			"Enable Sega VGM/VGZ music emulation") orelse defaults.vgm,
		.linkage = b.option(LinkMode, "linkage",
			"Library linking method") orelse defaults.linkage,
		.ym2612_emu = b.option(Ym2612Emu, "ym2612_emu",
			"Which YM2612 emulator to use.") orelse defaults.ym2612_emu,
		.spc_isolated_echo_buffer = b.option(bool, "spc_isolated_echo_buffer",
			"Enable isolated echo buffer on SPC emulator to allow correct playing of " ++
			"\"dodgy\" SPC files made for various ROM hacks ran on ZSNES")
			orelse defaults.spc_isolated_echo_buffer,
	};

	if (opt.nsfe and !opt.nsf) {
		std.debug.print("NSFE support requires NSF, enabling NSF support.\n", .{});
		opt.nsf = true;
	}

	const gme = b.addLibrary(.{
		.name = "gme",
		.linkage = opt.linkage,
		.root_module = b.createModule(.{
			.target = target,
			.optimize = optimize,
			.link_libcpp = true,
		}),
	});

	gme.linkLibrary(b.dependency("zlib",
		.{ .target = target, .optimize = optimize, }).artifact("z"));
	gme.root_module.addCMacro("HAVE_ZLIB_H", "1");

	const gme_src = "gme/";
	var files = std.ArrayList([]const u8).init(b.allocator);
	defer files.deinit();
	for ([_][]const u8{
		"Blip_Buffer", "Classic_Emu", "Data_Reader", "Dual_Resampler", "Effects_Buffer",
		"Fir_Resampler", "gme", "Gme_File", "M3u_Playlist", "Multi_Buffer", "Music_Emu",
	}) |s|
		try files.append(b.fmt("{s}{s}.cpp", .{ gme_src, s }));

	if(opt.ay or opt.kss)
		try files.append(b.fmt("{s}Ay_Apu.cpp", .{ gme_src }));

	if(opt.vgm or opt.gym) {
		const ym_file = switch(opt.ym2612_emu) {
			.nuked => "Nuked", .mame => "MAME", .gens => "GENS",
		};
		try files.append(b.fmt("{s}Ym2612_{s}.cpp", .{ gme_src, ym_file }));
		const ym_macro = switch(opt.ym2612_emu) {
			.nuked => "NUKED", .mame => "MAME", .gens => "GENS",
		};
		gme.root_module.addCMacro(b.fmt("VGM_YM2612_{s}", .{ ym_macro }), "1");
	}

	if (opt.vgm or opt.gym or opt.kss)
		try files.append(b.fmt("{s}Sms_Apu.cpp", .{ gme_src }));

	if (opt.ay)
		for ([_][]const u8{ "Ay_Cpu", "Ay_Emu" }) |s|
			try files.append(b.fmt("{s}{s}.cpp", .{ gme_src, s }));

	if (opt.gbs)
		for ([_][]const u8{ "Gb_Apu", "Gb_Cpu", "Gb_Oscs", "Gbs_Emu" }) |s|
			try files.append(b.fmt("{s}{s}.cpp", .{ gme_src, s }));

	if (opt.gym)
		try files.append(b.fmt("{s}Gym_Emu.cpp", .{ gme_src }));

	if (opt.hes)
		for ([_][]const u8{ "Hes_Apu", "Hes_Cpu", "Hes_Emu" }) |s|
			try files.append(b.fmt("{s}{s}.cpp", .{ gme_src, s }));

	if (opt.kss)
		for ([_][]const u8{ "Kss_Cpu", "Kss_Emu", "Kss_Scc_Apu" }) |s|
			try files.append(b.fmt("{s}{s}.cpp", .{ gme_src, s }));

	if (opt.nsf or opt.nsfe) {
		for ([_][]const u8{
			"Nsf_Emu", "Nes_Cpu", "Nes_Oscs", "Nes_Apu", "Nes_Fme7_Apu",
			"Nes_Namco_Apu", "Nes_Vrc6_Apu", "Nes_Fds_Apu", "Nes_Vrc7_Apu",
		}) |s|
			try files.append(b.fmt("{s}{s}.cpp", .{ gme_src, s }));
		for ([_][]const u8 { "emu2413", "panning" }) |s|
			try files.append(b.fmt("{s}ext/{s}.c", .{ gme_src, s }));
	}

	if (opt.nsfe)
		try files.append(b.fmt("{s}Nsfe_Emu.cpp", .{ gme_src }));

	if (opt.sap)
		for ([_][]const u8 { "Sap_Apu", "Sap_Cpu", "Sap_Emu" }) |s|
			try files.append(b.fmt("{s}{s}.cpp", .{ gme_src, s }));

	if (opt.spc) {
		for ([_][]const u8{ "Snes_Spc", "Spc_Cpu", "Spc_Dsp", "Spc_Emu", "Spc_Filter" }) |s|
			try files.append(b.fmt("{s}{s}.cpp", .{ gme_src, s }));
		if (opt.spc_isolated_echo_buffer)
			gme.root_module.addCMacro("SPC_ISOLATED_ECHO_BUFFER", "1");
	}

	if (opt.vgm)
		for ([_][]const u8{ "Vgm_Emu", "Vgm_Emu_Impl", "Ym2413_Emu" }) |s|
			try files.append(b.fmt("{s}{s}.cpp", .{ gme_src, s }));

	switch (target.result.cpu.arch.endian()) {
		.little => gme.root_module.addCMacro("BLARGG_LITTLE_ENDIAN", "1"),
		.big => gme.root_module.addCMacro("BLARGG_BIG_ENDIAN", "1"),
	}

	gme.addCSourceFiles(.{ .files=files.items, .flags=&.{"-fno-sanitize=undefined"} });
	gme.addIncludePath(b.path(gme_src));
	b.installArtifact(gme);

	const module = b.addModule("gme", .{
		.root_source_file = b.path("gme.zig"),
		.target = target,
		.optimize = optimize,
	});
	module.linkLibrary(gme);

	//---------------------------------------------------------------------------
	// Add player demo
	const player = b.addExecutable(.{
		.name = "gme_player",
		.target = target,
		.optimize = optimize,
	});
	player.linkLibrary(gme);
	player.linkSystemLibrary("SDL2");

	player.linkLibrary(b.dependency("unrar", .{
		.target = target,
		.optimize = optimize,
		.linkage = opt.linkage,
	}).artifact("unrar"));
	player.root_module.addCMacro("RARDLL", "1");
	player.root_module.addCMacro("RAR_HDR_DLL_HPP", "1");

	const player_src = "player/";
	files.deinit();
	files = std.ArrayList([]const u8).init(b.allocator);
	for ([_][]const u8{ "Audio_Scope", "Music_Player", "Archive_Reader", "player" }) |s|
		try files.append(b.fmt("{s}{s}.cpp", .{ player_src, s }));
	player.addCSourceFiles(.{ .files=files.items });
	player.addIncludePath(b.path(gme_src));
	addSteps(b, player, "player", "the player demo");

	//---------------------------------------------------------------------------
	// Add zig demo
	const basics = b.addExecutable(.{
		.name = "demo",
		.root_source_file = b.path("demo/basics.zig"),
		.target = target,
		.optimize = optimize,
	});
	basics.root_module.addImport("gme", module);
	addSteps(b, basics, "demo", "the zig demo");
}

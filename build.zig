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

pub fn build(b: *std.Build) !void {
	const target = b.standardTargetOptions(.{});
	const optimize = b.standardOptimizeOption(.{});

	const default: Options = .{};
	var opt: Options = .{
		.ay = b.option(bool, "ay",
			"Enable support for Spectrum ZX music emulation"
		) orelse default.ay,

		.gbs = b.option(bool, "gbs",
			"Enable support for Game Boy music emulation"
		) orelse default.gbs,

		.gym = b.option(bool, "gym",
			"Enable Sega MegaDrive/Genesis music emulation"
		) orelse default.gym,

		.hes = b.option(bool, "hes",
			"Enable PC Engine/TurboGrafx-16 music emulation"
		) orelse default.hes,

		.kss = b.option(bool, "kss",
			"Enable MSX or other Z80 systems music emulation"
		) orelse default.kss,

		.nsf = b.option(bool, "nsf",
			"Enable NES NSF music emulation"
		) orelse default.nsf,

		.nsfe = b.option(bool, "nsfe",
			"Enable NES NSFE and NSF music emulation"
		) orelse default.nsfe,

		.sap = b.option(bool, "sap",
			"Enable Atari SAP music emulation"
		) orelse default.sap,

		.spc = b.option(bool, "spc",
			"Enable SNES SPC music emulation"
		) orelse default.spc,

		.vgm = b.option(bool, "vgm",
			"Enable Sega VGM/VGZ music emulation"
		) orelse default.vgm,

		.linkage = b.option(LinkMode, "linkage",
			"Library linking method"
		) orelse default.linkage,

		.ym2612_emu = b.option(Ym2612Emu, "ym2612_emu",
			"Which YM2612 emulator to use."
		) orelse default.ym2612_emu,

		.spc_isolated_echo_buffer = b.option(bool, "spc_isolated_echo_buffer",
			"Enable isolated echo buffer on SPC emulator to allow correct playing of " ++
			"\"dodgy\" SPC files made for various ROM hacks ran on ZSNES"
		) orelse default.spc_isolated_echo_buffer,
	};

	if (opt.nsfe and !opt.nsf) {
		std.debug.print("NSFE support requires NSF, enabling NSF support.\n", .{});
		opt.nsf = true;
	}

	const lib = b.addLibrary(.{
		.name = "gme",
		.linkage = opt.linkage,
		.root_module = b.createModule(.{
			.target = target,
			.optimize = optimize,
			.link_libcpp = true,
		}),
	});

	const zlib_dep = b.dependency("zlib", .{
		.target = target,
		.optimize = optimize,
	});
	lib.linkLibrary(zlib_dep.artifact("z"));
	lib.root_module.addCMacro("HAVE_ZLIB_H", "1");

	const src = "gme/";
	var files = std.ArrayList([]const u8).init(b.allocator);
	defer files.deinit();
	for ([_][]const u8{
		"Blip_Buffer", "Classic_Emu", "Data_Reader", "Dual_Resampler", "Effects_Buffer",
		"Fir_Resampler", "gme", "Gme_File", "M3u_Playlist", "Multi_Buffer", "Music_Emu",
	}) |s|
		try files.append(b.fmt("{s}{s}.cpp", .{ src, s }));

	if(opt.ay or opt.kss)
		try files.append(b.fmt("{s}Ay_Apu.cpp", .{ src }));

	if(opt.vgm or opt.gym) {
		try files.append(b.fmt("{s}Ym2612_{s}.cpp", .{ src, switch(opt.ym2612_emu) {
			.nuked => "Nuked", .mame => "MAME", .gens => "GENS",
		}}));
		lib.root_module.addCMacro(b.fmt("VGM_YM2612_{s}", .{ switch(opt.ym2612_emu) {
			.nuked => "NUKED", .mame => "MAME", .gens => "GENS",
		}}), "1");
	}

	if (opt.vgm or opt.gym or opt.kss)
		try files.append(b.fmt("{s}Sms_Apu.cpp", .{ src }));

	if (opt.ay)
		for ([_][]const u8{ "Ay_Cpu", "Ay_Emu" }) |s|
			try files.append(b.fmt("{s}{s}.cpp", .{ src, s }));

	if (opt.gbs)
		for ([_][]const u8{ "Gb_Apu", "Gb_Cpu", "Gb_Oscs", "Gbs_Emu" }) |s|
			try files.append(b.fmt("{s}{s}.cpp", .{ src, s }));

	if (opt.gym)
		try files.append(b.fmt("{s}Gym_Emu.cpp", .{ src }));

	if (opt.hes)
		for ([_][]const u8{ "Hes_Apu", "Hes_Cpu", "Hes_Emu" }) |s|
			try files.append(b.fmt("{s}{s}.cpp", .{ src, s }));

	if (opt.kss)
		for ([_][]const u8{ "Kss_Cpu", "Kss_Emu", "Kss_Scc_Apu" }) |s|
			try files.append(b.fmt("{s}{s}.cpp", .{ src, s }));

	if (opt.nsf or opt.nsfe) {
		for ([_][]const u8{
			"Nsf_Emu", "Nes_Cpu", "Nes_Oscs", "Nes_Apu", "Nes_Fme7_Apu",
			"Nes_Namco_Apu", "Nes_Vrc6_Apu", "Nes_Fds_Apu", "Nes_Vrc7_Apu",
		}) |s|
			try files.append(b.fmt("{s}{s}.cpp", .{ src, s }));
		for ([_][]const u8 { "emu2413", "panning" }) |s|
			try files.append(b.fmt("{s}ext/{s}.c", .{ src, s }));
	}

	if (opt.nsfe)
		try files.append(b.fmt("{s}Nsfe_Emu.cpp", .{ src }));

	if (opt.sap)
		for ([_][]const u8 { "Sap_Apu", "Sap_Cpu", "Sap_Emu" }) |s|
			try files.append(b.fmt("{s}{s}.cpp", .{ src, s }));

	if (opt.spc) {
		for ([_][]const u8{ "Snes_Spc", "Spc_Cpu", "Spc_Dsp", "Spc_Emu", "Spc_Filter" }) |s|
			try files.append(b.fmt("{s}{s}.cpp", .{ src, s }));
		if (opt.spc_isolated_echo_buffer)
			lib.root_module.addCMacro("SPC_ISOLATED_ECHO_BUFFER", "1");
	}

	if (opt.vgm)
		for ([_][]const u8{ "Vgm_Emu", "Vgm_Emu_Impl", "Ym2413_Emu" }) |s|
			try files.append(b.fmt("{s}{s}.cpp", .{ src, s }));

	switch (target.result.cpu.arch.endian()) {
		.little => lib.root_module.addCMacro("BLARGG_LITTLE_ENDIAN", "1"),
		.big => lib.root_module.addCMacro("BLARGG_BIG_ENDIAN", "1"),
	}

	lib.addCSourceFiles(.{
		.files = files.items,
		.flags = &.{
			"-fno-sanitize=undefined",
			"-Wzero-as-null-pointer-constant",
			"-Werror",
		},
	});
	b.installArtifact(lib);

	const module = b.addModule("gme", .{
		.root_source_file = b.path("gme.zig"),
		.target = target,
		.optimize = optimize,
	});
	module.linkLibrary(lib);

	//---------------------------------------------------------------------------
	// Add player demo
	const player = b.addExecutable(.{
		.name = "gme_player",
		.target = target,
		.optimize = optimize,
	});
	player.linkLibrary(lib);
	player.linkLibrary(zlib_dep.artifact("z"));
	player.linkSystemLibrary("SDL2");
	player.linkSystemLibrary("archive");

	player.root_module.addCMacro("HAVE_ZLIB_H", "1");
	player.root_module.addCMacro("HAVE_LIBARCHIVE", "1");

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
	player.addCSourceFiles(.{
		.files = files.items,
		.flags = &.{
			"-Wzero-as-null-pointer-constant",
			"-Werror",
		},
	});
	player.addIncludePath(b.path("."));
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

fn addSteps(
	b: *std.Build,
	exe: *std.Build.Step.Compile,
	name: []const u8,
	desc: []const u8,
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

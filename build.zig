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

	fn init(b: *std.Build) Options {
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
		return opt;
	}
};

pub fn build(b: *std.Build) !void {
	const target = b.standardTargetOptions(.{});
	const optimize = b.standardOptimizeOption(.{});
	const opt: Options = .init(b);

	const zlib_dep = b.dependency("zlib", .{
		.target = target,
		.optimize = optimize,
	});

	const mod_args: std.Build.Module.CreateOptions = .{
		.target = target,
		.optimize = optimize,
		.link_libcpp = true,
	};

	//---------------------------------------------------------------------------
	// Library
	const lib = blk: {
		const mod = b.createModule(mod_args);

		const mem = b.allocator;
		var files: std.ArrayList([]const u8) = try .initCapacity(mem, 0);
		defer files.deinit(mem);

		try files.appendSlice(mem, &src.main);

		if (opt.ay or opt.kss) {
			try files.appendSlice(mem, &src.ay_apu);
		}
		if (opt.vgm or opt.gym) switch (opt.ym2612_emu) {
			.nuked => {
				try files.appendSlice(mem, &src.ym_nuked);
				mod.addCMacro("VGM_YM2612_NUKED", "1");
			},
			.mame => {
				try files.appendSlice(mem, &src.ym_mame);
				mod.addCMacro("VGM_YM2612_MAME", "1");
			},
			.gens => {
				try files.appendSlice(mem, &src.ym_gens);
				mod.addCMacro("VGM_YM2612_GENS", "1");
			},
		};
		if (opt.vgm or opt.gym or opt.kss) {
			try files.appendSlice(mem, &src.sms);
		}
		if (opt.ay) {
			try files.appendSlice(mem, &src.ay);
		}
		if (opt.gbs) {
			try files.appendSlice(mem, &src.gbs);
		}
		if (opt.gym) {
			try files.appendSlice(mem, &src.gym);
		}
		if (opt.hes) {
			try files.appendSlice(mem, &src.hes);
		}
		if (opt.kss) {
			try files.appendSlice(mem, &src.kss);
		}
		if (opt.nsf or opt.nsfe) {
			try files.appendSlice(mem, &src.nsf);
		}
		if (opt.nsfe) {
			try files.appendSlice(mem, &src.nsfe);
		}
		if (opt.sap) {
			try files.appendSlice(mem, &src.sap);
		}
		if (opt.spc) {
			try files.appendSlice(mem, &src.spc);
			if (opt.spc_isolated_echo_buffer) {
				mod.addCMacro("SPC_ISOLATED_ECHO_BUFFER", "1");
			}
		}
		if (opt.vgm) {
			try files.appendSlice(mem, &src.vgm);
		}

		switch (target.result.cpu.arch.endian()) {
			.little => mod.addCMacro("BLARGG_LITTLE_ENDIAN", "1"),
			.big => mod.addCMacro("BLARGG_BIG_ENDIAN", "1"),
		}

		mod.addCSourceFiles(.{
			.files = files.items,
			.flags = &.{
				"-fno-sanitize=undefined",
				"-Wzero-as-null-pointer-constant",
				"-Werror",
			},
		});

		mod.linkLibrary(zlib_dep.artifact("z"));
		mod.addCMacro("HAVE_ZLIB_H", "1");

		const lib = b.addLibrary(.{
			.name = "gme",
			.linkage = opt.linkage,
			.root_module = mod,
		});
		b.installArtifact(lib);
		break :blk lib;
	};

	//---------------------------------------------------------------------------
	// Player demo
	{
		const mod = b.createModule(mod_args);
		mod.linkLibrary(lib);
		mod.linkLibrary(zlib_dep.artifact("z"));
		mod.linkSystemLibrary("SDL2", .{});
		mod.linkSystemLibrary("archive", .{});

		mod.addCMacro("HAVE_ZLIB_H", "1");
		mod.addCMacro("HAVE_LIBARCHIVE", "1");

		mod.linkLibrary(b.dependency("unrar", .{
			.target = target,
			.optimize = optimize,
			.linkage = opt.linkage,
		}).artifact("unrar"));
		mod.addCMacro("RARDLL", "1");
		mod.addCMacro("RAR_HDR_DLL_HPP", "1");

		mod.addCSourceFiles(.{
			.files = &src.player,
			.flags = &.{
				"-Wzero-as-null-pointer-constant",
				"-Werror",
			},
		});
		mod.addIncludePath(b.path("."));

		addSteps(b, b.addExecutable(.{
			.name = "gme_player",
			.root_module = mod,
		}), "player", "the player demo");
	}

	//---------------------------------------------------------------------------
	// Zig example
	{
		const zig_mod = b.addModule("gme", .{
			.root_source_file = b.path("gme.zig"),
			.target = target,
			.optimize = optimize,
		});
		zig_mod.linkLibrary(lib);

		const basics = b.addExecutable(.{
			.name = "basics",
			.root_module = b.createModule(.{
				.root_source_file = b.path("demo/basics.zig"),
				.target = target,
				.optimize = optimize,
				.imports = &.{ .{ .name = "gme", .module = zig_mod } },
			}),
		});
		addSteps(b, basics, "basics", "the zig example");
	}
}

fn addSteps(
	b: *std.Build,
	exe: *std.Build.Step.Compile,
	name: []const u8,
	desc: []const u8,
) void {
	const install = b.addInstallArtifact(exe, .{});
	const step_install = b.step(name, b.fmt("Build {s}", .{ desc }));
	step_install.dependOn(&install.step);

	const run = b.addRunArtifact(exe);
	run.step.dependOn(&install.step);
	const step_run = b.step(
		b.fmt("run_{s}", .{name}), b.fmt("Build and run {s}", .{ desc }) );
	step_run.dependOn(&run.step);
	if (b.args) |args| {
		run.addArgs(args);
	}
}

const src = struct {
	const main = [_][]const u8{
		"gme/Blip_Buffer.cpp",
		"gme/Classic_Emu.cpp",
		"gme/Data_Reader.cpp",
		"gme/Dual_Resampler.cpp",
		"gme/Effects_Buffer.cpp",
		"gme/Fir_Resampler.cpp",
		"gme/gme.cpp",
		"gme/Gme_File.cpp",
		"gme/M3u_Playlist.cpp",
		"gme/Multi_Buffer.cpp",
		"gme/Music_Emu.cpp",
	};

	const ay = [_][]const u8{
		"gme/Ay_Cpu.cpp",
		"gme/Ay_Emu.cpp",
	};
	const ay_apu = [_][]const u8{
		"gme/Ay_Apu.cpp",
	};

	const ym_nuked = [_][]const u8{
		"gme/Ym2612_Nuked.cpp",
	};
	const ym_mame = [_][]const u8{
		"gme/Ym2612_MAME.cpp",
	};
	const ym_gens = [_][]const u8{
		"gme/Ym2612_GENS.cpp",
	};

	const sms = [_][]const u8{
		"gme/Sms_Apu.cpp",
	};

	const vgm = [_][]const u8{
		"gme/Vgm_Emu.cpp",
		"gme/Vgm_Emu_Impl.cpp",
		"gme/Ym2413_Emu.cpp",
	};

	const gym = [_][]const u8{
		"gme/Gym_Emu.cpp",
	};

	const kss = [_][]const u8{
		"gme/Kss_Cpu.cpp",
		"gme/Kss_Emu.cpp",
		"gme/Kss_Scc_Apu.cpp"
	};

	const gbs = [_][]const u8{
		"gme/Gb_Apu.cpp",
		"gme/Gb_Cpu.cpp",
		"gme/Gb_Oscs.cpp",
		"gme/Gbs_Emu.cpp",
	};

	const hes = [_][]const u8{
		"gme/Hes_Apu.cpp",
		"gme/Hes_Cpu.cpp",
		"gme/Hes_Emu.cpp",
	};

	const nsf = [_][]const u8{
		"gme/Nsf_Emu.cpp",
		"gme/Nes_Cpu.cpp",
		"gme/Nes_Oscs.cpp",
		"gme/Nes_Apu.cpp",
		"gme/Nes_Fme7_Apu.cpp",
		"gme/Nes_Namco_Apu.cpp",
		"gme/Nes_Vrc6_Apu.cpp",
		"gme/Nes_Fds_Apu.cpp",
		"gme/Nes_Vrc7_Apu.cpp",
		"gme/ext/emu2413.c",
		"gme/ext/panning.c",
	};
	const nsfe = [_][]const u8{
		"gme/Nsfe_Emu.cpp",
	};

	const sap = [_][]const u8 {
		"gme/Sap_Apu.cpp",
		"gme/Sap_Cpu.cpp",
		"gme/Sap_Emu.cpp",
	};

	const spc = [_][]const u8{
		"gme/Snes_Spc.cpp",
		"gme/Spc_Cpu.cpp",
		"gme/Spc_Dsp.cpp",
		"gme/Spc_Emu.cpp",
		"gme/Spc_Filter.cpp",
	};

	const player = [_][]const u8{
		"player/Audio_Scope.cpp",
		"player/Music_Player.cpp",
		"player/Archive_Reader.cpp",
		"player/player.cpp",
	};
};

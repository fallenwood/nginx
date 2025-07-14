const std = @import("std");

const Compile = std.Build.Step.Compile;

const CodeUnitWidth = enum {
    @"8",
    @"16",
    @"32",
};

fn buildPcre2(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) !*Compile {
    const codeUnitWidth: CodeUnitWidth = .@"8";
    const pcre2_header_dir = b.addWriteFiles();
    const pcre2_header = pcre2_header_dir.addCopyFile(b.path("vendor/pcre2/src/pcre2.h.generic"), "pcre2.h");

    const config_header = b.addConfigHeader(
        .{
            .style = .{ .cmake = b.path("vendor/pcre2/src/config-cmake.h.in") },
            .include_path = "config.h",
        },
        .{
            .HAVE_ASSERT_H = true,
            .HAVE_UNISTD_H = (target.result.os.tag != .windows),
            .HAVE_WINDOWS_H = (target.result.os.tag == .windows),

            .HAVE_MEMMOVE = true,
            .HAVE_STRERROR = true,

            .SUPPORT_PCRE2_8 = codeUnitWidth == CodeUnitWidth.@"8",
            .SUPPORT_PCRE2_16 = codeUnitWidth == CodeUnitWidth.@"16",
            .SUPPORT_PCRE2_32 = codeUnitWidth == CodeUnitWidth.@"32",
            .SUPPORT_UNICODE = true,

            .PCRE2_EXPORT = null,
            .PCRE2_LINK_SIZE = 2,
            .PCRE2_HEAP_LIMIT = 20000000,
            .PCRE2_MATCH_LIMIT = 10000000,
            .PCRE2_MATCH_LIMIT_DEPTH = "MATCH_LIMIT",
            .PCRE2_MAX_VARLOOKBEHIND = 255,
            .NEWLINE_DEFAULT = 2,
            .PCRE2_PARENS_NEST_LIMIT = 250,
            .PCRE2GREP_BUFSIZE = 20480,
            .PCRE2GREP_MAX_BUFSIZE = 1048576,
        },
    );

    // pcre2-8/16/32.lib

    const lib_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    lib_mod.addCMacro("HAVE_CONFIG_H", "");
    lib_mod.addCMacro("PCRE2_CODE_UNIT_WIDTH", @tagName(codeUnitWidth));
    lib_mod.addCMacro("PCRE2_STATIC", "");

    const lib = b.addLibrary(.{
        .name = b.fmt("pcre2-{s}", .{@tagName(codeUnitWidth)}),
        .root_module = lib_mod,
        .linkage = .static,
    });

    lib.addConfigHeader(config_header);
    lib.addIncludePath(pcre2_header_dir.getDirectory());
    lib.addIncludePath(b.path("vendor/pcre2/src"));

    lib.addCSourceFile(.{
        .file = b.addWriteFiles().addCopyFile(b.path("vendor/pcre2/src/pcre2_chartables.c.dist"), "pcre2_chartables.c"),
    });

    lib.addCSourceFiles(.{
        .files = &.{
            "vendor/pcre2/src/pcre2_auto_possess.c",
            "vendor/pcre2/src/pcre2_chkdint.c",
            "vendor/pcre2/src/pcre2_compile.c",
            "vendor/pcre2/src/pcre2_compile_cgroup.c",
            "vendor/pcre2/src/pcre2_compile_class.c",
            "vendor/pcre2/src/pcre2_config.c",
            "vendor/pcre2/src/pcre2_context.c",
            "vendor/pcre2/src/pcre2_convert.c",
            "vendor/pcre2/src/pcre2_dfa_match.c",
            "vendor/pcre2/src/pcre2_error.c",
            "vendor/pcre2/src/pcre2_extuni.c",
            "vendor/pcre2/src/pcre2_find_bracket.c",
            "vendor/pcre2/src/pcre2_jit_compile.c",
            "vendor/pcre2/src/pcre2_maketables.c",
            "vendor/pcre2/src/pcre2_match.c",
            "vendor/pcre2/src/pcre2_match_data.c",
            "vendor/pcre2/src/pcre2_match_next.c",
            "vendor/pcre2/src/pcre2_newline.c",
            "vendor/pcre2/src/pcre2_ord2utf.c",
            "vendor/pcre2/src/pcre2_pattern_info.c",
            "vendor/pcre2/src/pcre2_script_run.c",
            "vendor/pcre2/src/pcre2_serialize.c",
            "vendor/pcre2/src/pcre2_string_utils.c",
            "vendor/pcre2/src/pcre2_study.c",
            "vendor/pcre2/src/pcre2_substitute.c",
            "vendor/pcre2/src/pcre2_substring.c",
            "vendor/pcre2/src/pcre2_tables.c",
            "vendor/pcre2/src/pcre2_ucd.c",
            "vendor/pcre2/src/pcre2_valid_utf.c",
            "vendor/pcre2/src/pcre2_xclass.c",
        },
    });

    lib.installHeader(pcre2_header, "pcre2.h");

    return lib;
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const pcre2 = try buildPcre2(b, target, optimize);

    const nginx_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
    });

    const flags = [_][]const u8{ "-std=gnu11", "-DZIG_BUILD", "-D_GNU_SOURCE", "-DFD_SETSIZE=1024", "-Isrc/core", "-Isrc/http", "-Isrc/http/modules", "-Isrc/event", "-Isrc/event/modules", "-Isrc/event/quic", "-Izig/win32", "-Isrc/os/win32", "-Ivendor/pcre2/src" };

    const nginx_sources_common = [_][]const u8{
        "src/core/nginx.c",
        "src/core/ngx_array.c",
        "src/core/ngx_buf.c",
        "src/core/ngx_conf_file.c",
        "src/core/ngx_connection.c",
        "src/core/ngx_cpuinfo.c",
        "src/core/ngx_crc32.c",
        "src/core/ngx_crypt.c",
        "src/core/ngx_cycle.c",
        "src/core/ngx_file.c",
        "src/core/ngx_hash.c",
        "src/core/ngx_inet.c",
        "src/core/ngx_list.c",
        "src/core/ngx_log.c",
        "src/core/ngx_md5.c",
        "src/core/ngx_module.c",
        "src/core/ngx_murmurhash.c",
        "src/core/ngx_open_file_cache.c",
        "src/core/ngx_output_chain.c",
        "src/core/ngx_palloc.c",
        "src/core/ngx_parse_time.c",
        "src/core/ngx_parse.c",
        "src/core/ngx_proxy_protocol.c",
        "src/core/ngx_queue.c",
        "src/core/ngx_radix_tree.c",
        "src/core/ngx_rbtree.c",
        "src/core/ngx_regex.c",
        "src/core/ngx_resolver.c",
        "src/core/ngx_rwlock.c",
        "src/core/ngx_sha1.c",
        "src/core/ngx_shmtx.c",
        "src/core/ngx_slab.c",
        "src/core/ngx_spinlock.c",
        "src/core/ngx_string.c",
        "src/core/ngx_syslog.c",
        "src/core/ngx_times.c",
        "src/event/modules/ngx_iocp_module.c",
        "src/event/modules/ngx_win32_poll_module.c",
        "src/event/modules/ngx_win32_select_module.c",
        "src/event/ngx_event_accept.c",
        "src/event/ngx_event_acceptex.c",
        "src/event/ngx_event_connect.c",
        "src/event/ngx_event_pipe.c",
        "src/event/ngx_event_posted.c",
        "src/event/ngx_event_timer.c",
        "src/event/ngx_event_udp.c",
        "src/event/ngx_event.c",
        "src/http/modules/ngx_http_access_module.c",
        "src/http/modules/ngx_http_auth_basic_module.c",
        "src/http/modules/ngx_http_autoindex_module.c",
        "src/http/modules/ngx_http_browser_module.c",
        "src/http/modules/ngx_http_charset_filter_module.c",
        "src/http/modules/ngx_http_chunked_filter_module.c",
        "src/http/modules/ngx_http_empty_gif_module.c",
        "src/http/modules/ngx_http_fastcgi_module.c",
        "src/http/modules/ngx_http_geo_module.c",
        "src/http/modules/ngx_http_headers_filter_module.c",
        "src/http/modules/ngx_http_index_module.c",
        "src/http/modules/ngx_http_limit_conn_module.c",
        "src/http/modules/ngx_http_limit_req_module.c",
        "src/http/modules/ngx_http_log_module.c",
        "src/http/modules/ngx_http_map_module.c",
        "src/http/modules/ngx_http_memcached_module.c",
        "src/http/modules/ngx_http_mirror_module.c",
        "src/http/modules/ngx_http_not_modified_filter_module.c",
        "src/http/modules/ngx_http_proxy_module.c",
        "src/http/modules/ngx_http_range_filter_module.c",
        "src/http/modules/ngx_http_rewrite_module.c",
        "src/http/modules/ngx_http_referer_module.c",
        "src/http/modules/ngx_http_scgi_module.c",
        "src/http/modules/ngx_http_split_clients_module.c",
        "src/http/modules/ngx_http_ssi_filter_module.c",
        "src/http/modules/ngx_http_static_module.c",
        "src/http/modules/ngx_http_try_files_module.c",
        "src/http/modules/ngx_http_upstream_hash_module.c",
        "src/http/modules/ngx_http_upstream_ip_hash_module.c",
        "src/http/modules/ngx_http_upstream_keepalive_module.c",
        "src/http/modules/ngx_http_upstream_least_conn_module.c",
        "src/http/modules/ngx_http_upstream_random_module.c",
        "src/http/modules/ngx_http_upstream_zone_module.c",
        "src/http/modules/ngx_http_userid_filter_module.c",
        "src/http/modules/ngx_http_uwsgi_module.c",
        "src/http/ngx_http_copy_filter_module.c",
        "src/http/ngx_http_core_module.c",
        "src/http/ngx_http_file_cache.c",
        "src/http/ngx_http_header_filter_module.c",
        "src/http/ngx_http_parse.c",
        "src/http/ngx_http_postpone_filter_module.c",
        "src/http/ngx_http_request_body.c",
        "src/http/ngx_http_request.c",
        "src/http/ngx_http_script.c",
        "src/http/ngx_http_special_response.c",
        "src/http/ngx_http_upstream_round_robin.c",
        "src/http/ngx_http_upstream.c",
        "src/http/ngx_http_variables.c",
        "src/http/ngx_http_write_filter_module.c",
        "src/http/ngx_http.c",
    };

    const nginx_sources_win32 = [_][]const u8{
        "src/os/win32/ngx_alloc.c",
        "src/os/win32/ngx_dlopen.c",
        "src/os/win32/ngx_errno.c",
        "src/os/win32/ngx_event_log.c",
        "src/os/win32/ngx_files.c",
        "src/os/win32/ngx_process_cycle.c",
        "src/os/win32/ngx_process.c",
        "src/os/win32/ngx_shmem.c",
        "src/os/win32/ngx_socket.c",
        "src/os/win32/ngx_thread.c",
        "src/os/win32/ngx_time.c",
        "src/os/win32/ngx_udp_wsarecv.c",
        "src/os/win32/ngx_user.c",
        "src/os/win32/ngx_win32_init.c",
        "src/os/win32/ngx_wsarecv_chain.c",
        "src/os/win32/ngx_wsarecv.c",
        "src/os/win32/ngx_wsasend_chain.c",
        "src/os/win32/ngx_wsasend.c",
        "zig/win32/ngx_modules.c",
    };

    const sources = try std.mem.concat(std.heap.page_allocator, []const u8, &.{ &nginx_sources_common, &nginx_sources_win32 });

    nginx_mod.addCSourceFiles(.{
        .files = sources,
        .flags = &flags,
    });
    nginx_mod.addCMacro("PCRE2_STATIC", "");

    const exe = b.addExecutable(.{
        .linkage = .dynamic,
        .name = "nginx",
        .root_module = nginx_mod,
    });

    exe.step.dependOn(&pcre2.step);

    exe.linkLibC();
    exe.linkSystemLibrary("ws2_32");
    exe.linkLibrary(pcre2);

    b.installArtifact(pcre2);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

#!/usr/bin/ruby
$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), "."))

require 'work'
require 'patch'
require 'getopt/long'

$VERBOSE = nil
TERM::SPINNER = [ '[|]', '[/]', '[-]', '[\]' ]

trap("INT") {
	TERM.check_eol
	TERM.eol
	TERM.warn "exiting"
	exit
}

def get_patches(patches_d)
	ret = Hash.new
	pobj = Patch.new
	begin
	Dir.foreach(patches_d) { |patch|
		next if patch.eql? "."
		next if patch.eql? ".."
		pobj.load(patches_d + '/' + patch)
		if not pobj.target.nil? and not pobj.number.nil?
			if ret[pobj.target].nil?
				ret[pobj.target] = Array.new
			end
			ret[pobj.target][pobj.number.to_i] = patch
		end
	}
	rescue => ex
		TERM.error "error while reading patches from `#{patches_d}'"
		TERM.error ex.to_s
		exit 1
	end
	ret
end


# parsing command line arguments {{{

begin
opt = Getopt::Long.getopts(
	["--file", "-f", Getopt::REQUIRED],
	["--start", "-s", Getopt::REQUIRED],
	["--end", "-e", Getopt::REQUIRED],
	["--patches", "-p", Getopt::REQUIRED],
	["--source", "-o", Getopt::REQUIRED],
	["--vanilla", "-l", Getopt::REQUIRED],
	["--continue", "-c", Getopt::BOOLEAN],
	["--init", "-i", Getopt::BOOLEAN],
	["--sync", "", Getopt::BOOLEAN]
)

rescue => ex
	TERM.error("error parsing command line arguments")
	TERM.error(ex.to_s)
	exit 1
end

# }}} 


if opt["p"]
	$patches_d = opt["p"]
else
	$patches_d = CONFIG['workspace_d'] + '/itsd/devel/nix/' + CONFIG['branch'] + \
			'/low_level/' + CONFIG['asterisk_patches_d'] + '/' + \
			CONFIG['asterisk_version']
end

if opt["o"]
	$source_d = opt["o"]
else
	$source_d = CONFIG['src_d'] + '/' + CONFIG['branch'] + '/asterisk/' + CONFIG['asterisk_version'] + \
				'/' + CONFIG['patchroot_d']
end

if opt["l"]
	vanilla_d = opt["l"]
else
	vanilla_d = CONFIG['src_d'] + '/' + CONFIG['branch'] + '/asterisk/' + CONFIG['asterisk_version'] + \
				'/' + CONFIG['vanilla_d']
end

start_idx = opt["s"].to_i if not opt["s"].nil?
stop_idx = opt["e"].to_i if not opt["e"].nil?
file = opt["f"] if not opt["f"].nil?
init = opt["i"]

if opt["sync"]
	PERF.sync($patches_d + '/...')
end

patches = get_patches($patches_d)
if patches.nil? or patches.empty?
	TERM.error "no patches found in `#{$patches_d}'"
	exit
end


def apply_patch_set(target, set, start, stop)

	ok = true
	code = 0
	errors = ""
	n = 0

	TERM.action target.dup
	p = Patch.new('', $source_d)

	set.each_index { |idx|
		next if set[idx].nil?
		next if not start.nil? and idx < start
		break if not stop.nil? and idx > stop
		TERM.reset_line
		TERM.action target.dup + " : patch "
		TERM.print idx.to_s.dup, :light_yellow
		p.load($patches_d + '/' + set[idx])
		n += 1
		exit_code = p.apply
		if exit_code > 0
			code = exit_code
			errors = p.stdout
			TERM.failure
			TERM.error p.file
			ok = false
			break
		end
	}
	if ok
		TERM.reset_line
		TERM.action target.dup + " ("
		TERM.print n.to_s, :light_yellow
		if n > 1
			TERM.print " patches)"
		else
			TERM.print " patch)"
		end
		TERM.ok
	end
	
	[code, errors]
end

if init
	TERM.h1 "initializing"
	TERM.action "initializing source "
	TERM.spinner_start
	begin
	if not file.nil?
		FileUtils.copy(vanilla_d + '/' + file, $source_d + '/' + file)
	else
		FileUtils.cp_r(vanilla_d + '/.', $source_d)
	end
	rescue => ex
		TERM.failure
		TERM.error ex.to_s
		exit
	ensure
		TERM.spinner_stop
	end
	TERM.ok
end

TERM.h1 "applying patches"

if not file.nil?
	code, errors = apply_patch_set(file, patches[file], start_idx, stop_idx)
	if code > 0
		TERM.error errors
		exit
	end
else
	patches.each_pair { |target, spec|
		next if target.nil? or target.empty?
		code, errors = apply_patch_set(target, spec, start_idx, stop_idx)
		if code > 0 and not opt["c"]
			TERM.error errors
			exit
		end
	}
end




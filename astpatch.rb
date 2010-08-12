#!/usr/bin/ruby

require 'work'
require 'patch'
require 'getopt/long'

trap("INT") { exit }

def get_patches(patches_d)
	ret = Hash.new
	pobj = Patch.new
	begin
	Dir.foreach(patches_d) { |patch|
		pobj.load(patches_d + '/' + patch)
		if not pobj.target.nil? and not pobj.number.nil?
			if ret[pobj.target].nil?
				ret[pobj.target] = Array.new
			end
			ret[pobj.target][pobj.number] = patch
		end
	}
	rescue
		nil
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
	TERM.error "no patches found in `#{patches_d}'"
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
		n += 1
		p.load($patches_d + '/' + set[idx])
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
		TERM.print " patches)"
		TERM.ok
	end
	
	[code, errors]
end

if init
	TERM.action "initializing source"
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
	end
	TERM.ok
end

TERM.info "applying patches"
TERM.eol

if not file.nil?
	apply_patch_set(file, patches[file], start_idx, stop_idx)
else
	patches.each_pair { |target, spec|
		code, errors = apply_patch_set(target, spec, start_idx, stop_idx)
		if code > 0 and not opt["c"]
			TERM.error errors
			exit
		end
	}
end




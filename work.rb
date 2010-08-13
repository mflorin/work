#!/usr/bin/ruby

class ProgressBar
	attr_accessor :title, :title_width, :bar_mark

	def title=(t)
		@title = t
		@title_width = t.length
		@format = "%-#{@title_width}s %3d%% %s %s"
	end
	
	def title_width=(tw)
		@title_width = tw
		@format = "%-#{@title_width}s %3d%% %s %s"
	end

end

module Work # Beginning of Work module

require "P4"
require "singleton"
require "delegate"
require "rubygems"
require "parseconfig"
require "colorize"
require "util"
require "progressbar"

class Config
	
	include Singleton
	
	CFG_FILE = "/etc/work.rc"
	CFG_SEP = '='
	@@config = nil

	def initialize
		reload
	end
	
	def var(name, group = nil)
		if (group.nil? || @@config.params[group].nil?)
			@@config.params[name]
		else
			@@config.params[group][name]
		end
	end
	
	def [](var)
		@@config.params[var]
	end

	def reload
		@@config = ParseConfig.new(CFG_FILE, CFG_SEP)
	end

end

class P4_Work < DelegateClass(P4)

	include Singleton

	attr_accessor :client

	def initialize
		begin
			@p4obj = P4.new

			# to ignore "File(s) up-to-date"
			@p4obj.exception_level =  P4::RAISE_ERRORS
			@p4obj.connect
			@p4obj.run_login

			super(@p4obj)
			
			@client = @p4obj.run_client("-o").shift

		rescue P4Exception
			@p4obj.errors.each { |e| puts(e) }
		end

	end

	def revert_changelist(changelist)
		spec = run("describe", "-s", changelist)
		revs = spec[0]["rev"];
		files = spec[0]["depotFile"];
		
		revs.each_index { |x|
#			run("sync", files[x] + "#" + revs[x])		
			print files[x] + " # " + revs[x] + "\n"
		}
	end

end

class Term_Meta
	
	attr_accessor :out

	def self.metaclass
		class << self
			self
		end
	end

	def self.style(name, params)
		raise "params must be a hash" unless params.class == Hash
		@out = STDOUT	
		func =<<-EOT1
			def #{name}(str)
				@out.print "\r"
				#{params[:before]}.times { @out.print "\n" }
		EOT1

		if params.has_key?(:apply)
			func << <<-EOT
				if str.respond_to?("#{params[:apply]}")
					s = str.send("#{params[:apply]}")
				else
					s = str.dup
				end
			EOT
		else
			func << <<-EOT
				s = str.dup
			EOT
		end
		func << <<-EOT
				@out.print s.colorize("#{params[:fg]}".to_sym) + "\n"
				#{params[:after]}.times { @out.print "\n" }
			end
		EOT
		instance_eval func
	end

	instance_eval <<-EOT
		def out= (o)
			@out = o
		end

		def out
			@out
		end
	EOT

end


class Term < Term_Meta

	include Utils

	style "h1", :before => 2, :after => 1, :fg => :light_yellow, :bg => :default, :apply => :upcase
	style "h2", :before => 1, :after => 0, :fg => :light_green, :bg => :default, :apply => :capitalize
	
	TEXT_COLOR = :light_black

	INFO_BULLET_COLOR = :light_green
	INFO_TEXT_COLOR = :light_black

	WARN_BULLET_COLOR = :light_yellow
	WARN_TEXT_COLOR = :yellow

	ERROR_BULLET_COLOR = :red
	ERROR_TEXT_COLOR = :light_red

	ACTION_BULLET_COLOR = :light_green
	ACTION_TEXT_COLOR = :light_black

	OK_COLOR = :light_green
	FAILURE_COLOR = :light_red

	BRACKET_COLOR = :light_black

	BULLET = "* "
	TAB_SIZE = 2
	TAB = " "
	DOT = "."
	OK = "ok"
	FAILURE = "failed"
	LBRACKET = "["
	RBRACKET = "]"

	LPAD = 0
	RPAD = 10
	
	SPINNER = ['|', '/', '-', '\\', '|']
	SPINNER_SLEEP = 0.1


	@out = STDOUT
	@dent_val = 1
	@last_str = ""
	@line = ""
	@line_len = 0

	def self.reset_line(cols = nil)
		cols, = Utils.term_width_height if cols.nil?
		@out.print "\r" + " " * cols + "\r"
		@line = ""
		@line_len = 0
	end

	def self.indent(x = 1)
		@dent_val += x
	end

	def self.setdent(x = 0)
		@dent_val = x
	end

	def self.indent_str
		' ' * LPAD + TAB * TAB_SIZE * @dent_val
	end

	def self.prefix
		indent_str + BULLET
	end

	def self.print(msg, color = nil)

		str = msg
		@line_len += msg.length
		str = str.colorize(color) if not color.nil?
		@line << str
		@out.print str
		@out.flush
	end

	def self.text(msg, bullet = nil, eol = nil)
		e = eol
		e = "\n" if eol.nil?
		if bullet.nil?
			format(msg, TEXT_COLOR, indent_str, nil, e)
		else
			format(msg, TEXT_COLOR, indent_str + BULLET, INFO_BULLET_COLOR, e)
		end
	end

	def self.eol
		print "\n"
		@line_len = 0
		@line = ""
	end
	
	def self.check_eol
		eol if @line_len > 0
	end
	
	def self.info(msg)
		check_eol
		display(msg, INFO_TEXT_COLOR, prefix, INFO_BULLET_COLOR)
	end

	def self.warn(msg)
		check_eol
		display(msg, WARN_TEXT_COLOR, prefix, WARN_BULLET_COLOR)
	end

	def self.error(msg)
		check_eol
		display(msg, ERROR_TEXT_COLOR, prefix, ERROR_BULLET_COLOR)
	end

	def self.action(msg)
		check_eol
		print prefix, ACTION_BULLET_COLOR
		print msg, ACTION_TEXT_COLOR
	end

	def self.ok(msg = nil)

		cols, = Utils.term_width_height
		if not msg.nil?
			action(msg)
		end

		ok_str_len = (LBRACKET + OK + RBRACKET).length
		ok_str = LBRACKET.colorize(BRACKET_COLOR) + OK.colorize(OK_COLOR) + \
				RBRACKET.colorize(BRACKET_COLOR)
		print ' ' + DOT * (cols - @line_len - ok_str_len - 2 - RPAD) + \
				' ' + ok_str
		eol

	end

	def self.failure(msg = nil)
		
		cols, = Utils.term_width_height
		if not msg.nil?
			reset_line(cols)
			action(msg)
		end

		failure_str_len = (LBRACKET + FAILURE + RBRACKET).length
		failure_str = LBRACKET.colorize(BRACKET_COLOR) + \
					FAILURE.colorize(FAILURE_COLOR) + \
					RBRACKET.colorize(BRACKET_COLOR)
		print ' ' + DOT * (cols - @line_len - failure_str_len - 2 - RPAD) \
					+ ' ' + failure_str
		eol
	end

	def self.spinner_start
		return if @spinner_running
		return if not SPINNER.instance_of? Array
		@spinner_running = true
		@spinner_thread = Thread.new do
			until not @spinner_running 
				prev = nil
				SPINNER.each {|s|
					@out.print("\b" * prev.length) if not prev.nil?
					@out.print(" " * prev.length) if not prev.nil?
					@out.print("\b" * prev.length) if not prev.nil?
					@out.print s
					@out.flush
					prev = s
					sleep SPINNER_SLEEP
				}
				@out.print("\b" * SPINNER[SPINNER.length - 1].length)
				@out.print(" " * SPINNER[SPINNER.length - 1].length)
				@out.print("\b" * SPINNER[SPINNER.length - 1].length)
			end
		end
	end

	def self.spinner_stop
		@spinner_running = false;
		@spinner_thread.join
	end

private

	def self.display(msg, msg_color = nil, sep = nil, sep_color = nil)
		cols, = Utils.term_width_height
		cols -= 1
		cols -= sep.length if not sep.nil?
		msg_color = TEXT_COLOR if msg_color.nil?
		arr = Utils.wrap_arr(msg, cols - 1)
		arr.each { |line| 
			print sep, sep_color
			print line, msg_color
			eol
		}
	end


end

end # End of Work module

TERM = Work::Term
CONFIG = Work::Config.instance
PERF = Work::P4_Work.instance

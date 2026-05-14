require('vis') -- load standard vis module
require('plugins/filetype') -- file type detection
require('plugins/complete-filename') -- C-x C-f & C-x C-o
require('plugins/complete-word') -- C-n

-- vis-plug: a minimal plugin/theme manager for vis.
local plug = (function() if not pcall(require, 'plugins/vis-plug') then
	os.execute('git clone --quiet https://github.com/erf/vis-plug ' ..
		(os.getenv('XDG_CONFIG_HOME') or os.getenv('HOME') .. '/.config')
		.. '/vis/plugins/vis-plug')
end return require('plugins/vis-plug') end)()
local plugins = {
	-- theme which uses a transparent background and the terminal foreground
	{ 'erf/vis-minimal-theme', theme = true, file = 'minimal-dark-clear' },
	-- support for ctags; C-] goto, C-t go back
	{ 'kupospelov/vis-ctags' },
	-- comment toggle; gcc (normal), gc (visual)
	{ 'lutobler/vis-commentary' },
	-- save cursor position per file
	{ 'erf/vis-cursors' },
	-- per file type settings in visrc.lua
	{ 'jocap/vis-filetype-settings', file = 'vis-filetype-settings' },
	-- :fzfmru fuzzy open recently used files
	{ 'peaceant/vis-fzf-mru', file = 'fzf-mru', alias = 'fzf_mru' },
	-- :fzf fuzzy file open, C-s open in split, C-v open in vertical split
	{ 'git.sr.ht/~mcepl/vis-fzf-open' },
	-- open a URL with gx
	{ 'git.sr.ht/~mcepl/vis-jump' },
	-- open a file with gf
	{ 'git.sr.ht/~mcepl/vis-open-file-under-cursor' },
	-- vim-like quickfix commands
	{ 'repo.or.cz/vis-quickfix' },
	-- better deletion of spaces used for indentation
	{ 'milhnl/vis-backspace' },
	-- .editorconfig: indent_style, indent_size, tab_width, and max_line_length
	{ 'milhnl/vis-editorconfig-options' },
	-- spellcheck; C-w e enable, C-w d disable, F7 toggle, C-w w fix
	{ 'gitlab.com/muhq/vis-spellcheck', alias = 'spellcheck' },
	-- alternative to :< invoked as :R
	{ 'seifferth/vis-super-shellout', file = 'super-shellout' },
	-- edit files encrypted with GnuPG
	{ 'rnpnr/vis-gpg' },
}
plug.init(plugins, true)

-- for vis-filetype-settings
settings = {
	-- some languages have indentation conventions
	go = {"set expandtab off", "set tabwidth 8"},
	makefile = {"set expandtab off", "set tabwidth 8"},
	python = {"set expandtab on", "set tabwidth 4"},
	rust = {"set expandtab on", "set tabwidth 4"},
	zig = {"set expandtab on", "set tabwidth 4"},
}

-- global configuration options
vis.events.subscribe(vis.events.INIT, function()
	-- vis-fzf-mru
	plug.plugins.fzf_mru.fzfmru_history = 64
	vis:map(vis.modes.NORMAL, " b", ":fzfmru<Enter>")

	-- vis-fzf-open shortcut
	vis:command('map! normal <C-p> :fzf<Enter>')

	-- vis-spellcheck settings; use aspell(1) rather than enchant(1)
	plug.plugins.spellcheck.cmd = "aspell -l %s -a"
	plug.plugins.spellcheck.list_cmd = "aspell list -l %s -a"
	plug.plugins.spellcheck.default_lang = "en_US"
end)

-- fix filetype for *.gpg files, since autodetection doesn't work
local function gpgfixft(win)
	if win.syntax ~= nil then return end
	local file = win.file
	if file == nil then return end
	if file.name == nil then return end
	if file.name:find('%.gpg$') == nil then return end
	local extsyntax = {
		-- in theory a *.gpg file could be anything, but typically it's prose
		md = "markdown",
		txt = "text",
	}
	for ext, syntax in pairs(extsyntax) do
		if file.name:find('%.' .. ext .. '%.gpg$') then
			win:set_syntax(syntax)
			break
		end
	end
end

-- per-window configuration options
vis.events.subscribe(vis.events.WIN_OPEN, function(win)
	vis:command('set autoindent')
	win.options.showtabs = win.options.expandtab
	gpgfixft(win)
end)

-- file save hook to clean up the white space
vis.events.subscribe(vis.events.FILE_SAVE_PRE, function(file, path)
	-- convert \r\n to \n (vis only supports Unix newlines)
	for i=1, #file.lines do
		if string.match(file.lines[i], '\r$') then
			file.lines[i] = string.gsub(file.lines[i], '\r$', '')
		end
	end

	-- are we saving a patch file?  if file is in the current window (as
	-- it will be for a normal :w command), then we can check the window's
	-- syntax.  but if file is not the current window (e.g., a non-focused
	-- window being saved by :X w), then all we have to go on is the file
	-- name; assume *.patch and *.diff files are patches.
	local is_patch =
		string.match(file.name, '.patch$') or
		string.match(file.name, '.diff$') or
		(vis.win.file == file and vis.win.syntax == 'diff')

	-- trim trailing white space (except for patch files)
	if not is_patch then
		for i=1, #file.lines do
			if string.match(file.lines[i], '[ \t]$') then
				file.lines[i] = string.gsub(file.lines[i], '[ \t]*$', '')
			end
		end
	end

	-- ensure there is one (and only one) newline at EOF
	if file.size > 0 then
		if file:content(file.size-1, 1) == '\n' then
			while file.size > 1 and file:content(file.size-2, 1) == '\n' do
				file:delete(file.size-2, 1)
			end
		else
			file:insert(file.size, '\n')
		end
	end

	return true
end)

-- make it easier to copy to/from clipboard
vis:map(vis.modes.NORMAL, '\\y', '"+y')
vis:map(vis.modes.NORMAL, '\\p', '"+p')
vis:map(vis.modes.NORMAL, '\\Y', '"*y')
vis:map(vis.modes.NORMAL, '\\P', '"*p')
vis:map(vis.modes.VISUAL, '\\y', '"+y')
vis:map(vis.modes.VISUAL, '\\p', '"+p')
vis:map(vis.modes.VISUAL, '\\Y', '"*y')
vis:map(vis.modes.VISUAL, '\\P', '"*p')

-- option which defines a goal width for the gq operator
--
-- in vim, this is option is called "textwidth" (abbreviated "tw"), but in vis
-- "tw" is an alias for "tabwidth"; instead, use "fc" (an abbreviation for
-- "fill-column", the equivalent emacs variable).
vis:option_register("fc", "number", function(fc)
	if not vis.win then return false end
	vis.win.fillcolumn = math.floor(fc)
	return true
end, "Goal width for paragraph filling (gq)")

-- vim-like gq operator for rewrapping text
vis:operator_new("gq", function(file, range, pos)
	local fc = (vis.win.fillcolumn or 0) > 0 and vis.win.fillcolumn or vis.win.options.colorcolumn
	local warg = (fc ~= nil and fc > 0) and " -w" .. fc or ""
	-- fp is like fmt(1) but better: it knows about comments, lists, etc.
	-- see: https://github.com/ixtenu/fp
	local status, out, err = vis:pipe(file, range, "fp" .. warg)
	if status ~= 0 then
		vis:info(err)
	else
		file:delete(range)
		file:insert(range.start, out)
	end
	return range.start -- new cursor location
end, "Rewrap text operator")

-- shortcuts for gq operator
vis:map(vis.modes.NORMAL, 'Q', 'gqap')
vis:map(vis.modes.INSERT, '<M-q>', '<Escape>gqap}ha')

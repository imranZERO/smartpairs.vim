vim9script

# smartpairs.vim - Sensible pairings
# Author: Federico Ramirez <fedra.arg@gmail.com>
# Maintainer: Imran H. <imran.leave@gmail.com>
# Repository: https://github.com/imranZERO/smartpairs.vim

if exists('g:loaded_smartpairs') || v:version < 900
    finish
endif
g:loaded_smartpairs = 1

g:smartpairs_default_pairs = {
    \ '(': ')',
    \ '[': ']',
    \ '{': '}',
    \ '"': '"',
    \ "'": "'",
    \ }
g:smartpairs_pairs = {}
g:smartpairs_pairs['vim'] = { '(': ')', '[': ']', '{': '}', "'": "'" }
g:smartpairs_pairs['javascript'] = { '(': ')', '[': ']', '{': '}', '"': '"', "'": "'", '`': '`' }

# UTILITY FUNCTIONS
# ==============================================================================
def IsSpaceOrEmpty(char: string): bool
    return char == '' || char =~ '\s'
enddef

# Symmetric pairs, such as "" and '' behave differently when deleting. We want
# to be more conservative. So it will only delete if:
#   - The previous character is different from the opening
#   - The previous character is a space or empty
def BackspaceForSymmetricPairs(prevchar: string): string
    var nextchar = getline('.')[col('.') - 1]
    if nextchar != b:smartpairs_pairs[prevchar] | return "\<BS>" | endif

    var prevprevchar = getline('.')[col('.') - 3]
    if IsSpaceOrEmpty(prevprevchar) || prevprevchar != prevchar
        return "\<C-G>U\<Right>\<BS>\<BS>"
    endif

    return "\<BS>"
enddef

# Asymmetric pairs are simpler. We just delete them if they match.
def BackspaceForAsymmetricPairs(prevchar: string): string
    var nextchar = getline('.')[col('.') - 1]
    if nextchar == b:smartpairs_pairs[prevchar]
        return "\<C-G>U\<Right>\<BS>\<BS>"
    else
        return "\<BS>"
    endif
enddef

# KEYBINDED FUNCTIONS
# ==============================================================================
def Jump(char: string): string
    if get(g:, 'smartpairs_jumps_enabled', 1) == 0 | return char | endif

    var nextchar = getline('.')[col('.') - 1]
    if nextchar == char
        return "\<C-G>U\<Right>"
    else
        return char
    endif
enddef

def InsertOrJump(open: string, close: string): string
    var prevchar = getline('.')[col('.') - 2]
    # We want to always return the actual value if we are trying to escape something
    if prevchar == '\' | return open | endif

    var jump = Jump(open)
    if jump != open | return jump | endif

    # Jump failed, we are inserting now.
    # If the next char is a word, don't expand
    var nextchar = getline('.')[col('.') - 1]
    if nextchar =~ '\w'
        return open
    endif

    # If pair is ASYMMETRIC, just return expansion
    if open != close
        return open .. close .. "\<C-G>U\<Left>"
    endif

    # When the pair is SYMMETRIC. We want to expand if:
    #   - The previous character different from the opening AND is word
    #   - The previous char is a space or empty
    if (open != prevchar && prevchar !~ '\w') || IsSpaceOrEmpty(prevchar)
        return open .. close .. "\<C-G>U\<Left>"
    else
        return open
    endif
enddef

def Backspace(): string
    if !exists('b:smartpairs_pairs') | return "\<BS>" | endif

    var prevchar = getline('.')[col('.') - 2]
    if !has_key(b:smartpairs_pairs, prevchar) | return "\<BS>" | endif

    if prevchar == b:smartpairs_pairs[prevchar]
        return BackspaceForSymmetricPairs(prevchar)
    else
        return BackspaceForAsymmetricPairs(prevchar)
    endif
enddef

def CarriageReturn(): string
    if !exists('b:smartpairs_pairs') | return "\<CR>" | endif

    var prevchar = getline('.')[col('.') - 2]
    var nextchar = getline('.')[col('.') - 1]

    if has_key(b:smartpairs_pairs, prevchar) && nextchar == b:smartpairs_pairs[prevchar]
		return "\<CR>\<UP>\<END>\<CR>"
    else
        return "\<CR>"
    endif
enddef

# INITIALIZATION
# ==============================================================================
def g:SetUpMappings(): void
    var keys = keys(b:smartpairs_pairs)
    for opening in keys
        execute 'inoremap <script><expr><buffer><silent> ' .. opening .. ' <SID>InsertOrJump("' .. escape(opening, '"') .. '", "' .. escape(b:smartpairs_pairs[opening], '"') .. '")'
        if opening != b:smartpairs_pairs[opening]
            execute 'inoremap <script><expr><buffer><silent> ' .. b:smartpairs_pairs[opening] .. ' <SID>Jump("' .. escape(b:smartpairs_pairs[opening], '"') .. '")'
        endif
    endfor
enddef

def g:SmartPairsInitialize(): void
    if get(b:, 'smartpairs_mappings_initialize', 0) == 0
        b:smartpairs_mappings_initialize = 1
        b:smartpairs_pairs = has_key(g:smartpairs_pairs, &filetype) ? g:smartpairs_pairs[&filetype] : g:smartpairs_default_pairs
        g:SetUpMappings()
    endif
enddef

autocmd FileType * g:SmartPairsInitialize()

if get(g:, 'smartpairs_hijack_return', 1)
    imap <script><expr> <CR> <SID>CarriageReturn()
endif

if get(g:, 'smartpairs_hijack_backspace', 1)
    imap <script><expr><silent> <BS> <SID>Backspace()
endif

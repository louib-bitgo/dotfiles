local LSP_ENABLED_VAR_NAME = 'LSP_ENABLED'
local COPILOT_ENABLED_VAR_NAME = 'COPILOT_ENABLED'
local ENABLED_FORMATTING_TOOL_VAR_NAME = 'ENABLED_FORMATTING_TOOL'
local ENABLED_LINTING_TOOL_VAR_NAME = 'ENABLED_LINTING_TOOL'
local DEFAULT_COLORSCHEME = 'sonokai'

local function executable_is_available(executable_name)
  local handle = io.popen(string.format('which %s 2> /dev/null', executable_name))
  if not handle then
    return false
  end

  local output = handle:read('*a')
  handle:close()

  if string.find(output, executable_name) then
    return true
  end

  return false
end

local function get_prettier_formatting_config()
  if not pcall(require, 'formatter.util') then
    return {}
  end

  -- Utilities for creating configurations
  local formatter_util = require('formatter.util')

  if executable_is_available('prettier') then
    local buffer_number = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_var(buffer_number, ENABLED_FORMATTING_TOOL_VAR_NAME, 'prettier')

    -- I do not install prettier on my host machines, which means that if prettier is installed,
    -- I should probably be using it.
    return {
      exe = 'prettier',
      args = {
        '--stdin-filepath',
        formatter_util.escape_path(formatter_util.get_current_buffer_file_path()),
      },
      stdin = true,
    }
  end

  -- TODO about tslint
  return {}
end

local function get_terraform_formatting_config()
  if not pcall(require, 'formatter.util') then
    return {}
  end

  -- Utilities for creating configurations
  local formatter_util = require('formatter.util')

  if not executable_is_available('terraform') then
    return {}
  end

  local buffer_number = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_var(buffer_number, ENABLED_FORMATTING_TOOL_VAR_NAME, 'terraform fmt')

  return {
    exe = 'terraform',
    args = {
      'fmt',
      '-write=true',
      '-',
      formatter_util.escape_path(formatter_util.get_current_buffer_file_path()),
    },
    stdin = true,
  }
end

local function get_project_name()
  local current_dir = vim.fn.getcwd()

  local last_dir_name = nil
  for dir_name in string.gmatch(current_dir, '//') do
    last_dir_name = dir_name
    print(dir_name)
  end

  return last_dir_name
end

local function set_filetype_options()
  local buffer_number = vim.api.nvim_get_current_buf()
  local filetype = vim.api.nvim_buf_get_option(buffer_number, 'filetype')
  -- Apparently this is the only way to get the path associated with a buffer.
  local buffer_path = vim.api.nvim_buf_get_name(buffer_number)

  -- Default if we cannot detect the filetype.
  vim.wo.spell = false
  vim.bo.tabstop = 2
  vim.bo.shiftwidth = 2
  vim.bo.expandtab = true
  vim.bo.makeprg = 'echo "Make is disabled for this filetype."'

  -- TODO not sure that this makes sense just yet.
  vim.wo.colorcolumn = '100'

  if filetype == 'typescript' or filetype == 'javascript' or filetype == 'yaml' then
    -- We call this function here because is has the side-effect of detecting which formatting
    -- tools are available at this time.
    get_prettier_formatting_config()
  end

  if filetype == 'sh' then
    vim.bo.makeprg = 'shellcheck -f gcc %'
    vim.api.nvim_buf_set_var(buffer_number, ENABLED_LINTING_TOOL_VAR_NAME, 'shellcheck')
    vim.bo.tabstop = 4
    vim.bo.shiftwidth = 4
    return
  end

  if filetype == 'rust' then
    vim.bo.makeprg = 'cargo build -q --message-format short'
    vim.api.nvim_buf_set_var(buffer_number, ENABLED_LINTING_TOOL_VAR_NAME, 'cargo')
    vim.api.nvim_buf_set_var(buffer_number, ENABLED_FORMATTING_TOOL_VAR_NAME, 'rustfmt')
    vim.bo.tabstop = 4
    vim.bo.shiftwidth = 4
    return
  end

  if filetype == 'lua' then
    vim.api.nvim_buf_set_var(buffer_number, ENABLED_FORMATTING_TOOL_VAR_NAME, 'stylua')
    return
  end

  if filetype == 'go' then
    vim.bo.tabstop = 2
    vim.bo.shiftwidth = 2
    -- Apparently using tabs is a convention for Go code?
    vim.bo.expandtab = false
    return
  end

  if filetype == 'nix' then
    -- see :help filename-modifiers
    -- :p means the full path
    -- :h means the head (last component) removed.
    -- nix check flake requires the directory in which the flake resides, not the
    -- path to the flake itself.
    if string.match(buffer_path, 'flake.nix') then
      vim.bo.makeprg = 'nix flake check %:p:h'
      vim.api.nvim_buf_set_var(buffer_number, ENABLED_LINTING_TOOL_VAR_NAME, 'nix flake check')
    end
    vim.api.nvim_buf_set_var(buffer_number, ENABLED_FORMATTING_TOOL_VAR_NAME, 'alejandra')
    return
  end

  if filetype == 'cpp' then
    vim.bo.tabstop = 4
    vim.bo.shiftwidth = 4
    vim.api.nvim_buf_set_var(buffer_number, ENABLED_FORMATTING_TOOL_VAR_NAME, 'clang-format')
    return
  end

  if filetype == 'python' then
    vim.bo.tabstop = 4
    vim.bo.shiftwidth = 4
    return
  end

  if filetype == 'terraform' then
    -- We call this function here because is has the side-effect of detecting which formatting
    -- tools are available at this time.
    get_terraform_formatting_config()
    return
  end

  if filetype == 'gitcommit' then
    vim.wo.colorcolumn = '50'
    return
  end

  if filetype == 'xml' then
    -- vim.g['xml_syntax_folding'] = 1
    -- TODO syntax folding would be better, but for that I would need an XML syntax
    -- file.
    vim.wo.foldmethod = 'indent'
    vim.wo.foldnestmax = 1
    vim.wo.foldminlines = 0
    return
  end

  if filetype == 'yaml' then
    if string.match(buffer_path, '.github/workflows/') then
      vim.bo.makeprg = 'actionlint -oneline -shellcheck shellcheck %'
      vim.bo.errorformat = '%f:%l:%c: %m'
      vim.api.nvim_buf_set_var(buffer_number, ENABLED_LINTING_TOOL_VAR_NAME, 'actionlint')
      return
    end
  end

  -- Running spell checking by default on specific text files.
  -- See https://vimtricks.com/p/vimtrick-spell-checking-in-vim/ for
  -- the spell checking shortcuts.
  if filetype == 'tex' then
    vim.wo.spell = true
    return
  end
  if filetype == 'markdown' then
    vim.wo.spell = true
    return
  end
end

local function escape_termcode(raw_termcode)
  -- Adjust boolean arguments as needed
  return vim.api.nvim_replace_termcodes(raw_termcode, true, true, true)
end

local function configure_auto_format()
  if not pcall(require, 'formatter') then
    print('formatter is not installed.')
    return
  end
  if not pcall(require, 'formatter.util') then
    print('formatter.util is not installed.')
    return
  end

  -- Utilities for creating configurations
  local formatter_util = require('formatter.util')

  local get_cpp_config = function()
    return {
      exe = 'clang-format',
      stdin = true,
    }
  end

  local get_nix_config = function()
    return {
      exe = 'alejandra',
      stdin = true,
      args = {
        '-q',
        '-',
      },
    }
  end

  local get_rust_config = function()
    return {
      exe = 'rustfmt',
      stdin = true,
    }
  end

  local get_lua_config = function()
    return {
      exe = 'stylua',
      args = {
        '--search-parent-directories',
        '--stdin-filepath',
        formatter_util.escape_path(formatter_util.get_current_buffer_file_path()),
        '--',
        '-',
      },
      stdin = true,
    }
  end

  -- Provides the Format and FormatWrite commands
  -- See https://github.com/mhartington/formatter.nvim#configuration-specification
  -- for all the configuration options.
  require('formatter').setup({
    -- Enable or disable logging
    logging = false,
    -- Set the log level
    log_level = vim.log.levels.WARN,

    -- All formatter configurations are opt-in
    filetype = {
      cpp = {
        get_cpp_config,
      },
      rust = {
        get_rust_config,
      },
      nix = {
        get_nix_config,
      },
      lua = {
        get_lua_config,
      },
      javascript = {
        get_prettier_formatting_config,
      },
      typescript = {
        get_prettier_formatting_config,
      },
      yaml = {
        get_prettier_formatting_config,
      },
      terraform = {
        get_terraform_formatting_config,
      },
    },
  })

  -- this will format and write the buffer after saving.
  vim.cmd([[
    augroup FormatAutogroup
      autocmd!
      autocmd BufWritePost * FormatWrite
    augroup END
  ]])
end

local feedkey = function(key, mode)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, true, true), mode, true)
end

local function configure_auto_completion()
  vim.go.omnifunc = 'syntaxcomplete#Complete'

  if not pcall(require, 'cmp') then
    print('cmp is not installed.')
    return
  end

  -- Setup nvim-cmp.
  local cmp = require('cmp')

  cmp.setup({
    snippet = {
      -- REQUIRED - you must specify a snippet engine
      expand = function(args)
        vim.fn['vsnip#anonymous'](args.body) -- For `vsnip` users.
        -- require('luasnip').lsp_expand(args.body) -- For `luasnip` users.
        -- require('snippy').expand_snippet(args.body) -- For `snippy` users.
        -- vim.fn["UltiSnips#Anon"](args.body) -- For `ultisnips` users.
      end,
    },
    window = {
      -- completion = cmp.config.window.bordered(),
      -- documentation = cmp.config.window.bordered(),
    },
    mapping = cmp.mapping.preset.insert({
      ['<C-k>'] = cmp.mapping(function()
        if cmp.visible() then
          cmp.select_prev_item()
        elseif vim.fn['vsnip#jumpable'](-1) == 1 then
          feedkey('<Plug>(vsnip-jump-prev)', '')
        end
      end, { 'i', 's' }),
      ['<C-j>'] = cmp.mapping(function()
        if cmp.visible() then
          cmp.select_next_item()
        end
      end, { 'i', 's' }),
      ['<C-b>'] = cmp.mapping.scroll_docs(-4),
      ['<C-f>'] = cmp.mapping.scroll_docs(4),
      ['<C-Space>'] = cmp.mapping.complete(),
      ['<C-e>'] = cmp.mapping.abort(),
      -- Require Tab to accept a suggestion without confirmation, but Enter to
      -- accept if explicitely selected.
      ['<Tab>'] = cmp.mapping.confirm({ select = true }),
      ['<CR>'] = cmp.mapping.confirm({ select = false }),
    }),
    sources = cmp.config.sources({
      { name = 'nvim_lsp' },
      { name = 'vsnip' }, -- For vsnip users.
      -- { name = 'luasnip' }, -- For luasnip users.
      -- { name = 'ultisnips' }, -- For ultisnips users.
      -- { name = 'snippy' }, -- For snippy users.
    }, {
      { name = 'buffer' },
    }, {
      -- This uses cmp-path
      -- See https://github.com/hrsh7th/cmp-path#configuration for details
      -- on how to configure.
      { name = 'path' },
    }),
  })

  -- Set configuration for specific filetype.
  cmp.setup.filetype('gitcommit', {
    sources = cmp.config.sources({
      { name = 'cmp_git' }, -- You can specify the `cmp_git` source if you were installed it.
    }, {
      { name = 'buffer' },
    }),
  })

  -- Use buffer source for `/` (if you enabled `native_menu`, this won't work anymore).
  cmp.setup.cmdline('/', {
    mapping = cmp.mapping.preset.cmdline(),
    sources = {
      { name = 'buffer' },
    },
  })

  -- Commenting out this one for the moment since it breaks using the '%' as a shorthand
  -- for the current buffer file path
  -- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
  -- cmp.setup.cmdline(':', {
  --   mapping = cmp.mapping.preset.cmdline(),
  --   sources = cmp.config.sources({
  --     { name = 'cmdline' },
  --   }, {
  --     { name = 'path' },
  --   }),
  -- })

  vim.o.completeopt = 'menu,menuone,noselect'
end

local function configure_status_bar()
  if not pcall(require, 'lualine') then
    print('lualine is not installed.')
    return
  end

  -- https://github.com/nvim-lualine/lualine.nvim#available-components
  -- for the available components.
  require('lualine').setup({
    options = {
      -- FIXME what do I need to enable the icons?
      icons_enabled = false,
      theme = DEFAULT_COLORSCHEME,
      component_separators = { left = '', right = '' },
      section_separators = { left = '', right = '' },
      disabled_filetypes = {},
      always_divide_middle = true,
      globalstatus = false,
    },
    sections = {
      lualine_a = {
        {
          'mode',
          padding = 1,
        },
      },
      lualine_b = {
        {
          'branch',
          padding = 1,
        },
        {
          'diff',
          padding = 1,
        },
        {
          'diagnostics',
          padding = 1,
        },
      },
      lualine_c = {
        {
          'filename',
          -- 0: Just the filename
          -- 1: Relative path
          -- 2: Absolute path
          -- 3: Absolute path, with tilde as the home directory
          path = 1,
          padding = 1,
        },
      },
      lualine_x = {
        {
          function()
            local tools = ''

            local copilot_enabled, copilot_response = pcall(vim.api.nvim_buf_get_var, 0, COPILOT_ENABLED_VAR_NAME)
            if copilot_enabled and copilot_response then
              if string.len(tools) == 0 then
                tools = 'copilot'
              else
                tools = tools .. ',copilot'
              end
            end

            local lsp_enabled, lsp_tool_name = pcall(vim.api.nvim_buf_get_var, 0, LSP_ENABLED_VAR_NAME)
            if lsp_enabled and lsp_tool_name then
              if string.len(tools) == 0 then
                tools = 'lsp'
              else
                tools = tools .. ',lsp'
              end
            end

            local linter_enabled, linter_tool_name = pcall(vim.api.nvim_buf_get_var, 0, ENABLED_LINTING_TOOL_VAR_NAME)
            if linter_enabled and linter_tool_name then
              if string.len(tools) == 0 then
                tools = linter_tool_name
              else
                tools = tools .. ',' .. linter_tool_name
              end
            end

            local formatter_enabled, formatter_tool_name =
              pcall(vim.api.nvim_buf_get_var, 0, ENABLED_FORMATTING_TOOL_VAR_NAME)
            if formatter_enabled and formatter_tool_name then
              if string.len(tools) == 0 then
                tools = tools .. formatter_tool_name
              else
                tools = tools .. ',' .. formatter_tool_name
              end
            end

            -- TODO add an emoji to indicate errors when configuring the tools.

            if string.len(tools) == 0 then
              return ''
            else
              return string.format('[%s]', tools)
            end
          end,
          padding = 1,
        },
      },
      lualine_y = {
        'progress',
      },
      lualine_z = {
        {
          function()
            -- local current_buffer = vim.api.nvim_get_current_buf()
            local cursor = vim.api.nvim_win_get_cursor(0)
            local _, column = unpack(cursor)
            -- The column returned by the vim API starts at 0,
            -- so we increment it here.
            return string.format('%s', column + 1)
          end,
          padding = 1,
        },
      },
    },
    inactive_sections = {
      lualine_a = {},
      lualine_b = {},
      lualine_c = {
        {
          'filename',
          -- 0: Just the filename
          -- 1: Relative path
          -- 2: Absolute path
          -- 3: Absolute path, with tilde as the home directory
          path = 1,
          padding = 1,
        },
      },
      lualine_x = {},
      lualine_y = {},
      lualine_z = {},
    },
    tabline = {
      lualine_a = {
        {
          'buffers',
          show_modified_status = true,

          -- 0: Shows buffer name
          -- 1: Shows buffer index
          -- 2: Shows buffer name + buffer index
          -- 3: Shows buffer number
          -- 4: Shows buffer name + buffer number
          mode = 2,

          max_length = vim.o.columns,

          symbols = {
            -- Text to show when the buffer is modified
            modified = ' ●',
            -- Text to show to identify the alternate file
            alternate_file = '',
            -- Text to show when the buffer is a directory
            directory = '📁',
          },
        },
      },
      lualine_b = {},
      lualine_c = {},
      lualine_x = {},
      lualine_y = {},
      lualine_z = {},
    },
    extensions = {},
  })

  vim.api.nvim_set_keymap('n', '<Space>1', ':LualineBuffersJump 1<Enter>', { silent = false, noremap = true })
  vim.api.nvim_set_keymap('n', '<Space>2', ':LualineBuffersJump 2<Enter>', { silent = false, noremap = true })
  vim.api.nvim_set_keymap('n', '<Space>3', ':LualineBuffersJump 3<Enter>', { silent = false, noremap = true })
  vim.api.nvim_set_keymap('n', '<Space>4', ':LualineBuffersJump 4<Enter>', { silent = false, noremap = true })
  vim.api.nvim_set_keymap('n', '<Space>5', ':LualineBuffersJump 5<Enter>', { silent = false, noremap = true })
  vim.api.nvim_set_keymap('n', '<Space>6', ':LualineBuffersJump 6<Enter>', { silent = false, noremap = true })
  vim.api.nvim_set_keymap('n', '<Space>7', ':LualineBuffersJump 7<Enter>', { silent = false, noremap = true })
  vim.api.nvim_set_keymap('n', '<Space>8', ':LualineBuffersJump 8<Enter>', { silent = false, noremap = true })
  vim.api.nvim_set_keymap('n', '<Space>9', ':LualineBuffersJump 9<Enter>', { silent = false, noremap = true })
end

local function configure_lastplace()
  if not pcall(require, 'nvim-lastplace') then
    print('nvim-lastplace is not installed.')
    return
  end

  -- Currently using the default settings. See
  -- https://github.com/ethanholz/nvim-lastplace#installation
  require('nvim-lastplace').setup({
    lastplace_ignore_buftype = { 'quickfix', 'nofile', 'help' },
    lastplace_ignore_filetype = { 'gitcommit', 'gitrebase', 'svn', 'hgcommit' },
    lastplace_open_folds = true,
  })
end

local function configure_lsp()
  if not pcall(require, 'lspconfig') then
    print('lspconfig is not installed.')
    return
  end

  local custom_lsp_attach = function(client, buffer_number)
    -- Use LSP as the handler for omnifunc.
    --    See `:help omnifunc` and `:help ins-completion` for more information.
    vim.api.nvim_buf_set_option(buffer_number, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

    -- Use LSP as the handler for formatexpr.
    --    See `:help formatexpr` for more information.
    vim.api.nvim_buf_set_option(buffer_number, 'formatexpr', 'v:lua.vim.lsp.formatexpr()')

    -- Mappings.
    -- See `:h :map-arguments` for the options available when mapping
    local mapping_options = { noremap = true, silent = true, buffer = buffer_number }

    -- See `:help vim.lsp.*` for documentation on any of the below functions
    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, mapping_options)
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, mapping_options)

    vim.keymap.set('n', '<C-s>', vim.lsp.buf.signature_help, mapping_options)

    vim.api.nvim_buf_set_var(buffer_number, LSP_ENABLED_VAR_NAME, true)
  end

  local lsp_flags = {
    -- This is the default in Nvim 0.7+
    debounce_text_changes = 150,
  }

  local rust_analyzer_features = {}
  -- FIXME the get_project_name() function is still untested, but
  -- could be useful in the future.
  -- if get_project_name() == "project-name" then
  --   rust_analyzer_features = {"allo"}
  -- end

  require('lspconfig').rust_analyzer.setup({
    on_attach = custom_lsp_attach,
    flags = lsp_flags,
    -- Server-specific settings...
    settings = {
      ['rust-analyzer'] = {
        cargo = {
          features = rust_analyzer_features,
        },
      },
    },
  })

  -- Documented at https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#lua_ls
  require('lspconfig').lua_ls.setup({
    on_attach = custom_lsp_attach,
    flags = lsp_flags,
    settings = {
      Lua = {
        runtime = {
          -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
          version = 'LuaJIT',
        },
        diagnostics = {
          -- Get the language server to recognize the `vim` global
          globals = { 'vim' },
        },
        workspace = {
          -- Make the server aware of Neovim runtime files
          library = vim.api.nvim_get_runtime_file('', true),
        },
        -- Do not send telemetry data containing a randomized but unique identifier
        telemetry = {
          enable = false,
        },
      },
    },
  })

  -- Documented at https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#tsserver
  require('lspconfig').tsserver.setup({
    on_attach = custom_lsp_attach,
    flags = lsp_flags,
  })

  -- Documented at https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#rnix
  require('lspconfig').rnix.setup({
    on_attach = custom_lsp_attach,
    flags = lsp_flags,
  })

  require('lspconfig').clangd.setup({
    on_attach = custom_lsp_attach,
    flags = lsp_flags,
    settings = {
      ['clangd'] = {},
    },
  })

  require('lspconfig').jsonls.setup({
    on_attach = custom_lsp_attach,
    flags = lsp_flags,
  })

  require('lspconfig').taplo.setup({
    on_attach = custom_lsp_attach,
    flags = lsp_flags,
  })

  require('lspconfig').dockerls.setup({
    on_attach = custom_lsp_attach,
    flags = lsp_flags,
  })

  -- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#yamlls
  require('lspconfig').yamlls.setup({
    on_attach = custom_lsp_attach,
    flags = lsp_flags,
    settings = {
      ['yaml'] = {
        -- Name has to be in camelCase because this is what the yaml-language-server uses.
        keyOrdering = false,
        redhat = {
          telemetry = {
            enabled = false,
          },
        },
      },
    },
  })

  require('lspconfig').bashls.setup({
    on_attach = custom_lsp_attach,
    flags = lsp_flags,
  })

  -- See https://github.com/neovim/nvim-lspconfig#suggested-configuration for
  -- the suggested top-level configuration and https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
  -- for a list of all the available language servers.

  -- TODO add sumneko_lua support.
  -- TODO add eslint support?
  -- TODO add vanilla JS support?
  -- TODO add dockerfile support?
  -- TODO add python support
end

local function configure_key_bindings()
  -- See all the available modes here https://github.com/nanotee/nvim-lua-guide#defining-mappings
  -- See all the available options here https://neovim.io/doc/user/map.html#:map-arguments

  -- Window navigation and creation
  -- I no longer support vertical splits, only horizontal splits.
  vim.api.nvim_set_keymap('n', '<Space>s', '<C-w>s', { silent = true, noremap = true })
  vim.api.nvim_set_keymap('n', '<Space>c', '<C-w>c', { silent = true, noremap = true })
  vim.api.nvim_set_keymap('n', '<Space>j', '<C-w>j', { silent = true, noremap = true })
  vim.api.nvim_set_keymap('n', '<Space>k', '<C-w>k', { silent = true, noremap = true })

  -- Buffer management
  -- Buffer navigation is now handled by lualine.
  vim.api.nvim_set_keymap('n', '<Space>d', ':bdelete<Enter>', { silent = false, noremap = true })
  vim.api.nvim_set_keymap('n', '<Space>h', ':bprevious<Enter>', { silent = false, noremap = true })
  vim.api.nvim_set_keymap('n', '<Space>l', ':bnext<Enter>', { silent = false, noremap = true })

  -- This unsets the "last search pattern" register by hitting return
  -- Credits to https://stackoverflow.com/a/662914
  vim.api.nvim_set_keymap('n', '<CR>', ':noh<CR><CR>', { silent = false, noremap = true })

  vim.api.nvim_set_keymap('', '<C-c>', '"+y', { silent = false, noremap = false })

  -- Using the 'q' buffer as the quick buffer, with easy re-apply!
  -- Start recording that buffer with `qq`.
  -- Stop recording with `q`.
  -- Apply with space+q !!!
  vim.api.nvim_set_keymap('n', '<Space>q', '@q', { silent = false, noremap = true })

  -- When in terminal mode, I don't want to remap Esc to exit, because the terminal
  -- line cannot be modified from the nvim buffer. I might want to use the vi mode from bash
  -- to edit the line by pressing Esc instead.
  vim.api.nvim_set_keymap('t', '<Space><Esc>', '<C-\\><C-n>', { silent = false, noremap = true })
end

local function configure_commenting()
  if not pcall(require, 'Comment') then
    print('Comment is not installed.')
    return
  end

  -- See https://github.com/numToStr/Comment.nvim#configuration-optional
  require('Comment').setup({
    padding = true,

    ---LHS of operator-pending mappings in NORMAL + VISUAL mode
    ---@type table
    opleader = {
      ---Line-comment keymap
      line = 'gc',
      ---Block-comment keymap
      block = 'gb',
    },
  })
end

local function configure_copilot()
  if not pcall(require, 'copilot') then
    print('copilot is not installed.')
    return
  end

  if os.getenv('NVIM_ENABLE_COPILOT') ~= 'true' then
    print('Copilot is disabled.')
    return
  end

  -- You still need to call :Copilot auth to authenticated the device for
  -- the first time.

  -- Default settings, as defined
  -- here https://github.com/zbirenbaum/copilot.lua#setup-and-configuration
  require('copilot').setup({
    panel = {
      enabled = true,
      auto_refresh = false,
      keymap = {
        jump_prev = '[[',
        jump_next = ']]',
        accept = '<CR>',
        refresh = 'gr',
        open = '<M-CR>',
      },
      layout = {
        position = 'bottom', -- | top | left | right
        ratio = 0.4,
      },
    },
    suggestion = {
      enabled = true,
      auto_trigger = false,
      debounce = 75,
      keymap = {
        accept = '<M-l>',
        accept_word = false,
        accept_line = false,
        next = '<M-]>',
        prev = '<M-[>',
        dismiss = '<C-]>',
      },
    },
    filetypes = {
      -- filetypes here can be boolean values or functions that return a boolean value.
      -- See https://github.com/zbirenbaum/copilot.lua#filetypes
      yaml = false,
      markdown = false,
      help = false,
      gitcommit = false,
      gitrebase = false,
      hgcommit = false,
      svn = false,
      cvs = false,
      ['.'] = false,
    },
    copilot_node_command = 'node', -- Node.js version must be > 16.x
    server_opts_overrides = {},
  })

  local buffer_number = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_var(buffer_number, COPILOT_ENABLED_VAR_NAME, true)

  -- TODO also enable copilot-cmp
end

local function configure_git_blame()
  if not pcall(require, 'gitblame') then
    print('gitblame is not installed.')
    return
  end

  -- TODO add the git blame status to the status line
  -- https://github.com/f-person/git-blame.nvim#statusline-integration

  vim.cmd([[
    let g:gitblame_date_format = '%Y-%m-%d %X (%r)'
  ]])
end

local function configure_global_options()
  -- wo = window options
  -- bo = buffer options
  -- o = global options
  vim.o.encoding = 'utf8'

  -- This is for intelligent merging of lines. Will handle comments for example.
  vim.o.formatoptions = 'jcroql'

  -- Make searching case insensitive
  vim.o.ignorecase = true
  -- ... unless the query has capital letters.
  vim.o.smartcase = true

  -- Disabling mainly for security reasons
  vim.o.modeline = false

  -- Always show the status line
  vim.o.laststatus = 2

  vim.o.background = 'dark'

  if os.getenv('NVIM_ANSI_COLORS') == 'true' then
    vim.o.termguicolors = false
  else
    vim.o.termguicolors = true
  end

  vim.o.pastetoggle = '<F5>'

  -- This will render the trailing spaces and the tabs in a visible way.
  vim.o.listchars = 'tab:>-,trail:·'
  vim.o.list = true

  vim.wo.number = true
  vim.wo.relativenumber = true
  vim.wo.cursorline = true

  -- Not sure why but foldlevelstart is a global option, and the
  -- option folding options are at the window level...
  vim.o.foldlevelstart = 999
  -- Do not fold any of the block dy default.
  vim.o.foldlevel = 99

  -- TODO configure vim.o.wildignore ??

  -- the grep related configuration is inspired by
  -- https://gist.github.com/romainl/56f0c28ef953ffc157f36cc495947ab3
  -- FIXME switch to rg when I installed it in the neovim container.
  -- vim.go.grepprg = "rg --vimgrep"
  -- vim.go.grepformat = "%f:%l:%c:%m"
  vim.go.grepprg = 'grep --binary-files=without-match --exclude-dir=target/ --exclude-dir=.git/ -rni'

  local colorscheme = DEFAULT_COLORSCHEME
  pcall(vim.cmd, 'colorscheme ' .. colorscheme)
end

local function configure_nvim()
  vim.api.nvim_command('syntax on')

  -- Enable filetype detection
  vim.cmd([[
    filetype plugin on
    filetype plugin indent on
  ]])

  -- Calling packloadall is not necessary, because it will be called after
  -- running the init.lua anyway. Leaving here in case we want to load the plugins
  -- earlier in the future.
  -- vim.api.nvim_command('packloadall')
  --

  vim.api.nvim_create_autocmd('FileType', {
    pattern = '*',
    callback = function()
      vim.schedule(set_filetype_options)
    end,
  })

  vim.cmd([[
    augroup quickfix
        autocmd!
        autocmd QuickFixCmdPost [^l]* cwindow
        autocmd QuickFixCmdPost l* lwindow
    augroup END
  ]])

  -- Used to close all the buffers except the current buffer.
  vim.cmd([[
    command! BufOnly silent! execute "%bd|e#|bd#"
  ]])
end

local function configure()
  configure_nvim()
  configure_global_options()
  configure_key_bindings()
  configure_auto_format()
  configure_auto_completion()
  configure_commenting()
  configure_git_blame()
  configure_copilot()
  configure_lsp()
  configure_lastplace()
  configure_status_bar()
end

configure()

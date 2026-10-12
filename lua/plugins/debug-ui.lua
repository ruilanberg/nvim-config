-- Durante uma sessão de debug o fundo fica sólido (variáveis, popups e o painel do dap-ui
-- ficam legíveis sem o texto da janela de trás aparecendo); ao terminar, volta como estava.
return {
  {
    "mfussenegger/nvim-dap",
    optional = true,
    opts = function()
      local dap = require("dap")
      local transparency = require("config.transparency")
      local was_transparent = nil ---@type boolean?

      local function on_start()
        if was_transparent == nil then
          was_transparent = transparency.enabled
          transparency.set(false, true)
        end
      end
      local function on_end()
        -- só restaura quando não sobrou nenhuma sessão (ex.: sessões filhas do js-debug)
        vim.schedule(function()
          if was_transparent ~= nil and not next(dap.sessions()) then
            transparency.set(was_transparent, true)
            was_transparent = nil
          end
        end)
      end

      dap.listeners.after.event_initialized["debug_ui_opaque"] = on_start
      dap.listeners.after.event_terminated["debug_ui_opaque"] = on_end
      dap.listeners.after.event_exited["debug_ui_opaque"] = on_end
      dap.listeners.after.disconnect["debug_ui_opaque"] = on_end
    end,
  },
}

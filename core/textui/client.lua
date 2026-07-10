local isOpen = false
local currentText = nil

TextUI = {}

---@param text string
---@param keyboardKey string|nil
function TextUI.show(text, keyboardKey)
    if currentText == text then return end

    SendNUIMessage({
        action = "ui:showTextUI",
        data = { text = text, key = keyboardKey }
    })

    isOpen = true
    currentText = text
end

function TextUI.hide()
    SendNUIMessage({
        action = "ui:hideTextUI"
    })

    isOpen = false
    currentText = nil
end

---@return boolean
function TextUI.isOpen()
    return isOpen
end

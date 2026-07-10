RegisterNUICallback("nui:chat:getMessages", function(_, resultCallback)
    local messages = lib.callback.await(_e("server:chat:getMessages"), false)
    resultCallback(messages)
end)

RegisterNUICallback("nui:chat:sendMessage", function(message, resultCallback)
    resultCallback(lib.callback.await(_e("server:chat:sendMessage"), false, message))
end)

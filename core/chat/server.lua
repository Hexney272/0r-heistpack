local lib = lib

ChatServer = {
    messages = lib.array:new()
}

ChatServer.addMessage = function(source, message)
    local xPlayerProfile = ProfileServer:getBySource(source)
    if not xPlayerProfile then return end

    local data = {
        source = source,
        illegalNickname = xPlayerProfile.illegalNickname,
        level = xPlayerProfile.level,
        time = os.date("%H:%M"),
        text = message,
        photo = xPlayerProfile.photo,
    }
    local newLength = ChatServer.messages:push(data)
    if newLength >= 50 then
        ChatServer.messages = ChatServer.messages:slice(1, 50)
    end
    return data
end

lib.callback.register(_e("server:chat:getMessages"), function(source)
    return ChatServer.messages
end)

lib.callback.register(_e("server:chat:sendMessage"), function(source, message)
    return ChatServer.addMessage(source, message)
end)

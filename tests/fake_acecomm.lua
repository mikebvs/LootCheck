-- A loopback stand-in for AceComm-3.0.
--
-- The real library needs frames, ChatThrottleLib and SendAddonMessage, none of
-- which exist outside the game. This records what would go on the wire so a
-- test can hand the exact bytes back to the receiving code path, which
-- exercises everything except the client's own message delivery.
local fake = LibStub:NewLibrary("AceComm-3.0", 1)

fake.sent = {}      -- every message "sent", newest last
fake.handlers = {}  -- prefix -> { object, methodName }

function fake:RegisterComm(prefix, method)
    fake.handlers[prefix] = { object = self, method = method or "OnCommReceived" }
end

function fake:SendCommMessage(prefix, text, distribution, target, prio, callbackFn, callbackArg)
    tinsert(fake.sent, {
        prefix = prefix,
        text = text,
        distribution = distribution,
        target = target,
        prio = prio,
    })

    if callbackFn then
        callbackFn(callbackArg, #text, #text)
    end
end

function fake:Embed(target)
    target.RegisterComm = fake.RegisterComm
    target.SendCommMessage = fake.SendCommMessage
    return target
end

--- Deliver a message to the registered handler as if it came from `sender`
function fake:Deliver(prefix, text, distribution, sender)
    local handler = fake.handlers[prefix]
    if not handler then return false end

    handler.object[handler.method](handler.object, prefix, text, distribution or "WHISPER", sender)
    return true
end

function fake:Reset()
    fake.sent = {}
end

--- The most recent message, or the most recent one whose text starts with `kind`
function fake:Last(kind)
    for i = #fake.sent, 1, -1 do
        local message = fake.sent[i]
        if not kind or message.text:sub(1, #kind) == kind then return message end
    end
end

FakeComm = fake

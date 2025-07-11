-- TweenUtil.lua
local TweenService = game:GetService("TweenService")

local TweenUtil = {}

-- Tween the CFrame of a part to a target position with given speed
-- If you specify duration instead of speed, use useDuration = true
function TweenUtil.tweenTo(part, targetCFrame, speedOrDuration, useDuration)
    assert(part and targetCFrame, "TweenUtil.tweenTo: Missing parameters")

    local distance = (targetCFrame.Position - part.Position).Magnitude
    local duration = useDuration and speedOrDuration or (distance / speedOrDuration)

    local tweenInfo = TweenInfo.new(
        duration,
        Enum.EasingStyle.Linear,
        Enum.EasingDirection.Out,
        0,
        false,
        0
    )

    local tween = TweenService:Create(part, tweenInfo, {CFrame = targetCFrame})
    tween:Play()
    return tween
end

-- Tween a model by tweening its PrimaryPart
function TweenUtil.tweenModelTo(model, targetCFrame, speedOrDuration, useDuration)
    assert(model and model:IsA("Model") and model.PrimaryPart, "TweenUtil: Model must have PrimaryPart")
    return TweenUtil.tweenTo(model.PrimaryPart, targetCFrame, speedOrDuration, useDuration)
end

return TweenUtil

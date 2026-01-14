local mjm = mjrequire "common/mjm"
local vec3 = mjm.vec3
local vec2 = mjm.vec2
--local vec4 = mjm.vec4

local skill = mjrequire "common/skill"
local model = mjrequire "common/model"
local material = mjrequire "common/material"

local roleUICommon = {
    plinthInitialXOffset = 30,--16,
    plinthInitialYOffset = 20,
    plinthSize = vec2(174,40),
    plinthPadding = vec2(30,20),
    dualDependencyOffset = 5,
}

function roleUICommon:createDerivedTreeDependencies()
    for i,skillColumn in ipairs(roleUICommon.skillUIColumns) do
        for j,skillUIInfo in ipairs(skillColumn) do
            if skillUIInfo.requiredSkillTypes then
                for k, requiredSkillTypeIndex in ipairs(skillUIInfo.requiredSkillTypes) do
                    local foundRequiredSkill = false
                    for l=1,(i - 1) do
                        local possibleRequiredColumn = roleUICommon.skillUIColumns[l]
                        for m,possibleRequiredSkillInfo in ipairs(possibleRequiredColumn) do
                            if possibleRequiredSkillInfo.skillTypeIndex and possibleRequiredSkillInfo.skillTypeIndex == requiredSkillTypeIndex then
                                foundRequiredSkill = true
                                if not possibleRequiredSkillInfo.dependentSkillsByTypeIndex then
                                    possibleRequiredSkillInfo.dependentSkillsByTypeIndex = {}
                                end
                                possibleRequiredSkillInfo.dependentSkillsByTypeIndex[skillUIInfo.skillTypeIndex] = {
                                    xDistance = i-l,
                                    yDistance = m - j,
                                    skillUIInfo = skillUIInfo,
                                }
                                if not skillUIInfo.requiredSkillDistances then
                                    skillUIInfo.requiredSkillDistances = {}
                                else
                                    skillUIInfo.hasMultipleRequiredSkills = true
                                end
                                skillUIInfo.requiredSkillDistances[possibleRequiredSkillInfo.skillTypeIndex] = {
                                    xDistance = i-l,
                                    yDistance = m - j,
                                    dualRequiredYOffset = 0.0,
                                }

                                break
                            end
                        end
                        if foundRequiredSkill then
                            break
                        end
                    end
                end

                
                if skillUIInfo.hasMultipleRequiredSkills then
                    local foundMaxY = -99
                    local foundMaxKey = nil
                    --mj:log("multiple:", skillUIInfo)
                    for m,otherRequiredDistanceInfo in pairs(skillUIInfo.requiredSkillDistances) do
                        local yDistance = -otherRequiredDistanceInfo.yDistance
                        --mj:log("otherRequiredDistanceInfo:", otherRequiredDistanceInfo, " yDistance:", yDistance)
                        
                        if (otherRequiredDistanceInfo.xDistance % 2) == 1 then
                            if i % 2 == 0 then
                                yDistance = yDistance + 0.5 --high chance this might be wrong
                            else
                                yDistance = yDistance - 0.5
                            end
                        else
                            yDistance = 0.0
                        end
                        --mj:log("after:", yDistance)

                        if yDistance > foundMaxY then
                            foundMaxY = yDistance
                            foundMaxKey = m
                        end
                    end
                    --mj:log("foundMaxKey:", foundMaxKey, " foundMaxY:", foundMaxY)
                    
                    for m,otherRequiredDistanceInfo in pairs(skillUIInfo.requiredSkillDistances) do
                        if otherRequiredDistanceInfo.xDistance % 2 == 1 then
                            if foundMaxKey == m then
                                otherRequiredDistanceInfo.dualRequiredYOffset = roleUICommon.dualDependencyOffset
                            else
                                otherRequiredDistanceInfo.dualRequiredYOffset = -roleUICommon.dualDependencyOffset
                            end
                        end
                    end
                end
            end
        end
    end
end

function roleUICommon:mjInit()
    roleUICommon.skillUIColumns = {
        {
            {
                --empty
            },
            {
                --empty
            },
            {
                skillTypeIndex = skill.types.gathering.index,
            },
            {
                skillTypeIndex = skill.types.basicBuilding.index,
            },
            {
                skillTypeIndex = skill.types.researching.index,
            },
            {
                skillTypeIndex = skill.types.diplomacy.index,
            },
            {
                skillTypeIndex = skill.types.handToHandCombat.index,
            },
        },{
            {
                skillTypeIndex = skill.types.fireLighting.index,
                requiredSkillTypes = {
                    skill.types.researching.index, --hack to show the lines is the only reason for this
                },
            },
            {
                --empty
            },
            {
                skillTypeIndex = skill.types.basicHunting.index,
                requiredSkillTypes = {
                    skill.types.researching.index, --hack to show the lines is the only reason for this
                },
            },
            {
                --empty
            },
            {
                skillTypeIndex = skill.types.rockKnapping.index,
                requiredSkillTypes = {
                    skill.types.researching.index, --hack to show the lines is the only reason for this
                },
            },
            {
                --empty
            },
            {
                skillTypeIndex = skill.types.thatchBuilding.index,
                requiredSkillTypes = {
                    skill.types.researching.index, --hack to show the lines is the only reason for this
                },
            },
            {
                --empty
            },
            {
                --empty
            },
        },{
            {
                --empty
            },
            {
                skillTypeIndex = skill.types.spinning.index,
            },
            {
                --empty
            },
            {
                skillTypeIndex = skill.types.butchery.index,
                requiredSkillTypes = {
                    skill.types.rockKnapping.index,
                },
            },
            {
                skillTypeIndex = skill.types.digging.index,
                requiredSkillTypes = {
                    skill.types.rockKnapping.index,
                },
            },
            {
                skillTypeIndex = skill.types.flintKnapping.index,
                requiredSkillTypes = {
                    skill.types.rockKnapping.index,
                },
            },
            {
                skillTypeIndex = skill.types.chiselStone.index,
                requiredSkillTypes = {
                    skill.types.rockKnapping.index,
                },
            },
            {
                skillTypeIndex = skill.types.treeFelling.index,
                requiredSkillTypes = {
                    skill.types.rockKnapping.index,
                },
            },
            {
                skillTypeIndex = skill.types.boneCarving.index,
                requiredSkillTypes = {
                    skill.types.rockKnapping.index,
                },
            },
        },{
            {
                skillTypeIndex = skill.types.campfireCooking.index,
                requiredSkillTypes = {
                    skill.types.fireLighting.index,
                },
            },
            {
                skillTypeIndex = skill.types.toolAssembly.index,
                requiredSkillTypes = {
                    skill.types.spinning.index,
                    skill.types.rockKnapping.index,
                },
            },
            {
                --empty
            },
            {
                skillTypeIndex = skill.types.planting.index,
                requiredSkillTypes = {
                    skill.types.digging.index,
                },
            },
            {
                skillTypeIndex = skill.types.pottery.index,
                requiredSkillTypes = {
                    skill.types.digging.index,
                },
            },
            {
                --empty
            },
            {
                skillTypeIndex = skill.types.tiling.index,
                requiredSkillTypes = {
                    skill.types.chiselStone.index,
                },
            },
            {
                skillTypeIndex = skill.types.woodWorking.index,
                requiredSkillTypes = {
                    skill.types.treeFelling.index,
                },
            },
            {
                --empty
            },
        },{
            {
                --empty
            },
            {
                skillTypeIndex = skill.types.spearHunting.index,
                requiredSkillTypes = {
                    skill.types.toolAssembly.index,
                },
            },
            {
                skillTypeIndex = skill.types.mining.index,
                requiredSkillTypes = {
                    skill.types.toolAssembly.index,
                },
            },
            {
                skillTypeIndex = skill.types.mulching.index,
                requiredSkillTypes = {
                    skill.types.planting.index,
                },
            },
            {
                skillTypeIndex = skill.types.medicine.index,
                requiredSkillTypes = {
                    skill.types.pottery.index,
                },
            },
            {
                skillTypeIndex = skill.types.threshing.index,
                requiredSkillTypes = {
                    skill.types.pottery.index,
                },
            },
            {
                skillTypeIndex = skill.types.mudBrickBuilding.index,
                requiredSkillTypes = {
                    skill.types.pottery.index,
                    skill.types.chiselStone.index,
                },
            },
            {
                skillTypeIndex = skill.types.woodBuilding.index,
                requiredSkillTypes = {
                    skill.types.woodWorking.index,
                },
            },
            {
                skillTypeIndex = skill.types.flutePlaying.index,
                requiredSkillTypes = {
                    skill.types.boneCarving.index,
                    skill.types.woodWorking.index,
                },
                onlyRequiresSingleSkillUnlocked = true,
            },
        },{
            {
                --empty
            },
            {
                --empty
            },
            {
                --empty
            },
            {
                skillTypeIndex = skill.types.grinding.index,
                requiredSkillTypes = {
                    skill.types.threshing.index,
                },
            },
            {
                --empty
            },
            {
                skillTypeIndex = skill.types.potteryFiring.index,
                requiredSkillTypes = {
                    skill.types.mudBrickBuilding.index,
                },
            },
            {
                skillTypeIndex = skill.types.blacksmithing.index,
                requiredSkillTypes = {
                    skill.types.mudBrickBuilding.index,
                },
            },
            {
                --empty
            },
            {
                --empty
            },
        },{
            {
                --empty
            },
            {
                --empty
            },
            {
                --empty
            },
            {
                skillTypeIndex = skill.types.baking.index,
                requiredSkillTypes = {
                    skill.types.grinding.index,
                },
            },
            {
                --empty
            },
            {
                --empty
            },
            {
                --empty
            },
            {
                --empty
            },
            {
                --empty
            },
        },{
            {
                --empty
            },
            {
                --empty
            },
            {
                --empty
            },
            {
                --empty
            },
            {
                --empty
            },
            {
                --empty
            },
            {
                --empty
            },
            {
                --empty
            },
            {
                --empty
            },
        },
    }

    roleUICommon:createDerivedTreeDependencies()

   --mj:log("roleUICommon.skillUIColumns:", roleUICommon.skillUIColumns)
end

function roleUICommon:constructBackgroundConnections(insetView)
    local xOffset = roleUICommon.plinthInitialXOffset
    for i,skillColumn in ipairs(roleUICommon.skillUIColumns) do
        local yOffset = roleUICommon.plinthInitialYOffset + 2
        if i % 2 == 0 then
            yOffset = yOffset - (roleUICommon.plinthSize.y) / 2 - roleUICommon.plinthPadding.y / 2
        end
        for j,skillUIInfo in ipairs(skillColumn) do

            if skillUIInfo.requiredSkillTypes then

                
                for k,requiredDistanceInfo in pairs(skillUIInfo.requiredSkillDistances) do
                    
                    local hz1 = ModelView.new(insetView)

                    local length = roleUICommon.plinthPadding.x * 0.5
                    local lengthOffset = 0

                    local requiredXDistance = requiredDistanceInfo.xDistance

                    local dualRequiredYOffset = requiredDistanceInfo.dualRequiredYOffset

                    if requiredXDistance >= 2 then
                        length = length + roleUICommon.plinthSize.x + roleUICommon.plinthPadding.x - 1
                        --lengthOffset = -(roleUICommon.plinthSize.x + roleUICommon.plinthPadding.x)
                    end
                    
                    local hz1XScale = length * 0.5
                    local hz1YScale = 10.0
                    local hz1XOffset = xOffset - hz1XScale * 2.0

                    hz1.masksEvents = false
                    hz1.baseOffset = vec3(hz1XOffset + lengthOffset, yOffset - roleUICommon.plinthSize.y * 0.5 + dualRequiredYOffset, 0.1)
                    hz1.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
                    hz1.scale3D = vec3(hz1XScale,hz1YScale,1)
                    hz1.size = vec2(hz1XScale,hz1YScale * 0.15) * 2.0

                    hz1:setModel(model:modelIndexForName("ui_horizontalConnector"), {
                        default = material.types.ui_disabled.index
                    })

                    if requiredXDistance > 2 then --construct some extra connectors, this will need more work in the future, hard coded for a narrow solution for now

                        --local yDistance = -1
                        
                        local maxYOffset = 0
                        local minYOffset = 0
                        local thisDistance = 0--yDistance * (roleUICommon.plinthSize.y + roleUICommon.plinthPadding.y)
                        
                        if (requiredXDistance % 2) == 1 then
                            if i % 2 == 0 then
                                thisDistance = thisDistance + (roleUICommon.plinthSize.y) / 2 + roleUICommon.plinthPadding.y / 2
                            else
                                thisDistance = thisDistance - (roleUICommon.plinthSize.y) / 2 - roleUICommon.plinthPadding.y / 2
                            end
                            

                            if thisDistance > maxYOffset then
                                maxYOffset = thisDistance
                            end
                            if thisDistance < minYOffset then
                                minYOffset = thisDistance
                            end
                        end

                        local top = yOffset - roleUICommon.plinthSize.y * 0.5 + maxYOffset - roleUICommon.dualDependencyOffset --this won't work for longer distances or more complexity
                        local bottom = yOffset - roleUICommon.plinthSize.y * 0.5 + minYOffset
                        
                    -- mj:log("skillUIInfo:", skillUIInfo, " maxYOffset:", maxYOffset, " minYOffset:", minYOffset, " top:", top, " bottom:", bottom)
                    -- mj:log("end top:", top, " bottom:", bottom)

                        local vLength = top - bottom + 2

                        local v1 = ModelView.new(insetView)
                        
                        local v1XScale = 10.0
                        local v1YScale = vLength / 2.0
                        local v1XOffset = xOffset - roleUICommon.plinthSize.x - roleUICommon.plinthPadding.x * 1.5
                        local v1YOffset = top-- - (top - bottom) * 0.5

                        v1.masksEvents = false
                        v1.baseOffset = vec3(v1XOffset, v1YOffset - 1, 0.1)
                        v1.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
                        v1.scale3D = vec3(v1XScale,v1YScale,1)
                        v1.size = vec2(v1XScale * 0.15,v1YScale) * 2.0

                        v1:setModel(model:modelIndexForName("ui_verticalConnector"), {
                            default = material.types.ui_disabled.index,
                        })


                        
                        local hz3 = ModelView.new(insetView)
                        local length3 = roleUICommon.plinthSize.x + roleUICommon.plinthPadding.x

                        local hz3XScale = length3 * 0.5
                        local hz3YScale = 10.0
                        local hz3XOffset = xOffset - hz3XScale * 2.0 - roleUICommon.plinthSize.x - roleUICommon.plinthPadding.x * 1.5

                        hz3.masksEvents = false
                        hz3.baseOffset = vec3(hz3XOffset, yOffset - roleUICommon.plinthSize.y * 0.5 + thisDistance, 0.1)
                        hz3.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
                        hz3.scale3D = vec3(hz3XScale,hz3YScale,1)
                        hz3.size = vec2(hz3XScale,hz3YScale * 0.15) * 2.0

                        hz3:setModel(model:modelIndexForName("ui_horizontalConnector"), {
                            default = material.types.ui_disabled.index
                        })

                    end
                end
            end
            
            if skillUIInfo.dependentSkillsByTypeIndex then
                local maxXDistance = 1

                for k,info in pairs(skillUIInfo.dependentSkillsByTypeIndex) do
                    if info.xDistance > maxXDistance then
                        maxXDistance = info.xDistance
                    end
                end

                local length = roleUICommon.plinthPadding.x * 0.5
                local hz2 = ModelView.new(insetView)
                
                local hz2XScale = length / 2.0
                local hz2YScale = 10.0
                local hz2XOffset = xOffset + roleUICommon.plinthSize.x

                hz2.masksEvents = false
                hz2.baseOffset = vec3(hz2XOffset, yOffset - roleUICommon.plinthSize.y * 0.5, 0.1)
               -- mj:log("hz2.baseOffset X:", hz2XOffset, " Y:", yOffset - roleUICommon.plinthSize.y * 0.5)
                hz2.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
                hz2.scale3D = vec3(hz2XScale,hz2YScale,1)
                hz2.size = vec2(hz2XScale,hz2YScale * 0.15) * 2.0

                hz2:setModel(model:modelIndexForName("ui_horizontalConnector"), {
                    default = material.types.ui_disabled.index,
                })

                local maxYOffset = 0
                local minYOffset = 0

                for k,info in pairs(skillUIInfo.dependentSkillsByTypeIndex) do
                    local thisDistance = info.yDistance * (roleUICommon.plinthSize.y + roleUICommon.plinthPadding.y)
                    
                    if (info.xDistance % 2) == 1 then
                        if i % 2 == 0 then
                            thisDistance = thisDistance + (roleUICommon.plinthSize.y) / 2 + roleUICommon.plinthPadding.y / 2
                        else
                            thisDistance = thisDistance - (roleUICommon.plinthSize.y) / 2 - roleUICommon.plinthPadding.y / 2
                        end
                    end

                    local dualRequiredYOffset = info.skillUIInfo.requiredSkillDistances[skillUIInfo.skillTypeIndex].dualRequiredYOffset
                    thisDistance = thisDistance + dualRequiredYOffset

                    if thisDistance > maxYOffset then
                        maxYOffset = thisDistance
                    end
                    if thisDistance < minYOffset then
                        minYOffset = thisDistance
                    end
                end

                if (maxXDistance % 2) == 1 then
                    if i % 2 == 0 then
                        maxYOffset = math.max(maxYOffset, 0)
                    else
                        minYOffset = math.min(minYOffset,  0)
                    end
                end

                if maxYOffset ~= minYOffset then
                    local top = yOffset - roleUICommon.plinthSize.y * 0.5 + maxYOffset
                    local bottom = yOffset - roleUICommon.plinthSize.y * 0.5 + minYOffset
                    
                   -- mj:log("skillUIInfo:", skillUIInfo, " maxYOffset:", maxYOffset, " minYOffset:", minYOffset, " top:", top, " bottom:", bottom)
                   -- mj:log("end top:", top, " bottom:", bottom)

                    local vLength = top - bottom + 2

                    local v1 = ModelView.new(insetView)
                    
                    local v1XScale = 10.0
                    local v1YScale = vLength / 2.0
                    local v1XOffset = xOffset + roleUICommon.plinthSize.x + roleUICommon.plinthPadding.x * 0.5
                    local v1YOffset = top-- - (top - bottom) * 0.5

                    v1.masksEvents = false
                    v1.baseOffset = vec3(v1XOffset, v1YOffset - 1, 0.1)
                    v1.relativePosition = ViewPosition(MJPositionInnerLeft, MJPositionTop)
                    v1.scale3D = vec3(v1XScale,v1YScale,1)
                    v1.size = vec2(v1XScale * 0.15,v1YScale) * 2.0

                    v1:setModel(model:modelIndexForName("ui_verticalConnector"), {
                        default = material.types.ui_disabled.index,
                    })
                end
            end
            
            yOffset = yOffset - roleUICommon.plinthSize.y - roleUICommon.plinthPadding.y
        end
        xOffset = xOffset + roleUICommon.plinthSize.x + roleUICommon.plinthPadding.x
    end
end

return roleUICommon
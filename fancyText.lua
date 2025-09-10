local FancyText = {};
FancyText.__index = FancyText;

FancyText.font = PIXEL_FONT_128;--love.graphics.newFont("SpaceMono.ttf", 128);
FancyText.fontHeight = FancyText.font:getHeight("|");
FancyText.spaceWidth = FancyText.font:getWidth(" ");

FancyText.DEFAULT_COLOURS = {
    ["red"] = {1,0,0};
    ["green"] = {0,1,0};
    ["blue"] = {0,0,1};
    ["cyan"] = {0,1,1};
    ["magenta"] = {1,0,1};
    ["yellow"] = {1,1,0};
    ["white"] = {1,1,1};
    ["black"] = {0,0,0};
    ["pink"] = {1,0,0.5};
    ["orange"] = {1,0.5,0};
    ["purple"] = {0.5,0,1};
    ["white_"] = {0.9,0.9,0.9};
    ["black_"] = {0.1,0.1,0.1};
    ["gray"] = {0.5,0.5,0.5};
    ["grey"] = {0.5,0.5,0.5};
    ["clear"] = {1,1,1,0};
    -- for easier usage. <highlight=off> / <highlight=none> looks more like its being disabled than <highlight=clear>
    ["none"] = {1,1,1,0};
    ["off"] = {1,1,1,0};
};

function FancyText.new(text, x, y, width, textHeight, alignment, dataReference)
    local instance = setmetatable({}, FancyText);

    instance.x = x;
    instance.y = y;

    instance.textHeight = textHeight or 20;

    instance.width = width;
    instance.alignment = alignment or "left";

    instance.text = text;
    instance.lines = nil; -- gets redefined in FancyText:alignText()

    instance.pointer = dataReference or {};

    instance:alignText();

    return instance;
end

function FancyText:setPosition(x, y)
    self.x = x;
    self.y = y;
end

function FancyText:setText(text)
    self.text = text;

    self:alignText();
end

function FancyText:setPointer(pointer)
    self.pointer = pointer;

    self:alignText();
end

function FancyText:update()
    self:alignText();
end

function FancyText:alignText()
    local realText = self.text;
    realText = string.gsub(realText, "%b<>",
        function(strToReplace)
            -- check if it is changing a graphical component
            if string.find(strToReplace, "=") then
                return nil; -- dont alter the string (yet)
            else -- otherwise its a key to the pointer table
                return tostring(self.pointer[string.sub(strToReplace,2,-2)]);
            end
        end
    );

    local specialCharacter = nil;
    -- find a character that is not being used in the text. this will be used to mark when modifiers are changed
    for i = 0, 255 do
        local specialChar = string.char(i);

        -- look to see if character is absent from text (if so then it is usable as a marking character)
        if not string.find(realText, specialChar, 1, true) then
            specialCharacter = specialChar;

            break;
        end
    end

    assert(specialCharacter ~= nil, "fancyText was unable to find a special character to use in a given string (this means that every possible byte value of a character is present in the text wanted to be displayed)");

    local graphicalChanges = {};

    realText = string.gsub(realText, "%b<>",
        function(strToReplace)
            table.insert(graphicalChanges, string.sub(strToReplace,2,-2));

            return specialCharacter;
        end
    );

    local lineWidth = 0;
    local scale = self.textHeight / self.fontHeight;

    self.lines = {}; -- empty the table

    local curLine = "";
    local curAddLine = {};

    while string.len(realText) > 0 do
        local tillNextSpace, rest = string.match(realText, "^([^ \n]*[ \n])(.*)$");

        if not tillNextSpace then
            tillNextSpace = realText;
            realText = "";
        else
            realText = rest or "";
        end

        local tempAddLine = {};

        while string.find(tillNextSpace, specialCharacter, 1, true) do
            local ind = string.find(tillNextSpace, specialCharacter, 1, true);
            tillNextSpace = string.sub(tillNextSpace, 0, ind - 1) .. string.sub(tillNextSpace, ind + 1,-1);

            local modif = table.remove(graphicalChanges, 1);

            table.insert(tempAddLine, {charStart = ind, modificationName = string.match(modif, "^[^=]*"), setTo = string.match(modif, "[^=]*$")});
        end

        local widthOfStr = self.font:getWidth(string.match(tillNextSpace, "^[^ \n]*")) * scale; -- remove space for measurement

        if lineWidth + widthOfStr > self.width then
            curAddLine.text = (string.match(curLine, "^(.*)[ \n]$")) or curLine;
            table.insert(self.lines, curAddLine);
            curAddLine = {};

            for i, v in ipairs(tempAddLine) do
                table.insert(curAddLine, v);
            end

            curLine = tillNextSpace;
            lineWidth = widthOfStr + self.spaceWidth * scale;
        else
            for i, v in ipairs(tempAddLine) do
                v.charStart = v.charStart + string.len(curLine);
                table.insert(curAddLine, v);
            end

            curLine = curLine .. tillNextSpace;
            lineWidth = lineWidth + widthOfStr + self.spaceWidth * scale;
        end

        -- check if line ended with a line break
        if string.find(tillNextSpace, "\n") then
            curAddLine.text = (string.match(curLine, "^(.*)[ \n]$")) or curLine;
            table.insert(self.lines, curAddLine);
            curAddLine = {};

            curLine = "";
            lineWidth = 0;
        end
    end

    curAddLine.text = (string.match(curLine, "^(.*)[ \n]$")) or curLine;
    table.insert(self.lines, curAddLine);
end

function FancyText:getHeight()
    return #self.lines * self.textHeight;
end

function FancyText:getWidth()
    local scale = self.textHeight / self.fontHeight;

    local longest = self.font:getWidth(self.lines[1].text);

    for i = 2, #self.lines do
        longest = math.max(self.font:getWidth(self.lines[i].text), longest);
    end

    return longest * scale;
end

function FancyText:draw()
    local colour = self.DEFAULT_COLOURS.black;
    local highlight = self.DEFAULT_COLOURS.clear;

    local scale = self.textHeight / self.fontHeight;

    love.graphics.push();
    love.graphics.translate(self.x, self.y);
    love.graphics.setFont(self.font);

    -- has some bad coding practices but is very hard to fix without creating unecessary public functions
    -- or extremely inefficient local functions that are created and destroyed every draw call
    for i, v in ipairs(self.lines) do
        local lineWidth = self.font:getWidth(v.text) * scale;

        local x;

        if self.alignment == "left" then
            x = 0;
        elseif self.alignment == "middle" or self.alignment == "center" then
            x = (self.width - lineWidth) / 2;
        elseif self.alignment == "right" then
            x = self.width - lineWidth;
        else
            x = 0;
        end

        if #v > 0 then
            local alreadyDrawn = 1;

            for j, w in ipairs(v) do
                local toDraw = string.sub(v.text, alreadyDrawn, w.charStart - 1);
                alreadyDrawn = w.charStart;

                if highlight[4] ~= 0 then -- if alpha of the colour is not 0 then draw the highlight
                    love.graphics.setColor(highlight);
                    love.graphics.rectangle("fill", x - 2, (i - 1) * self.fontHeight * scale, self.font:getWidth(toDraw) * scale + 4, self.fontHeight * scale, 3,3);
                end

                love.graphics.setColor(colour);
                love.graphics.print(toDraw, x, (i - 1) * self.fontHeight * scale, 0, scale,scale);

                x = x + self.font:getWidth(toDraw) * scale;

                if w.modificationName == "colour" or w.modificationName == "color" then
                    colour = self.DEFAULT_COLOURS[w.setTo];
                elseif w.modificationName == "highlight" then
                    highlight = self.DEFAULT_COLOURS[w.setTo];
                end
            end

            local toDraw = string.sub(v.text, alreadyDrawn, -1);

            if highlight[4] ~= 0 then -- if alpha of the colour is not 0 then draw the highlight
                love.graphics.setColor(highlight);
                love.graphics.rectangle("fill", x - 2, (i - 1) * self.fontHeight * scale, self.font:getWidth(toDraw) * scale + 4, self.fontHeight * scale, 3,3);
            end

            love.graphics.setColor(colour);
            love.graphics.print(toDraw, x, (i - 1) * self.fontHeight * scale, 0, scale,scale);
        else
            if highlight[4] ~= 0 then -- if alpha of the colour is not 0 then draw the highlight
                love.graphics.setColor(highlight);
                love.graphics.rectangle("fill", x - 2, (i - 1) * self.fontHeight * scale + 4, lineWidth, self.fontHeight * scale, 3,3);
            end

            love.graphics.setColor(colour);
            love.graphics.print(v.text, x, (i - 1) * self.fontHeight * scale, 0, scale,scale);
        end
    end

    love.graphics.pop();
end

return FancyText;

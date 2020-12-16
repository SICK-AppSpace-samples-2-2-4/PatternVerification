--[[----------------------------------------------------------------------------

  Application Name:
  PatternVerification

  Summary:
  Verifying correctness of key pattern on a keyboard.

  How to Run:
  Starting this sample is possible either by running the app (F5) or
  debugging (F7+F10). Setting breakpoint on the first row inside the 'main'
  function allows debugging step-by-step after 'Engine.OnStarted' event.
  Results can be seen in the image viewer on the DevicePage.
  Restarting the Sample may be necessary to show images after loading the webpage.
  To run this Sample a device with SICK Algorithm API and AppEngine >= V2.5.0 is
  required. For example SIM4000 with latest firmware. Alternatively the Emulator
  in AppStudio 2.3 or higher can be used.

  More Information:
  Tutorial "Algorithms - Matching".

------------------------------------------------------------------------------]]

--Start of Global Scope---------------------------------------------------------

print('AppEngine Version: ' .. Engine.getVersion())

local DELAY = 1000 -- ms between visualization steps for demonstration purpose

-- Variable for holding table of verifiers
local verifiers = {}

-- Creating viewer
local viewer = View.create()

-- Setting up graphical overlay attributes
local teachDecoration = View.ShapeDecoration.create()
teachDecoration:setLineColor(0, 0, 230) -- Blue for "teach"
teachDecoration:setLineWidth(4)

local failDecoration = View.ShapeDecoration.create()
failDecoration:setLineColor(230, 0, 0) -- Red for "fail"
failDecoration:setLineWidth(4)

local passDecoration = View.ShapeDecoration.create()
passDecoration:setLineColor(0, 230, 0) -- Green for "pass"
passDecoration:setLineWidth(4)

local textDecoration = View.TextDecoration.create()
textDecoration:setPosition(25, 45)
textDecoration:setSize(35)
textDecoration:setColor(255, 255, 0)

-- Create a PatternMatcher instance and set parameters
-- Note that a PointMatcher possibly can be used as well here
local matcher = Image.Matching.PatternMatcher.create()
matcher:setRotationRange(3.1415 / 4)
matcher:setMaxMatches(5)
matcher:setDownsampleFactor(10)
matcher:setTimeout(60)

-- Creating fixture
local fixture = Image.Fixture.create()

-- Defining threshold for pass
local errorScoreThreshold = 0.85

--End of Global Scope-----------------------------------------------------------

--Start of Function and Event Scope---------------------------------------------

--@teachShape(img:Image, imageID:string):Transform
local function teachShape(img, imageID)
  -- Defining object teach region
  local center = Point.create(280, 180)
  local teachRectangle = Shape.createRectangle(center, 170, 200)
  local teachRegion = teachRectangle:toPixelRegion(img)
  viewer:addShape(teachRectangle, teachDecoration, nil, imageID)

  -- Teaching
  local matcherTeachPose = matcher:teach(img, teachRegion)
  fixture:setReferencePose(matcherTeachPose)
  fixture:appendShape('objectBox', teachRectangle)
  return matcherTeachPose
end

-- Routine for adding and teaching one verifier
--@addVerifier(verifiers:table, fixture:Image.Fixture, teachImage:Image,
--             keyName:string, keyRegion:Image.PixelRegion)
local function addVerifier(teachImage, keyName, keyRegion)
  verifiers[keyName] = Image.Matching.PatternVerifier.create()
  verifiers[keyName]:setPositionTolerance(3)
  verifiers[keyName]:setRotationTolerance(math.rad(1))
  local keyPose = verifiers[keyName]:teach(teachImage, keyRegion)
  fixture:appendPose(keyName, keyPose)
  fixture:appendShape(keyName, keyRegion:getBoundingBoxOriented(teachImage))
end

--@teachPatterns(teachPose:Transform, img:Image, imageID:string)
local function teachPatterns(teachPose, img, imageID)
  -- Key regions
  local printScreen = Image.PixelRegion.createRectangle(220, 103, 249, 137)
  local scrollLock = Image.PixelRegion.createRectangle(265, 103, 294, 139)
  local pause = Image.PixelRegion.createRectangle(309, 103, 338, 140)
  local insert = Image.PixelRegion.createRectangle(218, 166, 249, 201)
  local home = Image.PixelRegion.createRectangle(263, 166, 294, 201)
  local pageUp = Image.PixelRegion.createRectangle(308, 166, 337, 202)
  local delete = Image.PixelRegion.createRectangle(219, 212, 249, 246)
  local endButton = Image.PixelRegion.createRectangle(264, 213, 293, 248)
  local pageDown = Image.PixelRegion.createRectangle(308, 212, 336, 246)

  -- Teaching verifiers for keys
  addVerifier(img, 'PrintScreen', printScreen)
  addVerifier(img, 'ScrollLock', scrollLock)
  addVerifier(img, 'Pause', pause)
  addVerifier(img, 'Insert', insert)
  addVerifier(img, 'Home', home)
  addVerifier(img, 'PageUp', pageUp)
  addVerifier(img, 'Delete', delete)
  addVerifier(img, 'End', endButton)
  addVerifier(img, 'PageDown', pageDown)
  -- Draw teach regions
  fixture:transform(teachPose)
  for keyName, _ in pairs(verifiers) do
    local bbox = fixture:getShape(keyName)
    viewer:addShape(bbox, teachDecoration, nil, imageID)
  end

  viewer:addText('Teach', textDecoration, nil, imageID)

  viewer:present()
end

--@match(img:Image)
local function match(img)
  viewer:clear()
  local imageID = viewer:addImage(img)
  -- Finding object
  local poses,
    scores = matcher:match(img)
  local livePose = poses[1]
  local liveScore = scores[1]
  print('Object score: ' .. math.floor(liveScore * 100) / 100)

  -- Drawing object rectangle
  fixture:transform(livePose)
  local objectRectangle = fixture:getShape('objectBox')
  viewer:addShape(objectRectangle, passDecoration, nil, imageID)

  -- Verifying each key, draw box with color depending on verifier score
  local textContent = 'Pass'
  for keyName, verifier in pairs(verifiers) do
    local score, _, _ = verifier:verify(img, fixture:getPose(keyName))
    local bbox = fixture:getShape(keyName)
    if (score > errorScoreThreshold) then
      viewer:addShape(bbox, passDecoration, nil, imageID)
    else
      viewer:addShape(bbox, failDecoration, nil, imageID)
      textContent = 'Fail'
    end
    print(keyName .. ' score: ' .. tostring(math.floor(score * 100) / 100))
  end

  viewer:addText(textContent, textDecoration, nil, imageID)
  viewer:present()
end

local function main()
  -- Loading Teach image from resources and teaching
  local teachImage = Image.load('resources/Teach.bmp')
  viewer:clear()
  local imageID = viewer:addImage(teachImage)
  local matcherTeachPose = teachShape(teachImage, imageID)
  -- Teaching patterns to verify
  teachPatterns(matcherTeachPose, teachImage, imageID)
  Script.sleep(DELAY * 1.5)

  -- Loading images from resource folder and calling function for verification
  for i = 1, 3 do
    local liveImage = Image.load('resources/' .. i .. '.bmp')
    print('-------------------------')
    print('OBJECT ' .. i)
    match(liveImage)
    Script.sleep(DELAY)
  end

  print('App finished.')
end
--The following registration is part of the global scope which runs once after startup
--Registration of the 'main' function to the 'Engine.OnStarted' event
Script.register('Engine.OnStarted', main)

--End of Function and Event Scope--------------------------------------------------

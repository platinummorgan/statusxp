
OpenXBL
Integrate Xbox services easily.
We provide you all the tools you need to get started.
Account
API reference for retrieving account information and seeing all possible account types and subtypes
Endpoints
/account
Get account information
/account/{xuids}
Get account information for specified users
/search/{gamertag}
Find other players by gamertag
/alerts
Get user notifications
/generate/gamertag
Generate random gamertags
GET /account
Get account information
The account endpoint makes a request to the profile service for gamer pic, gamerscore, gamertag, account tier, Xbox One rep, preferred color, real name, bio, and location.
Response fields and example.
•	profileUsers
object
Accounts object.
Hide object
id
string
The Xbox User ID (XUID) is a unique identifier for the user.
hostId
string
This value is the same as the Xbox User ID (XUID).
settings
object
Array of key-value pairs for requested information.
Hide object
id
string
The key identifier for the supplied value.
value
string
The value for the specified key identifier.
isSponsoredUser
boolean
Guest Users, also known as Sponsored Guests or Guest Accounts, allow players to interact with many Xbox Live services without needing to create a full Xbox Live account.
API Object
Object
profileUsers:Array[1]
0:Object
id:"2533274798129181"
hostId:"2533274798129181"
settings:Array[9]
0:Object
id:"GameDisplayPicRaw"
value:"https://images-eds-ssl.xboxlive.com/image?url=wHwbXKif8cus8csoZ03RW_ES.ojiJijNBGRVUbTnZKsoCCCkjlsEJrrMqDkYqs3MBhMLdvWFHLCswKMlApTSbzvES1cjEAVPrczatfOc0jR0Ss4zHEy6ErElLAY8rAVFRNqPmGHxiumHSE9tZRnlghsACzaoisWEww1VSUd9Sx0-&format=png"
1:Object
id:"Gamerscore"
value:"19165"
2:Object
id:"Gamertag"
value:"xTACTICSx"
3:Object
id:"AccountTier"
value:"Gold"
4:Object
id:"XboxOneRep"
value:"GoodPlayer"
5:Object
id:"PreferredColor"
value:"http://dlassets.xboxlive.com/public/content/ppl/colors/00003.json"
6:Object
id:"RealName"
value:"David Regimbal"
7:Object
id:"Bio"
value:"Changing the world one semicolon at a time"
8:Object
id:"Location"
value:"United States"
isSponsoredUser:false
GET /account/{xuids}
Get account information for specified users
The account endpoint makes a request to the people hub service for gamer pic, gamerscore, gamertag, account tier, Xbox One rep, preferred color, real name, bio, and location.
Response fields and example.
•	people
object
People object.
Hide object
xuid
string
The Xbox User ID (XUID) is a unique identifier for the user.
isFavorite
boolean
Determines if this user is a favorite of the request caller.
isFollowingCaller
boolean
Determines if this user is following the request caller.
isFollowedByCaller
boolean
Determines if this user is followed by the request caller.
isIdentityShared
boolean
Determines if this user has shared their identity.
addedDateTimeUtc
timestamp
Gets the timestamp, if set, of when the user was added.
displayName
string
The custom display name set by the user.
realName
string
Provides the real name for the owner of the account.
displayPicRaw
string
Provides the gamer pic URL.
showUserAsAvatar
string
Identifier to determine if this user elected to show as their Avatar.
gamertag
string
The unique gamertag set for this user and compatible with Xbox 360.
gamerscore
string
The total gamer score earned by this user.
modernGamertag
string
The gamertag set for this user using the new Xbox One configuration.
modernGamertagSuffix
string
The gamertag suffix set for this user using the new Xbox One configuration.
uniqueModernGamertag
string
The combined modern gamertag and suffix which represents the unique gamertag for the user.
xboxOneRep
string
Returns the Xbox One reputation score for this user.
presenceState
string
Provides the current state of the user; i.e. 'Online'
presenceText
string
Provides the current activity of the user; i.e. 'Playing Halo Infinite'
presenceDevices
null
Returns the list of devices the user is on.
isBroadcasting
boolean
Determines if the user is streaming live.
isCloaked
boolean
isQuarantined
boolean
isXbox360Gamerpic
boolean
lastSeenDateTimeUtc
timestamp
Provides the datetime of when the user was last seen.
suggestion
null
recommendation
null
search
null
titleHistory
null
multiplayerSummary
null
recentPlayer
null
follower
null
preferredColor
object
Returns the primary, secondary and tertiary color set by the user.
Hide object
primaryColor
string
secondaryColor
string
tertiaryColor
string
presenceDetails
null
titlePresence
null
titleSummaries
null
presenceTitleIds
null
detail
null
communityManagerTitles
null
socialManager
null
broadcast
null
avatar
null
linkedAccounts
array
colorTheme
string
preferredFlag
string
preferredPlatforms
array
recommendationSummary
null
friendFinderState
null
accountLinkDetails
null
API Object
Object
people:Array[1]
0:Object
xuid:"2533274798129181"
isFavorite:false
isFollowingCaller:false
isFollowedByCaller:false
isIdentityShared:false
addedDateTimeUtc:null
displayName:"xTACTICSx"
realName:""
displayPicRaw:"https://images-eds-ssl.xboxlive.com/image?url=wHwbXKif8cus8csoZ03RW_ES.ojiJijNBGRVUbTnZKsoCCCkjlsEJrrMqDkYqs3MBhMLdvWFHLCswKMlApTSbzvES1cjEAVPrczatfOc0jR0Ss4zHEy6ErElLAY8rAVFRNqPmGHxiumHSE9tZRnlghsACzaoisWEww1VSUd9Sx0-&format=png"
showUserAsAvatar:"1"
gamertag:"xTACTICSx"
gamerScore:"19165"
modernGamertag:"xTACTICSx"
modernGamertagSuffix:""
uniqueModernGamertag:"xTACTICSx"
xboxOneRep:"GoodPlayer"
presenceState:"Online"
presenceText:"Online"
presenceDevices:null
isBroadcasting:false
isCloaked:true
isQuarantined:false
isXbox360Gamerpic:false
lastSeenDateTimeUtc:null
suggestion:null
recommendation:null
search:null
titleHistory:null
multiplayerSummary:null
recentPlayer:null
follower:null
preferredColor:Object
primaryColor:"193e91"
secondaryColor:"101836"
tertiaryColor:"102c69"
presenceDetails:null
titlePresence:null
titleSummaries:null
presenceTitleIds:null
detail:null
communityManagerTitles:null
socialManager:null
broadcast:null
avatar:null
linkedAccounts:Array[0]
colorTheme:"gamerpicblur"
preferredFlag:""
preferredPlatforms:Array[0]
recommendationSummary:null
friendFinderState:null
accountLinkDetails:null
GET /search/{gamertag}
Find other players by gamertag
This endpoint uses the people hub service to return 15 results for user detail, preferred color via gamertag.
Response fields and example.
•	people
object
People object.
Hide object
xuid
string
The Xbox User ID (XUID) is a unique identifier for the user.
isFavorite
boolean
Determines if this user is a favorite of the request caller.
isFollowingCaller
boolean
Determines if this user is following the request caller.
isFollowedByCaller
boolean
Determines if this user is followed by the request caller.
isIdentityShared
boolean
Determines if this user has shared their identity.
addedDateTimeUtc
timestamp
Gets the timestamp, if set, of when the user was added.
displayName
string
The custom display name set by the user.
realName
string
Provides the real name for the owner of the account.
displayPicRaw
string
Provides the gamer pic URL.
showUserAsAvatar
boolean
Identifier to determine if this user elected to show as their Avatar.
gamertag
string
The unique gamertag set for this user and compatible with Xbox 360.
gamerScore
timestamp
The total gamer score earned by this user.
modernGamertag
timestamp
The gamertag set for this user using the new Xbox One configuration.
modernGamertagSuffix
timestamp
The gamertag suffix set for this user using the new Xbox One configuration.
uniqueModernGamertag
timestamp
The combined modern gamertag and suffix which represents the unique gamertag for the user.
xboxOneRep
string
Returns the Xbox One reputation score for this user.
presenceState
string
Provides the current state of the user; i.e. 'Online'
presenceText
string
Provides the current activity of the user; i.e. 'Playing Halo Infinite'
presenceDevices
null
Returns the list of devices the user is on.
isBroadcasting
boolean
Determines if the user is streaming live.
isCloaked
boolean
isQuarantined
boolean
isXbox360Gamerpic
boolean
lastSeenDateTimeUtc
timestamp
Provides the datetime of when the user was last seen.
suggestion
null
recommendation
null
search
object
Hide object
type
string
reasons
array
titleHistory
null
multiplayerSummary
null
recentPlayer
null
follower
null
preferredColor
object
Returns the primary, secondary and tertiary color set by the user.
Hide object
primaryColor
string
secondaryColor
string
tertiaryColor
string
presenceDetails
null
titlePresence
null
titleSummaries
null
presenceTitleIds
null
detail
object
Hide object
accountTier
string
bio
string
isVerified
boolean
location
string
tenure
string
watermarks
array
blocked
boolean
mute
false
followerCount
integer
followingCount
integer
hasGamePass
boolean
Determines if this user has an active Game Pass subscription.
communityManagerTitles
null
socialManager
null
broadcast
null
avatar
string
linkedAccounts
object
colorTheme
string
preferredFlag
string
preferredPlatforms
object
recommendationSummary
null
friendFinderState
null
accountLinkDetails
null
API Object
Object
people:Array[1]
0:Object
xuid:"2533274798129181"
isFavorite:false
isFollowingCaller:false
isFollowedByCaller:false
isIdentityShared:false
addedDateTimeUtc:null
displayName:null
realName:""
displayPicRaw:"https://images-eds-ssl.xboxlive.com/image?url=wHwbXKif8cus8csoZ03RW_ES.ojiJijNBGRVUbTnZKsoCCCkjlsEJrrMqDkYqs3MBhMLdvWFHLCswKMlApTSbzvES1cjEAVPrczatfOc0jR0Ss4zHEy6ErElLAY8rAVFRNqPmGHxiumHSE9tZRnlghsACzaoisWEww1VSUd9Sx0-&format=png"
showUserAsAvatar:"1"
gamertag:"xTACTICSx"
gamerScore:"19165"
modernGamertag:"xTACTICSx"
modernGamertagSuffix:""
uniqueModernGamertag:"xTACTICSx"
xboxOneRep:"GoodPlayer"
presenceState:null
presenceText:null
presenceDevices:null
isBroadcasting:false
isCloaked:null
isQuarantined:false
isXbox360Gamerpic:false
lastSeenDateTimeUtc:null
suggestion:null
recommendation:null
search:Object
Type:"None"
Reasons:Array[0]
titleHistory:null
multiplayerSummary:null
recentPlayer:null
follower:null
preferredColor:Object
primaryColor:"193e91"
secondaryColor:"101836"
tertiaryColor:"102c69"
presenceDetails:null
titlePresence:null
titleSummaries:null
presenceTitleIds:null
detail:Object
accountTier:"Gold"
bio:null
isVerified:false
location:null
tenure:null
watermarks:Array[0]
blocked:false
mute:false
followerCount:40
followingCount:34
hasGamePass:false
communityManagerTitles:null
socialManager:null
broadcast:null
avatar:null
linkedAccounts:null
colorTheme:"gamerpicblur"
preferredFlag:""
preferredPlatforms:Array[0]
recommendationSummary:null
friendFinderState:null
accountLinkDetails:null
GET /alerts
Get user notifications
This endpoint uses the comments service to return alerts.
Response fields and example.
•	alerts
objects
Hide object
id
string
action
string
path
string
actorXuid
string
actorGamertag
string
parentType
string
parentPath
string
ownerXuid
string
ownerGamertag
string
timestamp
timestamp
seen
boolean
rootPath
string
clubId
string
API Object
Object
alerts:Array[1]
0:Object
id:"08587232084657218732_430928276_2533274795899722"
action:"Like"
path:"comments.xboxlive.com/screenshotsmetadata.xboxlive.com/users/xuid(2533274798129181)/scids/72010100-7d7f-4105-b34e-3ec552a4c121/screenshots/47cb19df-2283-44fb-ae18-4fe277ff205d/likes/xuid(2533274795899722)"
actorXuid:"2533274795899722"
actorGamertag:"GATORLAlD"
parentType:"Screenshot"
parentPath:"screenshotsmetadata.xboxlive.com/users/xuid(2533274798129181)/scids/72010100-7d7f-4105-b34e-3ec552a4c121/screenshots/47cb19df-2283-44fb-ae18-4fe277ff205d"
ownerXuid:"2533274798129181"
ownerGamertag:"xTACTICSx"
timestamp:"2016-11-06T02:13:39.7557075Z"
seen:true
rootPath:"screenshotsmetadata.xboxlive.com/users/xuid(2533274798129181)/scids/72010100-7d7f-4105-b34e-3ec552a4c121/screenshots/47cb19df-2283-44fb-ae18-4fe277ff205d"
clubId:"0"
POST /generate/gamertag
Generate random gamertags
This endpoint uses the user management service to generate random gamertags that are available.
Request fields and example.
•	algorithm
integer
count
integer
seed
string
locale
string
API Object
Object
algorithm:1
count:3
seed:""
locale:"en-US"
Response fields and example.
•	gamertags
array
API Object
Object
Gamertags:Array[3]
0:"ShadowYard22009"
1:"BackCookie22017"
2:"GivenBell320978"
Suggest a change on GitHub.
•	Learn
o	About OpenXBL
o	Getting Started
o	API Console
o	Docs
•	Contribute
o	GitHub
o	Join us on Discord
o	Submit an Issue
o	Provide Feedback
OpenXBL is an unofficial Xbox Live API designed around developer friendly documentation. The best part, it's free!
    
Copyright © 2026 OpenXBL v3.1.0
We are in no way endorsed or affiliated with Microsoft Corporation, Xbox, Xbox LIVE or any Microsoft subsidiary. Images are registered trademarks of their respected owners.
By visiting our website you agree to our terms and conditions. | View operational status






OpenXBL
Integrate Xbox services easily.
We provide you all the tools you need to get started.
Account
API reference for retrieving account information and seeing all possible account types and subtypes
Endpoints
/account
Get account information
/account/{xuids}
Get account information for specified users
/search/{gamertag}
Find other players by gamertag
/alerts
Get user notifications
/generate/gamertag
Generate random gamertags
GET /account
Get account information
The account endpoint makes a request to the profile service for gamer pic, gamerscore, gamertag, account tier, Xbox One rep, preferred color, real name, bio, and location.
Response fields and example.
•	profileUsers
object
Accounts object.
Hide object
id
string
The Xbox User ID (XUID) is a unique identifier for the user.
hostId
string
This value is the same as the Xbox User ID (XUID).
settings
object
Array of key-value pairs for requested information.
Hide object
id
string
The key identifier for the supplied value.
value
string
The value for the specified key identifier.
isSponsoredUser
boolean
Guest Users, also known as Sponsored Guests or Guest Accounts, allow players to interact with many Xbox Live services without needing to create a full Xbox Live account.
API Object
Object
profileUsers:Array[1]
0:Object
id:"2533274798129181"
hostId:"2533274798129181"
settings:Array[9]
0:Object
id:"GameDisplayPicRaw"
value:"https://images-eds-ssl.xboxlive.com/image?url=wHwbXKif8cus8csoZ03RW_ES.ojiJijNBGRVUbTnZKsoCCCkjlsEJrrMqDkYqs3MBhMLdvWFHLCswKMlApTSbzvES1cjEAVPrczatfOc0jR0Ss4zHEy6ErElLAY8rAVFRNqPmGHxiumHSE9tZRnlghsACzaoisWEww1VSUd9Sx0-&format=png"
1:Object
id:"Gamerscore"
value:"19165"
2:Object
id:"Gamertag"
value:"xTACTICSx"
3:Object
id:"AccountTier"
value:"Gold"
4:Object
id:"XboxOneRep"
value:"GoodPlayer"
5:Object
id:"PreferredColor"
value:"http://dlassets.xboxlive.com/public/content/ppl/colors/00003.json"
6:Object
id:"RealName"
value:"David Regimbal"
7:Object
id:"Bio"
value:"Changing the world one semicolon at a time"
8:Object
id:"Location"
value:"United States"
isSponsoredUser:false
GET /account/{xuids}
Get account information for specified users
The account endpoint makes a request to the people hub service for gamer pic, gamerscore, gamertag, account tier, Xbox One rep, preferred color, real name, bio, and location.
Response fields and example.
•	people
object
People object.
Hide object
xuid
string
The Xbox User ID (XUID) is a unique identifier for the user.
isFavorite
boolean
Determines if this user is a favorite of the request caller.
isFollowingCaller
boolean
Determines if this user is following the request caller.
isFollowedByCaller
boolean
Determines if this user is followed by the request caller.
isIdentityShared
boolean
Determines if this user has shared their identity.
addedDateTimeUtc
timestamp
Gets the timestamp, if set, of when the user was added.
displayName
string
The custom display name set by the user.
realName
string
Provides the real name for the owner of the account.
displayPicRaw
string
Provides the gamer pic URL.
showUserAsAvatar
string
Identifier to determine if this user elected to show as their Avatar.
gamertag
string
The unique gamertag set for this user and compatible with Xbox 360.
gamerscore
string
The total gamer score earned by this user.
modernGamertag
string
The gamertag set for this user using the new Xbox One configuration.
modernGamertagSuffix
string
The gamertag suffix set for this user using the new Xbox One configuration.
uniqueModernGamertag
string
The combined modern gamertag and suffix which represents the unique gamertag for the user.
xboxOneRep
string
Returns the Xbox One reputation score for this user.
presenceState
string
Provides the current state of the user; i.e. 'Online'
presenceText
string
Provides the current activity of the user; i.e. 'Playing Halo Infinite'
presenceDevices
null
Returns the list of devices the user is on.
isBroadcasting
boolean
Determines if the user is streaming live.
isCloaked
boolean
isQuarantined
boolean
isXbox360Gamerpic
boolean
lastSeenDateTimeUtc
timestamp
Provides the datetime of when the user was last seen.
suggestion
null
recommendation
null
search
null
titleHistory
null
multiplayerSummary
null
recentPlayer
null
follower
null
preferredColor
object
Returns the primary, secondary and tertiary color set by the user.
Hide object
primaryColor
string
secondaryColor
string
tertiaryColor
string
presenceDetails
null
titlePresence
null
titleSummaries
null
presenceTitleIds
null
detail
null
communityManagerTitles
null
socialManager
null
broadcast
null
avatar
null
linkedAccounts
array
colorTheme
string
preferredFlag
string
preferredPlatforms
array
recommendationSummary
null
friendFinderState
null
accountLinkDetails
null
API Object
Object
people:Array[1]
0:Object
xuid:"2533274798129181"
isFavorite:false
isFollowingCaller:false
isFollowedByCaller:false
isIdentityShared:false
addedDateTimeUtc:null
displayName:"xTACTICSx"
realName:""
displayPicRaw:"https://images-eds-ssl.xboxlive.com/image?url=wHwbXKif8cus8csoZ03RW_ES.ojiJijNBGRVUbTnZKsoCCCkjlsEJrrMqDkYqs3MBhMLdvWFHLCswKMlApTSbzvES1cjEAVPrczatfOc0jR0Ss4zHEy6ErElLAY8rAVFRNqPmGHxiumHSE9tZRnlghsACzaoisWEww1VSUd9Sx0-&format=png"
showUserAsAvatar:"1"
gamertag:"xTACTICSx"
gamerScore:"19165"
modernGamertag:"xTACTICSx"
modernGamertagSuffix:""
uniqueModernGamertag:"xTACTICSx"
xboxOneRep:"GoodPlayer"
presenceState:"Online"
presenceText:"Online"
presenceDevices:null
isBroadcasting:false
isCloaked:true
isQuarantined:false
isXbox360Gamerpic:false
lastSeenDateTimeUtc:null
suggestion:null
recommendation:null
search:null
titleHistory:null
multiplayerSummary:null
recentPlayer:null
follower:null
preferredColor:Object
primaryColor:"193e91"
secondaryColor:"101836"
tertiaryColor:"102c69"
presenceDetails:null
titlePresence:null
titleSummaries:null
presenceTitleIds:null
detail:null
communityManagerTitles:null
socialManager:null
broadcast:null
avatar:null
linkedAccounts:Array[0]
colorTheme:"gamerpicblur"
preferredFlag:""
preferredPlatforms:Array[0]
recommendationSummary:null
friendFinderState:null
accountLinkDetails:null
GET /search/{gamertag}
Find other players by gamertag
This endpoint uses the people hub service to return 15 results for user detail, preferred color via gamertag.
Response fields and example.
•	people
object
People object.
Hide object
xuid
string
The Xbox User ID (XUID) is a unique identifier for the user.
isFavorite
boolean
Determines if this user is a favorite of the request caller.
isFollowingCaller
boolean
Determines if this user is following the request caller.
isFollowedByCaller
boolean
Determines if this user is followed by the request caller.
isIdentityShared
boolean
Determines if this user has shared their identity.
addedDateTimeUtc
timestamp
Gets the timestamp, if set, of when the user was added.
displayName
string
The custom display name set by the user.
realName
string
Provides the real name for the owner of the account.
displayPicRaw
string
Provides the gamer pic URL.
showUserAsAvatar
boolean
Identifier to determine if this user elected to show as their Avatar.
gamertag
string
The unique gamertag set for this user and compatible with Xbox 360.
gamerScore
timestamp
The total gamer score earned by this user.
modernGamertag
timestamp
The gamertag set for this user using the new Xbox One configuration.
modernGamertagSuffix
timestamp
The gamertag suffix set for this user using the new Xbox One configuration.
uniqueModernGamertag
timestamp
The combined modern gamertag and suffix which represents the unique gamertag for the user.
xboxOneRep
string
Returns the Xbox One reputation score for this user.
presenceState
string
Provides the current state of the user; i.e. 'Online'
presenceText
string
Provides the current activity of the user; i.e. 'Playing Halo Infinite'
presenceDevices
null
Returns the list of devices the user is on.
isBroadcasting
boolean
Determines if the user is streaming live.
isCloaked
boolean
isQuarantined
boolean
isXbox360Gamerpic
boolean
lastSeenDateTimeUtc
timestamp
Provides the datetime of when the user was last seen.
suggestion
null
recommendation
null
search
object
Hide object
type
string
reasons
array
titleHistory
null
multiplayerSummary
null
recentPlayer
null
follower
null
preferredColor
object
Returns the primary, secondary and tertiary color set by the user.
Hide object
primaryColor
string
secondaryColor
string
tertiaryColor
string
presenceDetails
null
titlePresence
null
titleSummaries
null
presenceTitleIds
null
detail
object
Hide object
accountTier
string
bio
string
isVerified
boolean
location
string
tenure
string
watermarks
array
blocked
boolean
mute
false
followerCount
integer
followingCount
integer
hasGamePass
boolean
Determines if this user has an active Game Pass subscription.
communityManagerTitles
null
socialManager
null
broadcast
null
avatar
string
linkedAccounts
object
colorTheme
string
preferredFlag
string
preferredPlatforms
object
recommendationSummary
null
friendFinderState
null
accountLinkDetails
null
API Object
Object
people:Array[1]
0:Object
xuid:"2533274798129181"
isFavorite:false
isFollowingCaller:false
isFollowedByCaller:false
isIdentityShared:false
addedDateTimeUtc:null
displayName:null
realName:""
displayPicRaw:"https://images-eds-ssl.xboxlive.com/image?url=wHwbXKif8cus8csoZ03RW_ES.ojiJijNBGRVUbTnZKsoCCCkjlsEJrrMqDkYqs3MBhMLdvWFHLCswKMlApTSbzvES1cjEAVPrczatfOc0jR0Ss4zHEy6ErElLAY8rAVFRNqPmGHxiumHSE9tZRnlghsACzaoisWEww1VSUd9Sx0-&format=png"
showUserAsAvatar:"1"
gamertag:"xTACTICSx"
gamerScore:"19165"
modernGamertag:"xTACTICSx"
modernGamertagSuffix:""
uniqueModernGamertag:"xTACTICSx"
xboxOneRep:"GoodPlayer"
presenceState:null
presenceText:null
presenceDevices:null
isBroadcasting:false
isCloaked:null
isQuarantined:false
isXbox360Gamerpic:false
lastSeenDateTimeUtc:null
suggestion:null
recommendation:null
search:Object
Type:"None"
Reasons:Array[0]
titleHistory:null
multiplayerSummary:null
recentPlayer:null
follower:null
preferredColor:Object
primaryColor:"193e91"
secondaryColor:"101836"
tertiaryColor:"102c69"
presenceDetails:null
titlePresence:null
titleSummaries:null
presenceTitleIds:null
detail:Object
accountTier:"Gold"
bio:null
isVerified:false
location:null
tenure:null
watermarks:Array[0]
blocked:false
mute:false
followerCount:40
followingCount:34
hasGamePass:false
communityManagerTitles:null
socialManager:null
broadcast:null
avatar:null
linkedAccounts:null
colorTheme:"gamerpicblur"
preferredFlag:""
preferredPlatforms:Array[0]
recommendationSummary:null
friendFinderState:null
accountLinkDetails:null
GET /alerts
Get user notifications
This endpoint uses the comments service to return alerts.
Response fields and example.
•	alerts
objects
Hide object
id
string
action
string
path
string
actorXuid
string
actorGamertag
string
parentType
string
parentPath
string
ownerXuid
string
ownerGamertag
string
timestamp
timestamp
seen
boolean
rootPath
string
clubId
string
API Object
Object
alerts:Array[1]
0:Object
id:"08587232084657218732_430928276_2533274795899722"
action:"Like"
path:"comments.xboxlive.com/screenshotsmetadata.xboxlive.com/users/xuid(2533274798129181)/scids/72010100-7d7f-4105-b34e-3ec552a4c121/screenshots/47cb19df-2283-44fb-ae18-4fe277ff205d/likes/xuid(2533274795899722)"
actorXuid:"2533274795899722"
actorGamertag:"GATORLAlD"
parentType:"Screenshot"
parentPath:"screenshotsmetadata.xboxlive.com/users/xuid(2533274798129181)/scids/72010100-7d7f-4105-b34e-3ec552a4c121/screenshots/47cb19df-2283-44fb-ae18-4fe277ff205d"
ownerXuid:"2533274798129181"
ownerGamertag:"xTACTICSx"
timestamp:"2016-11-06T02:13:39.7557075Z"
seen:true
rootPath:"screenshotsmetadata.xboxlive.com/users/xuid(2533274798129181)/scids/72010100-7d7f-4105-b34e-3ec552a4c121/screenshots/47cb19df-2283-44fb-ae18-4fe277ff205d"
clubId:"0"
POST /generate/gamertag
Generate random gamertags
This endpoint uses the user management service to generate random gamertags that are available.
Request fields and example.
•	algorithm
integer
count
integer
seed
string
locale
string
API Object
Object
algorithm:1
count:3
seed:""
locale:"en-US"
Response fields and example.
•	gamertags
array
API Object
Object
Gamertags:Array[3]
0:"ShadowYard22009"
1:"BackCookie22017"
2:"GivenBell320978"
Suggest a change on GitHub.
•	Learn
o	About OpenXBL
o	Getting Started
o	API Console
o	Docs
•	Contribute
o	GitHub
o	Join us on Discord
o	Submit an Issue
o	Provide Feedback
OpenXBL is an unofficial Xbox Live API designed around developer friendly documentation. The best part, it's free!
    
Copyright © 2026 OpenXBL v3.1.0
We are in no way endorsed or affiliated with Microsoft Corporation, Xbox, Xbox LIVE or any Microsoft subsidiary. Images are registered trademarks of their respected owners.
By visiting our website you agree to our terms and conditions. | View operational status


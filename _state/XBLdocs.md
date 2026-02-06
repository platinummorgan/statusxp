account


GET
/api/v2/account
Get your profile information.


GET
/api/v2/account/{xuid}
Get someone elses profile information.


GET
/api/v2/search/{gamertag}
Find other players by gamertag.


GET
/api/v2/alerts
Get your alerts.


POST
/api/v2/generate/gamertag
Generate a random gamertag.


GET
/api/v2/{xuid}/presence
Presence for comma-separated list of specific XUIDs.

achievements


GET
/api/v2/achievements
Return your achievement list.


GET
/api/v2/achievements/player/{xuid}
Return a player achievement list.


GET
/api/v2/achievements/player/{xuid}/{titleId}
Return a player achievement list for specified game.


GET
/api/v2/achievements/player/{xuid}/title/{titleId}
Return a titles achievement list for specified Xbox 360 game.


GET
/api/v2/achievements/x360/{xuid}/title/{titleId}
Return a player title achievement list for specified Xbox 360 game.


GET
/api/v2/achievements/stats/{titleId}
Return your stats for a specified game.


GET
/api/v2/achievements/title/{titleId}
Return your stats for a specified game.


GET
/api/v2/achievements/title/{titleId}/{continuationToken}
Return your stats for a specified game.


GET
/api/v2/achievements/{titleIds}
Return your stats for a specified game.

activity


GET
/api/v2/activity/feed
Get activity feed.


POST
/api/v2/activity/feed
Post to activity feed.


GET
/api/v2/activity/history
Get activity history.


POST
/api/v2/activity/share
Creates a shareable link.

clubs


POST
/api/v2/clubs/recommendations
Get club recommendations.


GET
/api/v2/clubs/{clubId}
Get club details.


POST
/api/v2/clubs/{clubId}/invite/{xuid}
Invite someone to a club.


GET
/api/v2/clubs/owned
Get clubs owned by current user.


POST
/api/v2/clubs/create
Create a new club.


GET
/api/v2/clubs/find
Find clubs based off query.


POST
/api/v2/clubs/reserve
Reserve a club name.


GET
/api/v2/clubs/delete/{clubId}
Delete a club by id.

conversations


GET
/api/v2/conversations
Get your messages.


POST
/api/v2/conversations
Send a message.


GET
/api/v2/conversations/requests
List of invites.

dvr


GET
/api/v2/dvr/screenshots
Get your screenshots.


GET
/api/v2/dvr/gameclips
Get your game clips.


GET
/api/v2/dvr/gameclips/delete/{gameClipId}
Delete a game clip.


POST
/api/v2/dvr/privacy
Set the privacy setting for media content.

friends


GET
/api/v2/presence
Get the presence of all your friends.


GET
/api/v2/friends
Get your friends list.


GET
/api/v2/friends/{xuid}
Get friends list by xuid.


GET
/api/v2/friends/blocked
Get blocked players.


GET
/api/v2/friends/search/{gamertag}
Search your friends list.


POST
/api/v2/friends/add
Add friend(s).


POST
/api/v2/friends/remove
Remove friend.


GET
/api/v2/recent-players
List recently played players.


POST
/api/v2/friends/favorite
Add favorites.


POST
/api/v2/friends/favorite/{method}
Add favorites.

gamepass


GET
/api/v2/gamepass/all
Return list of all Game Pass Games.


GET
/api/v2/gamepass/pc
Return list of PC Games.


GET
/api/v2/gamepass/ea-play
Return list of EA Play Games.


GET
/api/v2/gamepass/no-controller
Return list of Games with no controller.

marketplace


GET
/api/v2/marketplace/new
Return list of New Games.


GET
/api/v2/marketplace/top-paid
Return list of Top Paid Games.


GET
/api/v2/marketplace/best-rated
Return list of Best Rated Games.


GET
/api/v2/marketplace/coming-soon
Return list of Coming Soon Games.


GET
/api/v2/marketplace/deals
Return list of Deals.


GET
/api/v2/marketplace/top-free
Return list of Top Free Games.


GET
/api/v2/marketplace/most-played
Return list of Most Played Games.


POST
/api/v2/marketplace/details
Return list Game details.


GET
/api/v2/marketplace/title/{titleId}
Return game by Xbox Title ID.

player


GET
/api/v2/player/summary
Get player summary.


GET
/api/v2/player/summary/{xuid}
Get player summary by XUID.


POST
/api/v2/player/stats
Request for multiple player statistics across titles.


GET
/api/v2/player/titleHistory
Get player title history.


GET
/api/v2/player/titleHistory/{xuid}
Get player title history by XUID.

session


GET
/api/v2/session
Returns list of current sessions.


POST
/api/v2/session/invite/{sessionId}
Invite to a party chat session.


PUT
/api/v2/session/{sessionName}/leave
Leave party chat session.


GET
/api/v2/session/{sessionName}
Get party chat session details.


GET
/api/v2/session/create
Creates a new party chat session.


GET
/api/v2/session/config
Returns configuration values.

group


GET
/api/v2/group
Get all your group conversations.


POST
/api/v2/group/create
Create a new group conversation.


POST
/api/v2/group/send
Send a message to a group conversation.


GET
/api/v2/group/summary/{groupId}
Get a summary of a group conversation.


GET
/api/v2/group/messages/{groupId}
List group messages.


POST
/api/v2/group/invite/voice
Invite to voice chat.


POST
/api/v2/group/invite
Invite to group chat.


POST
/api/v2/group/kick
Remove a user from group conversation.


POST
/api/v2/group/leave
Leave a group conversation.
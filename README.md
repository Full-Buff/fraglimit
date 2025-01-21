# fraglimit
Custom implementation of the mp_fraglimit functionality in SourceMod

this is now fully functional, but still kind of messy.
theres a bunch of functionality for customizing the hud overlay, but none of it works. leaving it in for now.

### To use this plugin, just install it in your server, then set the tf2 native cvar "mp_fraglimit" to whatever value you want. <br>The game will now function like TDM. Eventually I'll add functionality to easily switch it to an FFA format.

### Custom CVAR's

### sm_fragstatus
This is an admin command that simply shows the current frag counts of each team.

#

The compiled plugin found in the releases page is slightly modified so that the chat messages and hud elements dont attempt to show the text colors. since its broken right now, it just adds the hex value as a string to the text fields instead of using it to color them. v_v

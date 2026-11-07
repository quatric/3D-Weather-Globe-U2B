#import "WeatherGlobePrefix.h"
#import "AtlasController.h"

int main(int argc, const char *argv[])
{
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center addObserver:[AtlasController class] selector:@selector(_appDidFinishLaunching:)
		name:NSApplicationDidFinishLaunchingNotification object:nil];
	center = [NSNotificationCenter defaultCenter];
	[center addObserver:[AtlasController class] selector:@selector(_appWillTerminate:)
		name:NSApplicationWillTerminateNotification object:nil];
	@autoreleasepool {
		// the app has its own full screen view and no tabs; keep AppKit from
		// adding Show Tab Bar and Enter Full Screen to the 2011 menus
		[NSWindow setAllowsAutomaticWindowTabbing:NO];
		[[NSUserDefaults standardUserDefaults] registerDefaults:
			[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"NSFullScreenMenuItemEverywhere"]];
	}
	return NSApplicationMain(argc, argv);
}

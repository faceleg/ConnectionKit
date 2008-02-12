#import "Controller.h"
#import <HostSetupAssistant/HSAController.h>

@implementation Controller

- (void)awakeFromNib
{
	NSDictionary *props = [[NSUserDefaults standardUserDefaults] objectForKey:@"HSA"];
	if (props == nil)
	{
		props = [NSDictionary dictionary];
	}
	myProperties = [props copy];
	[oTextView setString:[myProperties description]];
}

- (IBAction)launchHSA:(id)sender
{
	if (!myAssistant)
	{
		myAssistant = [[HSAController alloc] initWithProperties:myProperties];
	}
	[myAssistant setProperties:myProperties];
	[myAssistant beginSheetModalForWindow:oWindow
							modalDelegate:self
						   didEndSelector:@selector(hostSetupAssistantDidEnd:returnCode:userInfo:)
								 userInfo:nil];
}

- (void)hostSetupAssistantDidEnd:(HSAController *)hsa returnCode:(int)returnCode userInfo:(id)userInfo
{
	if (returnCode == NSOKButton)
	{
		[myProperties autorelease];
		myProperties = [[hsa properties] copy];
		[oTextView setString:[NSString stringWithFormat:@"%@\n\nNew Properties:\n%@", [oTextView string], myProperties]];
		[[NSUserDefaults standardUserDefaults] setObject:myProperties forKey:@"HSA"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
}

@end

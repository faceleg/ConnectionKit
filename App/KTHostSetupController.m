//
//  KTHostSetupController.m
//  Marvel
//
//  Created by Dan Wood on 11/10/04.
//  Copyright 2004-2009 Karelia Software. All rights reserved.
//

/*
PURPOSE OF THIS CLASS/CATEGORY:
	x

TAXONOMY AND RELATIONSHIP TO OTHER CLASSES:
	x
"t
IMPLEMENTATION NOTES & CAUTIONS:
	We use "intValue" not "boolValue" so string properties can be parsed as booleans.

TO DO:

 */

#import "KTHostSetupController.h"

#import "Debug.h"
#import "KSUtilities.h"
#import "KT.h"
#import "KTAppDelegate.h"
#import "KTApplication.h"
#import "KTBackgroundTabView.h"
#import "KTDocument.h"
#import "KTHost.h"
#import "KTHostProperties.h"
#import "KTTranscriptController.h"
#import "NSApplication+Karelia.h"
#import "NSAttributedString+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSCharacterSet+Karelia.h"
#import "NSColor+Karelia.h"
#import "NSError+Karelia.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSString+KTExtensions.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"
#import "NSWorkspace+Karelia.h"
#import "NTSUTaskController.h"

#import <AddressBook/AddressBook.h>
#import <Connection/Connection.h> // for CKAbstractConnection, ConnectionOpenPanel, EMKeychainItem, and EMKeychainProxy

#import <Security/Security.h>
#import <sys/sysctl.h>


NSString *KTHostConnectionTimeoutValueKey = @"connectionTimeoutValue";

@interface ProtocolToIndexTransformer : NSValueTransformer
@end

// TODO: convert NSLog to LOG in this file after bugs have been shaken out

@interface KTHostSetupController ( private )
- (void)appendConnectionProgressLine:(BOOL)aNewLine format:(NSString *)aString, ...;
- (BOOL) createTestFileInDirectory:(NSString *)aDirectory;
- (void)updateSummaryString;
- (void) updateDotMacStatus:(NSTimer *)aTimer;
- (void) updateApacheStatus:(NSTimer *)aTimer;
- (BOOL) isApacheRunning;
- (void)loadPasswordFromKeychain:(id)bogus;
- (NSString *)passwordFromKeychain;
- (void)setKeychainPassword:(NSString *)aPassword;
- (void) tryToReachLocalHost:(BOOL)aStartStopFlag;
- (NSString *)globalBaseURLUsingHome:(BOOL)inHome allowNull:(BOOL)allowNull;;
- (void) startTestConnection:(id)bogus;
- (void)disconnectConnection;
- (NSString *)testFileUploadPath;
- (NSString *)testFileRemoteURL;
- (NSString *)subFolderPath;
- (void) updatePortPlaceholder;
- (void) clearRemoteProperties;
- (BOOL) change:(NSString *)aPath toPermissions:(int)aPermissions;
- (NSTimeInterval)connectionTimeoutValue;
@end

static NSSet *sUrlKeySet;
static NSSet *sSubFolderSet;
static NSSet *sHostNameSet;
static NSCharacterSet *sWhitespaceAndSlashSet;
static NSCharacterSet *sIllegalUserNameSet;
static NSCharacterSet *sIllegalSubfolderSet;

@implementation KTHostSetupController


+ (void) initialize
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	sUrlKeySet = [[NSSet setWithObjects:@"homePageURL", @"setupURL", @"stemURL", nil] retain];
	sSubFolderSet = [[NSSet setWithObjects:@"localSubFolder", @"subFolder", nil] retain];
	sHostNameSet = [[NSSet setWithObjects:@"localHostName", @"hostName", nil] retain];
	sWhitespaceAndSlashSet = [[[NSCharacterSet whitespaceAndNewlineCharacterSet] setByAddingCharactersInString:@"/"] retain];
	
	// alphanumeric, underline, and dash
	sIllegalUserNameSet =
		[[[[NSCharacterSet alphanumericCharacterSet] setByAddingCharactersInString:@"_%-@.~"] invertedSet] retain];	// diacriticals in user name?  Maybe
	sIllegalSubfolderSet =
		[[[[NSCharacterSet alphanumericASCIICharacterSet] setByAddingCharactersInString:@"_-."] invertedSet] retain];	// part of URL; restrict

	NSValueTransformer *theTransformer;

	theTransformer = [[[ProtocolToIndexTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:theTransformer
									forName:@"ProtocolToIndexTransformer"];
    [KTHostSetupController setKeys:
        [NSArray arrayWithObjects: @"localSubFolder", @"localSharedMatrix", nil]
        triggerChangeNotificationsForDependentKey: @"localURL"];
    [KTHostSetupController setKeys:
        [NSArray arrayWithObjects: @"localHostName", @"localSubFolder", @"localSharedMatrix", nil]
        triggerChangeNotificationsForDependentKey: @"globalSiteURL"];
    [KTHostSetupController setKeys:
        [NSArray arrayWithObjects: @"subFolder", @"userName", @"docRoot", @"remoteHosting", @"stemURL", @"domainName", nil]
        triggerChangeNotificationsForDependentKey: @"remoteSiteURL"];

	[KTHostSetupController setKeys:
			[NSArray arrayWithObjects: @"hostName", @"port", @"docRoot", @"stemURL", @"protocol", @"subFolder", @"userName", nil]
        triggerChangeNotificationsForDependentKey: @"uploadURL"];

	[KTHostSetupController setKeys:
		[NSArray arrayWithObjects: @"stemURL", @"userName", @"subFolder",  nil]
        triggerChangeNotificationsForDependentKey: @"remoteSiteURLIsValid"];
	
	[KTHostSetupController setKeys:
		[NSArray arrayWithObjects: @"protocol", @"usePublicKey", nil]
        triggerChangeNotificationsForDependentKey: @"enablePassword"];
	
	[KTHostSetupController setKeys:
		[NSArray arrayWithObjects:@"hostName", @"userName", nil]
		triggerChangeNotificationsForDependentKey:@"password"];
	
	[KTHostSetupController setKeys:
	 [NSArray arrayWithObjects:@"dotMacPersonalDomain", nil]
		triggerChangeNotificationsForDependentKey:@"docRoot"];		// domain affects docRoot, which affects other stuff.

	[KTHostSetupController setKeys:
	 [NSArray arrayWithObjects:@"dotMacPersonalDomain", nil]
		triggerChangeNotificationsForDependentKey:@"domainName"];		// domain affects docRoot, which affects other stuff.

	[KTHostSetupController setKeys:
	 [NSArray arrayWithObjects:@"dotMacPersonalDomain", nil]
		triggerChangeNotificationsForDependentKey:@"stemURL"];
	
	[KTHostSetupController setKeys:[NSArray arrayWithObject:@"protocol"] triggerChangeNotificationsForDependentKey:@"showSFTPMessage"];
	
	[KTHostSetupController setKeys:
		[NSArray arrayWithObjects: @"currentState", nil]
        triggerChangeNotificationsForDependentKey: @"canCreateNewConfiguration"];
	
	[pool release];
}

- (id)initWithHostProperties:(KTHostProperties *)hostProperties
{
	[super initWithWindowNibName:@"HostSetup" owner:self];
	
	[self setProperties:hostProperties];
	
	//		// there are 2 keys by default in the dict
	//		[self setValue:[NSNumber numberWithBool:[[[hostProperties currentValues] allKeys] count] > 2]
	//				forKey:@"isEditing"];
	
	BOOL isNewSetup = ( (NO == [hostProperties boolForKey:@"localHosting"]) && (NO == [hostProperties boolForKey:@"remoteHosting"]) );
	[self setValue:[NSNumber numberWithBool:!isNewSetup]
			forKey:@"isEditing"];
	
	
	if ([[self valueForKey:@"localHosting"] intValue] == 1 && 
		[[self valueForKey:@"remoteHosting"] intValue] == 1)
	{
		[self setValue:[NSNumber numberWithInt:0] forKey:@"localHosting"];
	}
	
	if ([[self valueForKey:@"protocol"] isEqualToString:@".Mac"] 
		&& nil == [self valueForKey:@"dotMacDomainStyle"])
	{
		// It was not set, so assume it's a legacy document, which is homepage.mac.com
		[self setValue:[NSNumber numberWithInt:HOMEPAGE_MAC_COM] forKey:@"dotMacDomainStyle"];
	}
	
	// Try to reach localhost when localHosting checkbox is checked -- and abort it when unchecked.
	[self tryToReachLocalHost:[hostProperties integerForKey:@"localHosting"]];	// start or stop the reaching process
	[self addObserver:self forKeyPath:@"localHosting" options:(NSKeyValueObservingOptionNew) context:nil];
	[self addObserver:self forKeyPath:@"localHostName" options:(NSKeyValueObservingOptionNew) context:nil];
	[self addObserver:self forKeyPath:@"localSharedMatrix" options:(NSKeyValueObservingOptionNew) context:nil];
	[self addObserver:self forKeyPath:@"protocol" options:(NSKeyValueObservingOptionNew) context:nil];
	[self addObserver:self forKeyPath:@"userName" options:(NSKeyValueObservingOptionNew) context:nil];
	[self addObserver:self forKeyPath:@"hostName" options:(NSKeyValueObservingOptionNew) context:nil];
	[self addObserver:self forKeyPath:@"dotMacDomainStyle" options:(NSKeyValueObservingOptionNew) context:nil];
	[self addObserver:self forKeyPath:@"dotMacPersonalDomain" options:(NSKeyValueObservingOptionNew) context:nil];
	[self setTrail:[NSMutableArray array]];
	
	if (nil == [[self properties] valueForKey:@"localHostName"])
	{
	}
	
	if (nil == [[self properties] valueForKey:@"hostTypeMatrix"])
	{
		// Default to my ISP if there is no .mac name set up for this account right now.
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		NSString *iToolsMember = [defaults objectForKey:@"iToolsMember"];
		int matrixSelection =  (nil == iToolsMember || [iToolsMember isEqualToString:@""]) ? OTHER_ISP : DOT_MAC;
		{
			[self setValue:[NSNumber numberWithInt:matrixSelection] forKey:@"hostTypeMatrix"];
		}
	}
	if (nil == [[self properties] valueForKey:@"localSharedMatrix"])
	{
		[self setValue:[NSNumber numberWithInt:HOMEDIR] forKey:@"localSharedMatrix"];
	}
	if (nil == [[self properties] valueForKey:@"protocol"])
	{
		[self setValue:@"FTP" forKey:@"protocol"];
	}
	if (nil == [[self properties] valueForKey:@"createNewHost"] && ![[self valueForKey:@"isEditing"] boolValue] )
	{
		[self setValue:[NSNumber numberWithBool:YES] forKey:@"createNewHost"];
	}
	return self;
}

- (void)windowWillClose:(NSNotification *)notification;
{
	[oMainObjectController setContent:nil];
}

- (void)awakeFromNib
{
	[oMainObjectController setContent:self];
	[oIntroductionTextView setDrawsBackground:NO];
	NSScrollView *scrollView = [oIntroductionTextView enclosingScrollView];
	[scrollView setDrawsBackground:NO];
	[[scrollView contentView] setCopiesOnScroll:NO];
	[oSummaryTextView setDrawsBackground:NO];
	scrollView = [oSummaryTextView enclosingScrollView];
	[scrollView setDrawsBackground:NO];
	[[scrollView contentView] setCopiesOnScroll:NO];
	[oSummaryTextView setTextContainerInset:NSMakeSize(20,20)];
	[oIntroductionTextView setTextContainerInset:NSMakeSize(20,20)];

	[self setCurrentState:@"introduction"];
	[self updatePortPlaceholder];

	
	NSMutableAttributedString *attrString = [[[oDotMacSetupLink attributedTitle] mutableCopyWithZone:[oDotMacSetupLink zone]] autorelease];
	NSRange range = NSMakeRange(0,[attrString length]);
	
	[attrString addAttribute:NSForegroundColorAttributeName value:[NSColor linkColor]
					   range:range];
	[attrString addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInt:1]
					   range:range];
	[attrString addAttribute:NSCursorAttributeName value:[NSCursor pointingHandCursor]
					   range:range];
	[oDotMacSetupLink setAttributedTitle:attrString];

	
	// turn off the radio group
	[oHostTypeMatrix deselectAllCells];
}


- (void)dealloc
{
	[self removeObserver:self forKeyPath:@"localHosting"];
	[self removeObserver:self forKeyPath:@"localHostName"];
	[self removeObserver:self forKeyPath:@"localSharedMatrix"];
	[self removeObserver:self forKeyPath:@"protocol"];
	[self removeObserver:self forKeyPath:@"userName"];
	[self removeObserver:self forKeyPath:@"hostName"];

	[self setConnectionStatus:nil];
	[self setConnectionProgress:nil];

	[self setTemporaryTestFilePath:nil];
	[self setProperties: nil];
    [self setOriginalProperties: nil];
    [self setTrail: nil];
    [self setCurrentState: nil];
    [self setDotMacTimer: nil];
	[self setApacheTimer: nil];
    [self setPassword: nil];
    [self setConnectionStatusColor: nil];
    [self setDefaultISP: nil];
    [self setConnectionData: nil];
    [self setReachableConnection: nil];
	[self setDownloadTestConnection: nil];

	[myRemotePath release];
	
    [super dealloc];
}


#pragma mark -
#pragma mark Actions

- (IBAction) openPreferredHost:(id)sender;
{
	[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:[NSURL URLWithString:[sender title]]];
	
}

- (IBAction) settingUpDotMacPersnalDomains:(id)sender;
{
	[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:[NSURL URLWithString:@"http://docs.info.apple.com/article.html?path=MobileMe/Account/en/acct17114.html"]];
}

- (IBAction) windowHelp:(id)sender
{
	NSDictionary *lookupHelp = [NSDictionary dictionaryWithObjectsAndKeys:		// HELPSTRING ... MANY HERE!
		@"Host_Overview", @"introduction",
		@"Choosing_a_Publishing_Location", @"where",
		@"Publishing_to_your_Computer", @"apache",
		@"Publishing_to_your_Computer", @"local",
		@"Publishing_to_your_Computer", @"localError",
		@"Publishing_to_.Mac", @"mac",
		@"Entering_Your_Host_Settings", @"host",
		@"Entering_Your_Account_Details", @"account",
		@"Testing_Your_Connection", @"test",
		@"Host_Summary", @"summary",
		nil];
	
	NSString *pageName = [lookupHelp objectForKey:myCurrentState];

	// special case -- troubleshooting
	if (myShouldShowConnectionTroubleshooting
		&& ([myCurrentState isEqualToString:@"summary"] || [myCurrentState isEqualToString:@"introduction"]) )
	{
		pageName = @"Troubleshooting_Publishing_and_Connections";	// HELPSTRING
	}
	if (nil == pageName) pageName = @"Setting_Up_Your_Host";	// HELPSTRING

	[[NSApp delegate] showHelpPage:pageName];
}

- (IBAction)createNewConfiguration:(id)sender
{
	[self setValue:[NSNumber numberWithBool:NO] forKey:@"isEditing"];
	[self setValue:[NSNumber numberWithInt:0] forKey:@"remoteHosting"];	// choose NEITHER
	[self setValue:[NSNumber numberWithInt:0] forKey:@"localHosting"];
	[self setValue:[NSNumber numberWithInt:0] forKey:@"hostTypeMatrix"];
	[self setValue:[NSNumber numberWithInt:WEB_ME_COM] forKey:@"dotMacDomainStyle"];	// initially homepage.mac.com
	[self doNext:sender];
}

#pragma mark -
#pragma mark Authentication Support

/*  Support method that will first attempt to authenticate the connection. After that it gives up.
 */
- (void)handleAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    NSURLCredential *credential = nil;
    
    if ([challenge previousFailureCount] == 0)
	{
		if ([[[self properties] valueForKey:@"protocol"] isEqualToString:@".Mac"])
		{
			credential = [challenge proposedCredential];
		}
		else
		{
			NSString *user = [[self properties] valueForKey:@"userName"];
			
			BOOL isSFTPWithPublicKey = [[[self properties] valueForKey:@"protocol"] isEqualToString:@"SFTP"] && [[[self properties] valueForKey:@"usePublicKey"] intValue] == NSOnState;
			if (isSFTPWithPublicKey)
            {
                credential = [NSURLCredential credentialWithUser:user
                                                        password:nil
                                                     persistence:NSURLCredentialPersistenceNone];
            }
            else
            {
                NSString *password = [self password];
                if (password)   // Need this check otherwise we effectively tell SFTP to use public key auth
                {
                    credential = [NSURLCredential credentialWithUser:user
                                                            password:password
                                                         persistence:NSURLCredentialPersistenceNone];
                }
            }
		}
	}
	
    
    if (credential)
    {
        [[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
    }
    else
	{
		[[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
	}
}

#pragma mark -
#pragma mark ConnectionOpenPanel

// delegate method for the open panel
- (void)connectionOpenPanel:(CKConnectionOpenPanel *)panel didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
	if ([challenge previousFailureCount] == 0)
    {
        [self handleAuthenticationChallenge:challenge];
    }
    else
    {
        [[challenge sender] cancelAuthenticationChallenge:challenge];
        [self setValue:[NSNumber numberWithBool:YES] forKey:@"browseHasBadPassword"];
        [panel closePanel:nil];
    }
}

- (IBAction)browseHostToSelectPath:(id)sender
{
	NSString *protocol = [self valueForKey:@"protocol"];
	NSString *host = [self valueForKey:@"hostName"];
	
	// show the ConnectionOpenPanel
	CKConnectionRequest *connectionRequest = [[CKConnectionRegistry sharedConnectionRegistry] connectionRequestForName:protocol
                                                                                                                  host:host
                                                                                                                  port:[self valueForKey:@"port"]];
    
    CKConnectionOpenPanel *choose = [(CKConnectionOpenPanel *)[CKConnectionOpenPanel alloc] initWithRequest:connectionRequest];
    if (!choose)
	{
		return;
	}
	
    
	[choose setCanChooseDirectories:YES];
	[choose setCanChooseFiles:NO];
	[choose setCanCreateDirectories:NO];	 // Disable creating directories since that confuses people with doc root.
	
	//set the current value to initial dir for webdav if / is not allowed.

	[[self window] makeFirstResponder:nil];		// unfocus text field so binding will work

		
	// Connect at the chosen document root if possible. iDisk is odd though and CANNOT connect at the root dir
	NSString *documentRoot = [self valueForKey:@"docRoot"];
	if ([host isEqualToStringCaseInsensitive:@"idisk.mac.com"] &&
		[protocol isEqualToString:@"WebDAV"] &&
		(!documentRoot || [documentRoot isEqualToString:@""] || [documentRoot isEqualToString:@"/"]))
	{
		documentRoot = [@"/" stringByAppendingString:[self valueForKey:@"userName"]];
	}
	
	[choose beginSheetForDirectory:documentRoot
							  file:nil
					modalForWindow:[self window]
					 modalDelegate:self
					didEndSelector:@selector(browseHostPathDidEnd:returnCode:contextInfo:)
					   contextInfo:nil];
	
}

- (void)browseHostPathDidEnd:(CKConnectionOpenPanel *)choose returnCode:(int)returnCode contextInfo:(id)info
{
	if (returnCode == NSOKButton)
	{
		[self setValue:[[choose filenames] objectAtIndex:0] forKey:@"docRoot"];
	}
	else if (returnCode == -1)
	{
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Password was not accepted.", @"status message for test connection")
										 defaultButton:nil 
									   alternateButton:nil 
										   otherButton:nil
							 informativeTextWithFormat:@""];
		(void)[alert runModal];
		
	}
	[choose autorelease];
}

- (IBAction)browseHostAccountPanelOK:(id)sender
{
	[NSApp stopModalWithCode:NSOKButton];
	[oBrowseHostAccountPanel orderOut:self];
	// get the password and username
	NSString *username = [oBrowseHostUsername stringValue];
	NSString *password = [oBrowseHostPassword stringValue];
	
	if (username)
	{
		[self setValue:username forKey:@"userName"];
	}
	if (password)
	{
		[self setValue:password forKey:@"password"];
	}
	[self browseHostToSelectPath:self];
}

- (IBAction)browseHostAccountPanelCancel:(id)sender
{
	[NSApp stopModalWithCode:NSCancelButton];
	[oBrowseHostAccountPanel orderOut:self];
}

/*!	State machine logic.
*/
- (IBAction) doNext:(id)sender
{
	[self setWantsNextWhenDoneLoading:NO];	// make sure no delayed "doNext" pending now that we're doing it
	// Force end editing ... any better way?
	if (![[oTabView window] makeFirstResponder:nil])
	{
		return;	// can't resign status, so don't do next!
	}
	if (nil != myReachableConnection && ![myCurrentState isEqualToString:@"introduction"])
	{
		// Need to delay this action until the data comes back.  But plow on ahead if introduction.
		[oPreviousButton setEnabled:NO];
		[oNextButton setEnabled:NO];
		[self setWantsNextWhenDoneLoading:YES];
		return;
	}

	NSString	*nextState = nil;
	NSString	*stateWeAreComingFrom = myCurrentState;

	if ([stateWeAreComingFrom isEqualToString:@"introduction"])
	{
		if ([[self valueForKey:@"isEditing"] boolValue] == YES)
		{
			if ([[self valueForKey:@"remoteHosting"] intValue] == 1)
			{
				if ([[self valueForKey:@"protocol"] isEqualToString:@".Mac"])
				{
					nextState = @"mac";
				}
				else
				{
					nextState = @"host";
				}
			}
			else
			{
				nextState = @"local";
			}
		}
		else
		{
			nextState = @"where";
		}
	}

	if ([stateWeAreComingFrom isEqualToString:@"where"])
	{
		if ([[[self properties] valueForKey:@"localHosting"] intValue])
		{
			if ([self isApacheRunning])
			{
				nextState = @"local";
			}
			else
			{
				nextState = @"apache";
			}
		}
		else if ([[[self properties] valueForKey:@"remoteHosting"] intValue])
		{
			stateWeAreComingFrom = @"local";
			// emulate coming from local since the behavior is the same.

		}
		else
		{
			nextState = @"summary";	// go to summary, not hosted
		}

	}

	if ([stateWeAreComingFrom isEqualToString:@"local"]
		|| [stateWeAreComingFrom isEqualToString:@"localError"])
	{

		if ([[[self properties] valueForKey:@"localHosting"] intValue]
			&& myLocalHostVerifiedStatus >= LOCALHOST_UNREACHABLE
			&& ![stateWeAreComingFrom isEqualToString:@"localError"])
		{
			NSMutableString *message = [NSMutableString string];

			[message appendString:NSLocalizedString(@"Sandvox was not able to successfully reach your computer from the Internet.","could not connect")];
			[message appendString:@"\n\n"];

			NSString *globalSiteURL = [self globalSiteURL];
			switch (myLocalHostVerifiedStatus)
			{
				case LOCALHOST_WRONGCOMPUTER:
					[message appendFormat:NSLocalizedString(@"It appears that the URL, %@, does not resolve to this computer. One reason is that the hostname of this computer may have been improperly specified, and not actually correspond to your computer.", "Host Setup - wrong computer"), globalSiteURL];
					break;
				case LOCALHOST_404:	// 404 ... document not found, so maybe it's not going to the right computer
					[message appendFormat:NSLocalizedString(@"It appears that the URL, %@, does not resolve to this computer. A web server was contacted, but the test file was not found. One explanation is that you may have a router installed on your local network that does not send requests for web pages to your computer. You will need to consult the documentation for your router or speak to your network administrator.", "Host Setup - 404"), globalSiteURL];
					break;
				default:
					[message appendFormat:NSLocalizedString(@"No web server appears to be responding at the URL you specified, %@. The web server on your computer may not be functioning. Or the hostname of this computer may have been improperly specified. Or you may have a router installed on your local network that does not send requests for web pages to your computer. You will need to consult the documentation for your router or speak to your network administrator.", "Host Setup - No Web Server"), globalSiteURL];
					break;
			}
			[oLocalHostErrorString setStringValue:message];

			nextState = @"localError";
		}
		else
		{
			// Done with local; now go to remote stuff
			if ([[[self properties] valueForKey:@"remoteHosting"] intValue])
			{
				int selectedRemoteHostType = [[[self properties] valueForKey:@"hostTypeMatrix"] intValue];
				int originalRemoteHostType = [[myOriginalProperties objectForKey:@"hostTypeMatrix"] intValue];
				
				if (selectedRemoteHostType == DOT_MAC)	// .Mac
				{
					nextState = @"mac";
				}
				else if (selectedRemoteHostType == OTHER_ISP)	// other
				{
					if (originalRemoteHostType != OTHER_ISP)
					{
						// if we have ever changed from .mac to remote, .mac settings are still in there.
						[self setValue:nil forKey:@"domainName"];
						[self setValue:nil forKey:@"homePageURL"];
						[self setValue:nil forKey:@"hostName"];
						[self setValue:nil forKey:@"docRoot"];
						[self setValue:@"FTP" forKey:@"protocol"];
						[self setValue:nil forKey:@"provider"];
						[self setValue:nil forKey:@"stemURL"];
						[self setValue:nil forKey:@"setupURL"];
						nextState = @"host";
					}
					else
					{
						nextState = @"host";
					}
					
				}
			}
			else
			{
				nextState = @"summary";	// go back to summary, not hosted
			}
		}

	}
	else if ([stateWeAreComingFrom isEqualToString:@"apache"])
	{
		nextState = @"local";
	}
	else if ([stateWeAreComingFrom isEqualToString:@"mac"])
	{
		if (nil == [[self properties] valueForKey:@"userName"])
		{
			nextState = @"summary";		// don't bother connecting; no account.
		}
		else
		{
			nextState = @"test";
		}
	}
	else if ([stateWeAreComingFrom isEqualToString:@"host"])
	{
		// manual domain name .... so don't save it, so we won't match to table
		[self setValue:nil forKey:@"domainName"];
		
		if ([[self valueForKey:@"selectNewHost"] boolValue])
		{
			nextState = @"host";
			[self setValue:[NSNumber numberWithBool:NO] forKey:@"selectNewHost"]; //turn it off for when we come back to this screen
		}
		else if (nil ==  [[self properties] valueForKey:@"hostName"] || 
				 nil == [[self properties] valueForKey:@"stemURL"] ||
				 nil == [[self properties] valueForKey:@"userName"])
		{
			nextState = @"summary";	// done, can't set up the account
		}
		else 
		{
			// see if we can substitute the account name in the stemURL
			NSMutableString *urlString = [NSMutableString stringWithString:[[self properties] valueForKey:@"stemURL"]];
			NSString *account = [[self properties] valueForKey:@"userName"];
			
			if ([urlString rangeOfString:account].location != NSNotFound) {
				NSURL *url = [NSURL URLWithUnescapedString:urlString];
				NSString *urlHost = [url host];
				NSArray *hostComponents = [urlHost componentsSeparatedByString:@"."];
				NSMutableArray *newHostComponents = [NSMutableArray array];
				NSEnumerator *e = [hostComponents objectEnumerator];
				NSString *cur;
				
				while (cur = [e nextObject])
				{
//					if ([cur isEqualToString:account])
//					{
//						[newHostComponents addObject:@"?"];
//					}
//					else
//					{
						[newHostComponents addObject:cur];
//					}
				}
				NSString *newHost = [newHostComponents componentsJoinedByString:@"."];
				if (urlHost && newHost)
				{
					[urlString replaceOccurrencesOfString:urlHost withString:newHost options:NSLiteralSearch range:NSMakeRange(0, [urlString length])];
				}
				// [urlString replaceOccurrencesOfString:account withString:@"?" options:NSLiteralSearch range:NSMakeRange([newHost length], [urlString length] - [newHost length])];
				LOG((@"setting stemURL to %@ after subbing username", urlString));
				[self setValue:urlString forKey:@"stemURL"]; 
			}
			nextState = @"test";	// we have chosen, now get the details
		}
		// make sure docRoot isn't null and make it empty if it is.
		if (![[self properties] valueForKey:@"docRoot"]) {
			[self setValue:@"" forKey:@"docRoot"];
		}
	}
	else if ([stateWeAreComingFrom isEqualToString:@"account"])
	{
		if ([[self valueForKey:@"selectNewHost"] boolValue])
		{
			nextState = @"host";
			[self setValue:[NSNumber numberWithBool:NO] forKey:@"selectNewHost"]; //turn it off for when we come back to this screen
		}
		else if (nil == [[self properties] valueForKey:@"userName"]
			|| nil ==  [[self properties] valueForKey:@"hostName"]
			|| ![self remoteSiteURLIsValid]) //we can have an empty password for sftp as it uses authorized_keys2 mechanism
		{
			nextState = @"summary";	// done, can't do the test
		}
		else
		{
			// see if we can substitute the account name in the stemURL
			NSMutableString *urlString = [NSMutableString stringWithString:[[self properties] valueForKey:@"stemURL"]];
			NSString *account = [[self properties] valueForKey:@"userName"];
			
			if ([urlString rangeOfString:account].location != NSNotFound) {
				NSURL *url = [NSURL URLWithUnescapedString:urlString];
				NSString *urlHost = [url host];
				NSArray *hostComponents = [urlHost componentsSeparatedByString:@"."];
				NSMutableArray *newHostComponents = [NSMutableArray array];
				NSEnumerator *e = [hostComponents objectEnumerator];
				NSString *cur;
				
				while (cur = [e nextObject])
				{
//					if ([cur isEqualToString:account])
//					{
//						[newHostComponents addObject:@"?"];
//					}
//					else
//					{
						[newHostComponents addObject:cur];
//					}
				}
				NSString *newHost = [newHostComponents componentsJoinedByString:@"."];
				[urlString replaceOccurrencesOfString:urlHost withString:newHost options:NSLiteralSearch range:NSMakeRange(0, [urlString length])];
				// [urlString replaceOccurrencesOfString:account withString:@"?" options:NSLiteralSearch range:NSMakeRange([newHost length], [urlString length] - [newHost length])];
				LOG((@"setting stemURL to %@ after subbing username", urlString));
				[self setValue:urlString forKey:@"stemURL"]; 
			}
			nextState = @"test";	// do the test to see if we can connect
		}
	}
	else if ([stateWeAreComingFrom isEqualToString:@"test"])
	{
		nextState = @"summary";
			
	}

	// If not yet set, initialize .mac style to Mobile Me for new sites
	if ([nextState isEqualToString:@"mac"] && nil == [self valueForKey:@"dotMacDomainStyle"])
	{
		// It was not set, so assume it's a legacy document, which is homepage.mac.com
		[self setValue:[NSNumber numberWithInt:WEB_ME_COM] forKey:@"dotMacDomainStyle"];
	}
	
	if (nil == nextState)
	{
		[NSException raise:@"KTInconsistentStateMachineException" format:@"Host setup cannot find next step from state '%@'", myCurrentState];
	}

	if (![myCurrentState isEqualToString:@"introduction"] && ![myCurrentState isEqualToString:@"localError"] && ![myCurrentState isEqualToString:@"test"])	// can't go back to introduction, localError, test
	{
		[myTrail addObject:myCurrentState];
	}
	[self setCurrentState:nextState];
}

/*!	Go back to previous state
*/
- (IBAction) doPrevious:(id)sender
{
	if (0 == [myTrail count])	// do nothing if clicked when transparent
	{
		return;
	}
	[self disconnectConnection];
	[myReachableConnection cancel];
	[myDownloadTestConnection cancel];

	// Force end editing ... any better way?
	if (![[oTabView window] makeFirstResponder:nil])
	{
		return;
	}
	if ([myCurrentState isEqualToString:@"mac"]) {
		// clear out the host settings
		[self setValue:nil forKey:@"hostName"];
		[self setValue:nil forKey:@"port"];
		[self setValue:nil forKey:@"docRoot"];
		[self setValue:nil forKey:@"stemURL"];
		[self setValue:nil forKey:@"domainName"];
		[self setValue:nil forKey:@"homePageURL"];
		[self setValue:nil forKey:@"setupURL"];
		[self setValue:nil forKey:@"storageLimitMB"];
	}

	NSString *prevState = [myTrail lastObject];
	[myTrail removeLastObject];
	[self setCurrentState:prevState];
}

- (IBAction) doCancel:(id)sender
{
	[self disconnectConnection];
	[myReachableConnection cancel];
	[myDownloadTestConnection cancel];

	[self setDotMacTimer:nil];	// Be sure timers are not running
	[self setApacheTimer:nil];
	[NSApp endSheet:[self window] returnCode:0];
	[[self window] orderOut:sender];
}

- (IBAction) doOK:(id)sender
{
	BOOL remoteHosting = [[[self properties] valueForKey:@"remoteHosting"] intValue];
	BOOL remoteHostingValid = remoteHosting && [self remoteSiteURLIsValid];
	BOOL goAhead = !remoteHosting || remoteHostingValid;	// OK if we are not remote-hosting, or validly remote-hosting
	if (!goAhead)
	{
		int alertResult = NSRunAlertPanel(
			NSLocalizedString(@"Do you really want to save your incomplete hosting information?", "Title of alert"),
			NSLocalizedString(@"You have not fully specified and tested your connection information. You may save the configuration in progress, but your website cannot be published until you finish.", "Message in alert prompting user to fill out hosting info"),
			NSLocalizedString(@"Save", "Save Button"), NSLocalizedString(@"Don\\U2019t Save", "Don't Save Button"), NSLocalizedString(@"Cancel", "Cancel Button"));

		switch (alertResult) // -1=cancel, 0 = don't save, 1 = Save
		{
			case 0:	// don't save -- effectively, cancel the alert
				[self doCancel:sender];
				break;
			case 1:
				goAhead = YES;
				break;
		};
	}
	if (goAhead)
	{
		[self setDotMacTimer:nil];	// Be sure timers not running
		[self setApacheTimer:nil];
		[NSApp endSheet:[self window] returnCode:1];
		[[self window] orderOut:sender];
		
		// set the password AFTER the window closes; we may have an error message
		if ( remoteHosting )
		{
			NSString *pass = [self password];
			if (pass && ![pass isEqualToString:@""] 
				&& !([[myProperties valueForKey:@"hostName"] isEqualToString:@"idisk.mac.com"] 
					 && [[[self properties] valueForKey:@"protocol"] isEqualToString:@".Mac"]) )  // TODO - excise .Mac by name from this code
			{
				[self setKeychainPassword:pass];		// finally, store the password in the keychain
			}
		}
	}
}


- (IBAction) doDotMacConfigure:(id)sender
{
	NSString *appleScriptString = @"tell application \"System Preferences\"\nactivate\nset current pane to pane \"com.apple.preference.internet\"\nend tell";
	NSAppleScript *script = [[[NSAppleScript alloc] initWithSource:appleScriptString] autorelease];
	NSDictionary *errorDict = nil;
	(void) [script executeAndReturnError:&errorDict];
}

- (IBAction) doSharingConfigure:(id)sender;
{
	NSString *appleScriptString = @"tell application \"System Preferences\"\nactivate\nset current pane to pane \"com.apple.preferences.sharing\"\nend tell";
	NSAppleScript *script = [[[NSAppleScript alloc] initWithSource:appleScriptString] autorelease];
	NSDictionary *errorDict = nil;
	(void) [script executeAndReturnError:&errorDict];
}

- (IBAction) doGetDotMacAccount:(id)sender
{
	[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:[NSURL URLWithString:@"http://www.apple.com/mobileme/"]];		// this is our link URL
}



- (IBAction) doVerifyHomePageURL:(id)sender
{
	if ([[self properties] valueForKey:@"homePageURL"] != nil)
	{
		NSURL *url = [NSURL URLWithUnescapedString:[[self properties] valueForKey:@"homePageURL"]];	// BETA: This used to be in a @try block. Are certain URL strings failing?
		
		if (url) {
			[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:url];
		}
		else
		{
			NSBeep();
		}
	}
}

- (IBAction) doVerifySetupURL:(id)sender
{
	if ([[self properties] valueForKey:@"setupURL"] != nil)
	{
		NSURL *url = [NSURL URLWithUnescapedString:[[self properties] valueForKey:@"setupURL"]];		// BETA: This used to be in a @try block. Are certain URL strings failing?
		
		if (url != nil) {
			[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:url];
		}
		else
		{
			NSBeep();
		}
	}
}

#pragma mark -
#pragma mark Test Connection

- (void)startTestConnection:(id)bogus
{
	LOG((@"start test connection"));
	myDidSuccessfullyDownloadTestFile = NO;
	myHasProcessedDidChangeToDirectory = NO;
	[self setConnectionStatus:@""];
	[self setConnectionProgress:@""];

	[self setConnectionData:[NSMutableData data]];	// HACK to start the progress indicator!
		
	id <CKConnection> connection = [[CKConnectionRegistry sharedConnectionRegistry] connectionWithName:[[self properties] valueForKey:@"protocol"]
                                                                                                  host:[[self properties] valueForKey:@"hostName"]
                                                                                                  port:[[self properties] valueForKey:@"port"]];
	OBASSERT(connection);
    if (!connection) return;
    
	[connection setName:@"Host Setup Test"];
	[self setTestConnection:connection];
	[connection setDelegate:self];
	[self appendConnectionProgressLine:YES format:NSLocalizedString(@"Contacting %@... ", "status message for test connection"), [[self properties] valueForKey:@"hostName"]];

	// Delay calling this so that we see the above message before the actual connect method is called, since this takes a moment in the foreground.
	[self performSelector:@selector(actuallyConnect:) withObject:nil afterDelay:0.0];
}

- (void)actuallyConnect:(id)bogus
{
	[self appendConnectionProgressLine:YES format:NSLocalizedString(@"Establishing %@ connection... ", "status message for test connection"), [KSUtilities displayNameForProtocol:[[self properties] valueForKey:@"protocol"]]];

//	NSLog(@"Queuing timeout test from actuallyConnect");
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(timeoutTest:) object:nil];
	[self performSelector:@selector(timeoutTest:) withObject:nil afterDelay:[self connectionTimeoutValue]];
	[myTestConnection connect];
}


/*  Authenticate the connection from the user's entered credentials. If this fails, end the test.
 */
- (void)connection:(id <CKConnection>)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    if ([challenge previousFailureCount] == 0)
	{
		[self handleAuthenticationChallenge:challenge];
	}
	else
	{
		[[challenge sender] cancelAuthenticationChallenge:challenge];
		
		[self disconnectConnection];
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(timeoutTest:) object:nil];
		NSLog(@"= %@", NSStringFromSelector(_cmd));
		
		[self appendConnectionProgressLine:YES format:NSLocalizedString(@"Password was not accepted.", @"status message for test connection")];
		[self setConnectionStatusColor:[NSColor redColor]];
		[self setConnectionStatus:NSLocalizedString(@"Unable to connect; the password was not accepted for your account. Please go back and review your account information.", @"status message for test connection")];
	}
}


// TODO: Remove this method
- (BOOL)connection:(id <CKConnection>)con authorizeConnectionToHost:(NSString *)host message:(NSString *)message
{
	if (NSRunAlertPanel(NSLocalizedString(@"Authorize Connection?", "connection delegate"), 
						message, 
						NSLocalizedString(@"Yes", "Yes Button"),
						NSLocalizedString(@"No", "No Button"),
						nil) == NSOKButton) {
		return YES;
	}
	return NO;
}

// Support method to now upload the test file
- (void)uploadTestFileAtPath:(NSString *)dirPath
{
	[self appendConnectionProgressLine:YES format:NSLocalizedString(@"Attempting to upload a test file... ", @"status message for test connection")];
	
	[myRemotePath autorelease];
	myRemotePath = [dirPath copy];
	// Upload file ... same as in connection:didConnectToHost:
	NSString *remoteFile = [myRemotePath stringByAppendingPathComponent:[[self testFileUploadPath] lastPathComponent]];
	[myTestConnection uploadFile:myTemporaryTestFilePath toFile:remoteFile];
	
	if ( [[[NSUserDefaults standardUserDefaults] objectForKey:@"ConnectionSetsPermissions"] boolValue] )
	{
		[myTestConnection setPermissions:0644 forFile:remoteFile];
	}
	
	LOG((remoteFile));
	
	//		NSLog(@"Queuing timeout test before upload, from didChangeToDir");
	[self performSelector:@selector(timeoutTest:) withObject:nil afterDelay:[self connectionTimeoutValue]];
}

/*!	We've connected.  Now try to create and upload a test file.
*/
- (void)connection:(id <CKConnection>)con didConnectToHost:(NSString *)host error:(NSError *)error;
{
//	NSLog(@"Cancelling timeout test, didConnectToHost");
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(timeoutTest:) object:nil];
	NSLog(@"= %@%@", NSStringFromSelector(_cmd), host);
	[self appendConnectionProgressLine:NO format:NSLocalizedString(@"Server reached.", "status message for test connection")];

	BOOL success = [self createTestFileInDirectory:NSTemporaryDirectory()];	// this saves path in myTemporaryTestFilePath

	if (success)
	{
		NSString *subFolder = [[self properties] valueForKey:@"subFolder"];
		//we need to make sure all paths are created here including the docRoot
		NSString *path = [[self properties] valueForKey:@"docRoot"];
		if (subFolder  && ![subFolder isEqualToString:@""])
		{
			path = [path stringByAppendingPathComponent:subFolder];
		}
				
		if (	(path && ![path isEqualToString:@""])
				||	(subFolder  && ![subFolder isEqualToString:@""]) )
		{
			[self appendConnectionProgressLine:YES format:NSLocalizedString(@"Creating Directories... ", "status message for test connection")];
			[self performSelector:@selector(timeoutTest:) withObject:nil afterDelay:[self connectionTimeoutValue]];

			NSArray *pathComponents = [path pathComponents];	///[path componentsSeparatedByString:@"/"];
			NSString *builtupPath = @"";
			NSEnumerator *pathEnum = [pathComponents objectEnumerator];
			NSString *curPath;
			
			while (curPath = [pathEnum nextObject]) {
				//[builtupPath appendFormat:@"%@/", curPath];	/// Old way that resulted in an erroneous trailing slash
				builtupPath = [builtupPath stringByAppendingPathComponent:curPath];
				LOG((@"Creating Directory: %@", builtupPath));
				[myTestConnection createDirectory:[NSString stringWithString:builtupPath]]; //we don't want to go messing with permissions if someone specifies an absolute path liek /User/ghulands/Sites/
			}
			if ( [[[NSUserDefaults standardUserDefaults] objectForKey:@"ConnectionSetsPermissions"] boolValue] )
			{
				[myTestConnection setPermissions:0755 forFile:path];
			}
			LOG((@"Changing to %@", builtupPath));
			[myTestConnection changeToDirectory:builtupPath];
		}
		else
		{
			LOG((@"No SubFolder, going to upload test file directly"));
			[self uploadTestFileAtPath:@""];
		}
	}
	else
	{
		[self appendConnectionProgressLine:YES format:NSLocalizedString(@"Unable to create test file %@", "status message for test connection"), myTemporaryTestFilePath];
		[self setConnectionStatusColor:[NSColor redColor]];
		[self setConnectionStatus:NSLocalizedString(@"Sandvox is unable to write a test file into your computer\\U2019s temporary directory.", "status message for test connection")];
		[self disconnectConnection];
	}
}

/*	Called when the current directory changes.
 *	This can be when first connecting, or after a manual dir change.
 */
- (void)connection:(id <CKConnection>)con didChangeToDirectory:(NSString *)dirPath error:(NSError *)error
{
	LOG((@"= %@%@", NSStringFromSelector(_cmd), dirPath));
	
	// Compare the current directory with the upload one specified by the user.
	// If they match, upload the test file.
	// (We only test the last path component as it could be a symlink)
	
	NSString *path = [self subFolderPath];
	if (!myHasProcessedDidChangeToDirectory && [[dirPath lastPathComponent] isEqualToString:[path lastPathComponent]])
	{
		myHasProcessedDidChangeToDirectory = YES;	// only let us get this callback once.
		// Only process if this is callback from changing to our subdir.
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(timeoutTest:) object:nil];
		
		[self appendConnectionProgressLine:NO format:NSLocalizedString(@"Done.", @"status message for test connection")];
		[self uploadTestFileAtPath:([dirPath isAbsolutePath] ? dirPath : @"")];
	}
}

/*!	We've uploaded.  Now try to download.
*/
- (void)connection:(id <CKConnection>)con uploadDidFinish:(NSString *)remotePath error:(NSError *)error
{
//	NSLog(@"Cancelling timeout test, uploadDidFinish");
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(timeoutTest:) object:nil];

	NSLog(@"= %@%@", NSStringFromSelector(_cmd), remotePath);

	NSString *fullURLString = [self testFileRemoteURL];
	NSLog(@"remote URL = %@", fullURLString);
	NSURLRequest *theRequest
		=	[NSURLRequest requestWithURL:[NSURL URLWithUnescapedString:fullURLString]
							 cachePolicy:NSURLRequestReloadIgnoringCacheData
						 timeoutInterval:20.0];
	// create the connection with the request and start loading the data
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
	NSURLConnection *theConnection=[NSURLConnection connectionWithRequest:theRequest delegate:self];
	if (theConnection)
	{
		[self appendConnectionProgressLine:NO format:NSLocalizedString(@"Done.", @"status message for test connection")];
		[self appendConnectionProgressLine:YES format:NSLocalizedString(@"Attempting to download the test file... ", @"status message for test connection")];

		[self setDownloadTestConnection:theConnection];
		// Create the NSMutableData that will hold the received data
		[self setConnectionData:[NSMutableData data]];

	} else {
		// inform the user that the download could not be made
		[self appendConnectionProgressLine:NO format:NSLocalizedString(@"Done.", @"status message for test connection")];
		[self appendConnectionProgressLine:YES format:NSLocalizedString(@"Unable to establish connection to URL: %@", @"status message for test connection"), fullURLString];
		[self setConnectionStatusColor:[NSColor redColor]];
		[self setConnectionStatus:NSLocalizedString(@"Unable to establish a HTTP connection to the server. You may have your host's URL Format misconfigured.", @"status message for test connection")];
		[self disconnectConnection];
	}
}

/*!	Now we should get this method called (via the connectionDidFinishLoading: callback).  We then delete the file from the server.
*/

- (void) testConnectionDidFinishLoading
{
	NSLog(@"= %@", NSStringFromSelector(_cmd));
	[self appendConnectionProgressLine:NO format:NSLocalizedString(@"Done.", @"status message for test connection")];
	[self appendConnectionProgressLine:YES format:NSLocalizedString(@"Attempting to delete the test file... ", @"status message for test connection")];

//	NSLog(@"Queuing timeout test from testConnectionDidFinishLoading");
	[self performSelector:@selector(timeoutTest:) withObject:nil afterDelay:[self connectionTimeoutValue]];
	NSString *file = [myRemotePath stringByAppendingPathComponent:[[self testFileUploadPath] lastPathComponent]];
	[myTestConnection deleteFile:file];
}

/*!	File was deleted.  We have passed the test.  Now save this marker, also maybe upload host info to our server.
*/
- (void)connection:(id <CKConnection>)con didDeleteFile:(NSString *)path error:(NSError *)error
{
//	NSLog(@"Cancelling timeout test, didDeleteFile");
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(timeoutTest:) object:nil];

	NSLog(@"= %@%@", NSStringFromSelector(_cmd), path);
	[self appendConnectionProgressLine:NO format:NSLocalizedString(@"Done.", @"status message for test connection")];

	[self appendConnectionProgressLine:YES format:NSLocalizedString(@"Disconnecting... ", @"status message for test connection")];
	[myTestConnection disconnect];

	[self setValue:[self uploadURL] forKey:@"passedUploadURL"];
}

- (void)disconnectConnection
{
	LOG((@"DISCONNECTING"));
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(timeoutTest:) object:nil];
	[myTestConnection setDelegate:nil];
	[myTestConnection cancelAll];
	[myTestConnection forceDisconnect];
	[myTestConnection release];
	myTestConnection = nil;
	[oNextButton setEnabled:YES];
	[self setConnectionData:nil];	// HACK to stop the progress indicator!		
}

//
//
// FAILURE HANDLERS
//
//
- (void) testConnectionDidFailWithError:(NSError *)error
{
	NSString *fullURLString = [self testFileRemoteURL];
	
	NSLog(@"Download Test Error: %@", error);

	[self appendConnectionProgressLine:YES format:NSLocalizedString(@"Unable to download file from URL: %@", @"status message for test connection"), fullURLString];
	[self appendConnectionProgressLine:YES format:NSLocalizedString(@"Received the error message: %@", @"status message for test connection"), [error localizedDescription]];
	[self setConnectionStatusColor:[NSColor redColor]];
	[self setConnectionStatus:NSLocalizedString(@"Unable to download the test file from the server. You may have your host's URL Format misconfigured.", @"status message for test connection")];
}

- (void)connection:(id <CKConnection>)con didReceiveError:(NSError *)error
{
//	NSLog(@"Cancelling timeout test, didReceiveError");
	LOG((@"= %@%@", NSStringFromSelector(_cmd), error));
	
	if ([[error userInfo] objectForKey:ConnectionDirectoryExistsKey]) {
		return; //don't alert users to the fact it already exists, silently fail
	}
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(timeoutTest:) object:nil];
	
	if ([error code] == 550 || [[[error userInfo] objectForKey:@"protocol"] isEqualToString:@"createDirectory:"] )
	{
		// Next step, almost the same as connection:didCreateDirectory:
		[self appendConnectionProgressLine:NO format:NSLocalizedString(@"Failed.", @"status message for test connection")];
		//[self appendConnectionProgressLine:YES format:NSLocalizedString(@"Attempting to change to directory... ", @"status message for test connection")];
		// Directory created; now change to the directory

		//we need to kill the test here and now
		[self disconnectConnection];
	}
	else if ([con isKindOfClass:NSClassFromString(@"WebDAVConnection")] && 
			 [[[error userInfo] objectForKey:@"directory"] isEqualToString:@"/"])
	{
		// web dav returns a 404 if we try to create / .... which is fair enough!
		return;
	}
	else
	{
		[self appendConnectionProgressLine:NO format:NSLocalizedString(@"Failed", @"status message for test connection")];
		[self appendConnectionProgressLine:YES format:NSLocalizedString(@"Received the error message: %@", @"status message for test connection"), [error localizedDescription]];
		[self setConnectionStatusColor:[NSColor redColor]];
		[self setConnectionStatus:NSLocalizedString(@"Errors encountered, test failed. Please go back and check your settings.", @"status message for test connection")];
		//we need to kill the test here and now
		[self disconnectConnection];
	}
}

/*!	We've disconnected.  No need for action here.
*/
- (void)connection:(id <CKConnection>)con didDisconnectFromHost:(NSString *)host
{
	NSLog(@"= %@%@", NSStringFromSelector(_cmd), host);
	if (myDidSuccessfullyDownloadTestFile)
	{
		[self setConnectionStatusColor:[NSColor colorWithDeviceRed:0.0 green:0.5 blue:0.0 alpha:1.0]];
		[self setConnectionStatus:NSLocalizedString(@"Connectivity test passed!", @"status message for test connection")];
		[self appendConnectionProgressLine:NO format:NSLocalizedString(@"Done.", @"status message for test connection")];
	}
	else	// we disconnected before we expected to
	{
		[self appendConnectionProgressLine:NO format:NSLocalizedString(@"Failed", @"status message for test connection")];
		[self setConnectionStatusColor:[NSColor redColor]];
		[self setConnectionStatus:NSLocalizedString(@"Errors encountered, test failed. Please go back and check your settings.", @"status message for test connection")];
	}
	[self disconnectConnection];
}

// Allow the timeout value to come from NSUserDefaults as some peoples connections could be slow
- (NSTimeInterval)connectionTimeoutValue
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	return [defaults floatForKey:KTHostConnectionTimeoutValueKey];
}

// Called after delay to give up on where we are going.

- (void) timeoutTest:(id)unused
{
	NSLog(@"= %@", NSStringFromSelector(_cmd));

	[self appendConnectionProgressLine:YES format:NSLocalizedString(@"Operation timed out.", @"status message for test connection")];
	[self setConnectionStatusColor:[NSColor redColor]];
	[self setConnectionStatus:NSLocalizedString(@"Timed out, unable to complete tests.", @"status message for test connection")];
	[self disconnectConnection];
}

- (void)connection:(id <CKConnection>)connection appendString:(NSString *)string toTranscript:(CKTranscriptType)transcript
{
	string = [string stringByAppendingString:@"\n"];
	NSAttributedString *attributedString = [[connection class] attributedStringForString:string transcript:transcript];
	[[[KTTranscriptController sharedControllerWithoutLoading] textStorage] appendAttributedString:attributedString];
}

- (void)connectionOpenPanel:(CKConnectionOpenPanel *)panel appendString:(NSString *)string toTranscript:(CKTranscriptType)transcript
{
	string = [string stringByAppendingString:@"\n"];
	NSAttributedString *attributedString = [CKAbstractConnection attributedStringForString:string transcript:transcript];
	[[[KTTranscriptController sharedControllerWithoutLoading] textStorage] appendAttributedString:attributedString];
}

#pragma mark -
#pragma mark Derived Accessors

- (NSString *)localURL
{
	return [[self properties] localURL];
}

- (NSString *)globalBaseURLUsingHome:(BOOL)inHome  allowNull:(BOOL)allowNull;
{
	return [[self properties] globalBaseURLUsingHome:inHome  allowNull:allowNull];
}

- (NSString *)globalSiteURL
{
	return [[self properties] globalSiteURL];
}

- (BOOL)remoteSiteURLIsValid
{
	return [[self properties] remoteSiteURLIsValid];
}

- (NSString *)remoteSiteURL		// e.g. http://foobar.com/~dwood/MySandvoxSite/
{
	return [[self properties] remoteSiteURL];
}


- (NSString *)uploadURL
{
	return [[self properties] uploadURL];
}


/*!	Calculate path of uploaded test file.
*/
- (NSString *)testFileUploadPath
{
	NSString *result = @"";
	NSString *docRoot = [[self properties] valueForKey:@"docRoot"];
	if (nil != docRoot)
	{
		// replace ? with user name
		NSMutableString *mutableDocRoot = [NSMutableString stringWithString:docRoot];
		NSString *userName = [[self properties] valueForKey:@"userName"];
		if (nil != userName)
		{
			[mutableDocRoot replaceOccurrencesOfString:@"?" withString:userName options:0 range:NSMakeRange(0, [docRoot length])];
		}
		result = mutableDocRoot;
	}
	NSString *subFolder = [[self properties] valueForKey:@"subFolder"];
	if (nil != subFolder && ![subFolder isEqualToString:@""])
	{
		result = [result stringByAppendingPathComponent:subFolder];
	}
	NSString *fileName = [myTemporaryTestFilePath lastPathComponent];
	result = [result stringByAppendingPathComponent:fileName];

	return result;
}

/*!	SubFolder and file uploaded
*/
- (NSString *)testFileRemoteURL
{
	NSString *result = [self remoteSiteURL];
	NSString *fileName = [myTemporaryTestFilePath lastPathComponent];
	if (![result hasSuffix:@"/"])
	{
		result = [result stringByAppendingString:@"/"];
	}
	result = [result stringByAppendingString:fileName];

	return result;
}

/*!	return subfolder with docRoot prepended
*/
- (NSString *)subFolderPath
{
	NSString *subFolder = [[self properties] valueForKey:@"subFolder"];
	if (nil != subFolder  && [subFolder length] > 0)
	{
		NSString *docRoot = [[self properties] valueForKey:@"docRoot"];
		if (nil != docRoot)
		{
			// replace ? with user name
			NSMutableString *mutableDocRoot = [NSMutableString stringWithString:docRoot];
			NSString *userName = [[self properties] valueForKey:@"userName"];

			if (nil != userName)
			{
				[mutableDocRoot replaceOccurrencesOfString:@"?" withString:userName options:0 range:NSMakeRange(0, [docRoot length])];
			}
			subFolder = [mutableDocRoot stringByAppendingPathComponent:subFolder];
		}
	}
	else
	{
		//if no subFolder we return the doc root
		subFolder = [[self properties] valueForKey:@"docRoot"];
	}
	return subFolder;
}

- (BOOL)showSFTPMessage
{
	return [[[self properties] valueForKey:@"protocol"] isEqualToString:@"SFTP"];
}


#pragma mark -
#pragma mark Constant Accessors

//
//
// TODO: when we reorganize the HSA -- right now we are binding to these to get the images.  Instead, we should
// have some methods to return the NSImage, and bind to that.  That way, we can get the proper
// icon images (see our -[NSImage imageFromOSType:] and not be returning paths, which is not really
// the supported way to do this.
//


- (NSString *) serverImagePath
{
	// We have our own copy of the "globe in a cube" becuase this changed to a hard disk kind of icon in Leopard.  Not what we wanted.
	// I think we just have to have our own copy of this.
	
	return [[NSBundle mainBundle] pathForImageResource:@"GenericFileServerIcon.icns"];	// kGenericFileServerIcon
}

- (NSString *) sharingImagePath
{
	return @"/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/PublicFolderIcon.icns";	// kPublicFolderIcon
}
- (NSString *) iDiskImagePath
{
	if (floor(NSAppKitVersionNumber) <= 824)		// Tiger
	{
		return @"/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/iDiskGenericIcon.icns";
	}
	else
	{
		return @"/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/dotMacLogo.icns";		// becomes 'macn' or 'idsk' (or 'mymc', Leopard-only?) -- not sure which 
	}
}
- (NSString *) iMacImagePath
{
	// INSTEAD, WE SHOULD BE USING SOME OF THE NEW SERVICES IN LEOPARD (AND A FALLBACK IN TIGER) FOR *THIS* COMPUTER.
	// Leopoard method is -[NSImage imageNamed:NSImageNameComputer]
	return @"/System/Library/PrivateFrameworks/SyncServicesUI.framework/Versions/A/Resources/Computer.tif";
}
- (NSString *) homeImagePath
{
	return @"/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/HomeFolderIcon.icns";	// kToolbarHomeIcon
}

- (NSString *) folderPath
{
	return @"/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericFolderIcon.icns";	// kGenericFolderIcon
}

- (NSString *) cautionPath
{
	return @"/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertCautionIcon.icns";	// kAlertCautionIcon
}

#pragma mark -
#pragma mark Accessors

// these two are temporary to make it "Or"

- (void)setLocalHosting:(id)val
{
	[[self properties] setValue:val forKey:@"localHosting"];
	if ([val intValue])
	{
		[self setValue:[NSNumber numberWithInt:0] forKey:@"remoteHosting"];
	}
}

- (void)setRemoteHosting:(id)val
{
	[[self properties] setValue:val forKey:@"remoteHosting"];
	if ([val intValue])
	{
		[self setValue:[NSNumber numberWithInt:0] forKey:@"localHosting"];
	}
}


- (NSString *)connectionProgress
{
    return myConnectionProgress;
}
- (void)setConnectionProgress:(NSString *)aConnectionProgress
{
    [aConnectionProgress retain];
    [myConnectionProgress release];
    myConnectionProgress = aConnectionProgress;
}


- (NSString *)connectionStatus
{
    return myConnectionStatus;
}
- (void)setConnectionStatus:(NSString *)aConnectionStatus
{
    [aConnectionStatus retain];
    [myConnectionStatus release];
    myConnectionStatus = aConnectionStatus;
}


- (int)testState
{
    return myTestState;
}
- (void)setTestState:(int)aTestState
{
    myTestState = aTestState;
}

- (CKAbstractConnection *)testConnection
{
    return myTestConnection;
}
- (void)setTestConnection:(CKAbstractConnection *)aTestConnection
{
    [aTestConnection retain];
    [myTestConnection autorelease];			// let test connection finish its business
    myTestConnection = aTestConnection;
}


- (BOOL)wantsNextWhenDoneLoading
{
    return myWantsNextWhenDoneLoading;
}
- (void)setWantsNextWhenDoneLoading:(BOOL)flag
{
    myWantsNextWhenDoneLoading = flag;
}

- (NSString *)temporaryTestFilePath
{
    return myTemporaryTestFilePath;
}
- (void)setTemporaryTestFilePath:(NSString *)aTemporaryTestFilePath
{
	// Before deleting path, delete the file too.
	if (nil != myTemporaryTestFilePath)
	{
		NSFileManager *fm = [NSFileManager defaultManager];
		(void) [fm removeFileAtPath:myTemporaryTestFilePath handler:nil];
	}

    [aTemporaryTestFilePath retain];
    [myTemporaryTestFilePath release];
    myTemporaryTestFilePath = aTemporaryTestFilePath;
}

- (NSMutableData *)connectionData
{
    return myConnectionData;
}
- (void)setConnectionData:(NSMutableData *)aConnectionData
{
    [aConnectionData retain];
    [myConnectionData release];
    myConnectionData = aConnectionData;
}


- (NSMutableData *)ISPConnectionData
{
    return myISPConnectionData; 
}

- (void)setISPConnectionData:(NSMutableData *)anISPConnectionData
{
    [anISPConnectionData retain];
    [myISPConnectionData release];
    myISPConnectionData = anISPConnectionData;
}

- (NSURLConnection *)downloadTestConnection
{
    return myDownloadTestConnection;
}
- (void)setDownloadTestConnection:(NSURLConnection *)aDownloadTestConnection
{
    [aDownloadTestConnection retain];
    [myDownloadTestConnection release];
    myDownloadTestConnection = aDownloadTestConnection;
}

- (NSURLConnection *)reachableConnection
{
    return myReachableConnection;
}
- (void)setReachableConnection:(NSURLConnection *)aReachableConnection
{
    [aReachableConnection retain];
    [myReachableConnection release];
    myReachableConnection = aReachableConnection;
}


- (int)localHostVerifiedStatus
{
    return myLocalHostVerifiedStatus;
}
- (void)setLocalHostVerifiedStatus:(int)aLocalHostVerifiedStatus
{
    myLocalHostVerifiedStatus = aLocalHostVerifiedStatus;
}

- (NSString *)defaultISP
{
    return myDefaultISP;
}
- (void)setDefaultISP:(NSString *)aDefaultISP
{
    [aDefaultISP retain];
    [myDefaultISP release];
    myDefaultISP = aDefaultISP;
}

- (NSString *)password
{
	if (!myPassword || [myPassword length] == 0)
	{
		myPassword = [[self passwordFromKeychain] copy];
		if (myPassword)
		{
			[oPasswordField setStringValue:myPassword];
		}
	}
    return myPassword;
}

- (void)setPassword:(NSString *)aPassword
{
    [aPassword retain];
    [myPassword release];
    myPassword = aPassword;
}

- (NSTimer *)apacheTimer
{
    return myApacheTimer;
}
- (void)setApacheTimer:(NSTimer *)anApacheTimer
{
	[myApacheTimer invalidate];
    [myApacheTimer release];
    myApacheTimer = [anApacheTimer retain];
}


- (NSTimer *)dotMacTimer
{
    return myDotMacTimer;
}
- (void)setDotMacTimer:(NSTimer *)aDotMacTimer
{
	[myDotMacTimer invalidate];
    [myDotMacTimer release];
    myDotMacTimer = [aDotMacTimer retain];
}

- (NSMutableDictionary *)originalProperties
{
    return myOriginalProperties;
}
- (void)setOriginalProperties:(NSMutableDictionary *)anOriginalProperties
{
    [anOriginalProperties retain];
    [myOriginalProperties release];
    myOriginalProperties = anOriginalProperties;
}

- (KTHostProperties *)properties
{
    return myProperties;
}

- (void)setProperties:(KTHostProperties *)aProperties
{
	[self setOriginalProperties:[NSMutableDictionary dictionaryWithDictionary:[aProperties currentValues]]];
	
	[aProperties retain];
	[myProperties release];
	myProperties = aProperties;
}

- (NSMutableArray *)trail
{
    return myTrail;
}

- (void)setTrail:(NSMutableArray *)aTrail
{
    [aTrail retain];
    [myTrail release];
    myTrail = aTrail;
}

- (NSColor *)connectionStatusColor
{
    return myConnectionStatusColor;
}
- (void)setConnectionStatusColor:(NSColor *)aConnectionStatusColor
{
    [aConnectionStatusColor retain];
    [myConnectionStatusColor release];
    myConnectionStatusColor = aConnectionStatusColor;
}

- (NSString *)currentState
{
    return myCurrentState;
}

/*!	Set the new state.  Update the UI.  If we're at account, load the password from the keychain.
*/

- (void)setCurrentState:(NSString *)aCurrentState
{
	[oTabView selectTabViewItemWithIdentifier:aCurrentState];
	/// defend against nil
	NSString *string = [[oTabView selectedTabViewItem] label];
	if (nil == string) string = @"";
	[oStepLabel setStringValue:string];

	[oPreviousButton highlight:NO];		// be sure it's not highlighted when revealed
	[oPreviousButton setHidden:/*setTransparent:*/(0 == [myTrail count])];	// instead of setHidden so we don't get exception when clicking on button that gets hidden
	[oPreviousButton setEnabled:YES];
	[oNextButton setEnabled:YES];

	// Set up Continue button based on where we are

	if ([aCurrentState isEqualToString:@"where"])
	{
		[oHostTypeMatrix selectCellWithTag:[[[self properties] valueForKey:@"hostTypeMatrix"] intValue]];
	}
	
	if ([aCurrentState isEqualToString:@"summary"])
	{
		[self updateSummaryString];
		[oNextButton setTitle:NSLocalizedString(@"Done", @"Done Button in setup host")];
		[oNextButton setAction:@selector(doOK:)];
	}
	else if ([aCurrentState isEqualToString:@"introduction"])
	{
		[self updateSummaryString];
		[oNextButton setTitle:NSLocalizedString(@"Edit", @"Button in setup host to start the editing process")];
		[oNextButton setAction:@selector(doNext:)];
	}
	else
	{
		[oNextButton setTitle:NSLocalizedString(@"Continue", @"Button in setup host to go to next dialog")];
		[oNextButton setAction:@selector(doNext:)];
	}

	// Special: If account, get the password in a moment so we see keychain request AFTER seeing this pane open
	if ([aCurrentState isEqualToString:@"host"])
	{
		// Read in the account password, make sure we get the request AFTER seeing what it's for.
		if (!myPassword || [myPassword length] == 0)	// don't call password accessor, that will actually load it now!
		{
			BOOL isSFTPWithPublicKey = [[[self properties] valueForKey:@"protocol"] isEqualToString:@"SFTP"] && [[[self properties] valueForKey:@"usePublicKey"] intValue] == NSOnState;
			if (!isSFTPWithPublicKey)
			{
				[self performSelector:@selector(loadPasswordFromKeychain:) withObject:nil afterDelay:0.05];
			}
		}
	}

	// Special: If we are at the .Mac panel, start checking for changes in the .Mac status
	if ([aCurrentState isEqualToString:@"mac"])
	{
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		
		// Put .Mac-specific properties into general properties
		NSDictionary *ispInfo = [NSDictionary dictionaryWithObjectsAndKeys:
			@"mac.com", @"domainName",
			@"http://www.mac.com/", @"homePageURL",
			@"idisk.mac.com", @"hostName",
			@"webDAV", @"protocol",
			nil];
				
		[[self properties] setValuesForKeysWithDictionary:ispInfo];
		[self setValuesForKeysWithDictionary:ispInfo];
		// Now start checking for any changes in the .Mac name
		[defaults synchronize];	// since we'll be resetting .. just to be safe
		[self updateDotMacStatus:nil];	// make sure it's showing correct .Mac stuff immediately
		NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0 
														  target:self 
														selector:@selector(updateDotMacStatus:) 
														userInfo:nil 
														 repeats:YES];
		[self setDotMacTimer:timer];
		[self setValue:@".Mac" forKey:@"protocol"];
	}
	else
	{
		[self setDotMacTimer:nil];
	}

	// Special: If we are at the Apache panel, start checking for changes in the .Mac status
	if ([aCurrentState isEqualToString:@"apache"])
	{
		// Now start checking for any changes in Apache
		myWasApacheRunning = 99;	// start out in undefined state
		[self updateApacheStatus:nil];	// make sure it's showing correct Apache stuff immediately
		NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateApacheStatus:) userInfo:nil repeats:YES];
		[self setApacheTimer:timer];
	}
	else
	{
		[self setApacheTimer:nil];
	}

	if ([aCurrentState isEqualToString:@"test"])
	{
		[self setConnectionStatus:@""];
		[self setConnectionProgress:@""];
		// immediately clear out status, but wait a moment to start the connection
		// until the UI has caught up, and to show the "movement" to the user

		if ([self remoteSiteURLIsValid])
		{
			[self performSelector:@selector(startTestConnection:) withObject:nil afterDelay:0.1];
		}
		else
		{
			NSLog(@"should not test; we don't have a remote URL");
		}
		// delay this until next cycle so UI is refreshed.
	}
	
	if (NO) {	// If we don't want a background
		[oTabView setBorderColor:[NSColor clearColor]];
		[oTabView setBackgroundColor:[NSColor clearColor]];
	} else {
		[oTabView setBackgroundColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.7]];
		[oTabView setBorderColor:[NSColor colorWithCalibratedWhite:0.3 alpha:1.0]];
	}
	
	// Now do the usual storing stuff
	[self willChangeValueForKey:@"currentState"];
    [aCurrentState retain];
    [myCurrentState release];
    myCurrentState = aCurrentState;
	[self didChangeValueForKey:@"currentState"];
}

- (void)setUsePublicKey:(id)val
{
	if ([val intValue] == NSOnState)
	{
		[myPassword autorelease];
		myPassword = nil;
		[oPasswordField setStringValue:@""];
	}
	[[self properties] setValue:val forKey:@"usePublicKey"];
	//[self setValue:val forKey:@"usePublicKey"]; // this causes a recursive crash ggh
}

- (void)setEnabledPassword:(BOOL)val
{
	
}

- (BOOL)enablePassword
{
	if ([[[self properties] valueForKey:@"protocol"] isEqualToString:@"SFTP"])
	{
		if ([[[self properties] valueForKey:@"usePublicKey"] boolValue])
		{
			return NO;
		}
		else
		{
			return YES;
		}
	}
	else
	{
		return YES;
	}
}

- (BOOL)canCreateNewConfiguration
{
	return ([[self valueForKey:@"isEditing"] boolValue] == YES && [[self currentState] isEqualToString:@"introduction"]);
}

- (void)setCanCreateNewConfiguration:(BOOL)flag
{
	//do nothing
}

#pragma mark -
#pragma mark Validation

/*!	General validation.  Used to validate a bunch of different strings.
*/
- (BOOL)validateValue:(id *)ioValue forKey:(NSString *)key error:(NSError **)outError
{
	NSString *leftDoubleQuote = NSLocalizedString(@"\\U201C", "left double quote");
	NSString *rightDoubleQuote = NSLocalizedString(@"\\U201D", "right double quote");

    if (ioValue == nil || *ioValue == nil)
	{
        return YES;
    }
    else if (![*ioValue isKindOfClass:[NSString class]])
	{
		NSString *errorString
			= NSLocalizedString(@"Value is not a string", @"validation error message for unexpected non-string");
        NSDictionary *userInfoDict =
			[NSDictionary dictionaryWithObject:errorString
										forKey:NSLocalizedDescriptionKey];
        NSError *error = [[[NSError alloc] initWithDomain:kKTHostSetupErrorDomain
													 code:1
												 userInfo:userInfoDict] autorelease];
		if (outError)
		{
			*outError = error;
		}
		return NO;
	}

	BOOL result = YES;	// unless we trap an error, assume it's OK
	NSString *newValue = [[*ioValue copy] autorelease];	// this will be modified
	NSString *errorString = nil;	// must fill in with a nice message for the user

	// URL
	if ([sUrlKeySet containsObject:key])
	{
		newValue = [newValue trim];
		newValue = [newValue stringWithValidURLScheme];
		NSString *testURL = newValue;
		// special case: with stemURL, we temporarily convert "?" into "userid" to make it seem valid
		if ([key isEqualToString:@"stemURL"])
		{
			// Fix stemURL to have suffix / if it's missing
			if (![testURL hasSuffix:@"/"])
			{
				newValue = [testURL stringByAppendingString:@"/"];
				testURL = newValue;
			}
			NSMutableString *newString = [NSMutableString stringWithString:testURL];
			[newString replaceOccurrencesOfString:@"?" withString:@"userID" options:0 range:NSMakeRange(0, [newString length])];
			testURL = newString;		// use this instead for the test
		}
		NSURL *url = [NSURL URLWithUnescapedString:testURL];

		errorString
			= NSLocalizedString(@"Illegal characters found in URL. A URL must look something like http://www.domain.com/path/", @"validation error message for illegal URL");
		result = (url != nil);

		// THIS IS ONLY WORKABLE IF WE DON'T UPDATE VALUE CONTINUOUSLY AS USER TYPES!

		if (result)
		{
			// more vigorous testing:
			result = ([[url host] looksLikeValidHost]);

			errorString
				= [NSString stringWithFormat:NSLocalizedString(@"This does not appear to be a valid Web URL. %@%@%@ does not appear to be a valid hostname.", "validation error message for invalid web hostname"), leftDoubleQuote, [url host], rightDoubleQuote];;
		}
	}

	// Subfolder
	else if ([sSubFolderSet containsObject:key])
	{
		// Remove leading and trailing / and whitespace
		newValue = [newValue stringByTrimmingCharactersInSet:sWhitespaceAndSlashSet];

		// Convert empty string to nil, in case we got rid of everything
		if (0 == [((NSString *)newValue) length])
		{
			newValue = nil;
		}
		errorString
			= NSLocalizedString(@"Illegal characters were found in the folder name.  Please limit the folder name to letters, numbers, dashes, and underscores.", @"validation error message for illegal subfolder");

		NSRange whereBad
			= [newValue rangeOfCharacterFromSet:sIllegalSubfolderSet];
		result = (NSNotFound == whereBad.location);
	}

	// Hostname
	else if ([sHostNameSet containsObject:key])
	{
		newValue = [newValue stringByTrimmingFirstLine];

		// Now for a more vigorous check
		result = ([newValue looksLikeValidHost]);
		//try to get a NSHost
		if (!result)
		{
			NSString *resolver = [[NSUserDefaults standardUserDefaults] objectForKey:@"hostResolver"];
			NSHost *host = [NSClassFromString(resolver) hostWithAddress:newValue];
			if (host && [host address])
			{
				result = YES;
			}
		}

		errorString
			= NSLocalizedString(@"This does not appear to be a valid hostname. A hostname consists of server name(s) and a domain name, like server.domain.com, or is a valid IP address like '123.45.67.89'.", @"validation error message for invalid hostname");
	}

	else if ([key isEqualToString:@"docRoot"])
	{
		newValue = [newValue stringByTrimmingFirstLine];

/// take this out to see if we can type in the equivalent of a file chooser
//		// Fix docRoot to have suffix / if it's missing
//		if (![newValue hasSuffix:@"/"])
//		{
//			newValue = [newValue stringByAppendingString:@"/"];
//		}

		// Be really lax here ... not sure what is bad in a file path
		result = YES;

		errorString
			= NSLocalizedString(@"Illegal characters found in docRoot.", @"validation error message for illegal 'stem' docRoot");
	}
	else if ([key isEqualToString:@"userName"])
	{
		newValue = [newValue stringByTrimmingFirstLine];

		NSRange whereBad
			= [newValue rangeOfCharacterFromSet:sIllegalUserNameSet];
		result = (NSNotFound == whereBad.location);

		errorString
			= NSLocalizedString(@"Illegal characters found in User ID. A User ID contains numbers and letters and underscores.", @"validation error message for illegal userID");
	}
	else if ([key isEqualToString:@"provider"])
	{
		
	}

	// Now deal with result
	if (result)
	{
		if (![*ioValue isEqualToString:newValue])
		{
			// Update the UI to reflect the "fixed" value
			NSInvocation *invocation = [NSInvocation invocationWithSelector:@selector(setValue:forKey:)
																	 target:self
																  arguments:[NSArray arrayWithObjects:newValue, key, nil]];
			[invocation performSelector:@selector(invokeWithTarget:) withObject:self afterDelay:0.0];
		}
		*ioValue = newValue;	// update the real value immediately, I guess
	}
	else	// error: construct error; don't modify *ioValue
	{
        NSDictionary *userInfoDict =
			[NSDictionary dictionaryWithObject:errorString
										forKey:NSLocalizedDescriptionKey];
        NSError *error = [[[NSError alloc] initWithDomain:kKTHostSetupErrorDomain
													 code:2
												 userInfo:userInfoDict] autorelease];
 		if (outError)
		{
			*outError = error;
		}
	}
	return result;
}

#pragma mark -
#pragma mark Delegate Methods

/*!	We can't use binding on the password field because we don't get continuous value notification on a secure text field.  But we want that, so we can bind the enabled flag of the button.
*/
- (void)controlTextDidChange:(NSNotification *)aNotification
{
	id object = [aNotification object];
	if (object == oPasswordField)
	{
		[self setValue:[[object stringValue] stringByTrimmingFirstLine] forKey:@"password"];
	}
}

#pragma mark -
#pragma mark LocalHost Reachability

/*!	Sets up a connection to our servers asking us to try to contact the local host.  No attempt is made if apache is not running, though, that sets up a status immediately.
*/
- (void) tryToReachLocalHost:(BOOL)aStartStopFlag
{
	if (![self isApacheRunning])
	{
		[self setLocalHostVerifiedStatus:LOCALHOST_NOAPACHE];
		return;
	}
	if (aStartStopFlag)
	{
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		if ([self localHostVerifiedStatus] != LOCALHOST_REACHABLE)
		{
			[self setLocalHostVerifiedStatus:LOCALHOST_UNVERIFIED];
		}

		NSFileManager *fm = [NSFileManager defaultManager];

		// Make sure that the "~/Sites" directory exists and is world-readable
		NSString *sitesPath;
		BOOL homeDirectory = (HOMEDIR == [[[self properties] valueForKey:@"localSharedMatrix"] intValue]);

		if (homeDirectory)
		{
			sitesPath = [[NSWorkspace sharedWorkspace] userSitesDirectory];
		}
		else
		{
			sitesPath = [defaults objectForKey:@"ApacheDocRoot"];
		}

		BOOL isDirectory = NO;
		if ([fm fileExistsAtPath:sitesPath isDirectory:&isDirectory])
		{
			if (isDirectory)
			{
				NSDictionary *attributes = [fm fileAttributesAtPath:sitesPath traverseLink:YES];	// TODO: verify link is OK
				unsigned long perm = [attributes filePosixPermissions];
				unsigned long neededPerm = 0755;
				if ((perm | neededPerm) != perm)
				{
					NSMutableDictionary *newAttr = [NSMutableDictionary dictionaryWithDictionary:attributes];
					// *add* in the permissions we need, on top of current permissions
					[newAttr setObject:[NSNumber numberWithUnsignedLong:perm | neededPerm] forKey:NSFilePosixPermissions];
					BOOL success = [fm changeFileAttributes:newAttr atPath:sitesPath];

					if (!success)
					{
						success = [self change:sitesPath toPermissions:perm | neededPerm];
					}
					if (!success)
					{
						if (homeDirectory)
						{
							NSRunAlertPanel(
											NSLocalizedString(@"Could not make \\U201CSites\\U201D folder readable",@"Title of alert"),
											NSLocalizedString(@"Your Sites folder needs to be readable by other users in order to host your website from your computer. You will need to make this folder fully readable (using the Finder).",@"Message in alert"),
											nil, nil, nil);
						}
						else
						{
							NSRunAlertPanel(
											NSLocalizedString(@"Could not make web server folder readable",@"Title of alert"),
											NSLocalizedString(@"The folder at '%@' needs to be readable by other users in order to host your website from your computer. You will need to make this folder fully readable (using the Finder).",@"Message in alert"),
											nil, nil, nil, sitesPath);
						}
						return;	// no point in proceeding.
					}
				}
			}
			else	// Yikes!  It's a file!
			{
				NSRunAlertPanel(
					NSLocalizedString(@"\\U201CSites\\U201D must be a folder",@"Title of alert"),
					NSLocalizedString(@"A file at the path '%@' was found. However, this must be a folder, not a file. Please replace this file with a folder.",@"Message in alert"),
					nil, nil, nil, sitesPath);
				return;	// no point in proceeding.
			}
		}
		else	// Doesn't exist, let's do it
		{
			if (homeDirectory)
			{
				BOOL success = [fm createDirectoryAtPath:sitesPath attributes:[NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithUnsignedLong:0755], NSFilePosixPermissions, nil]];
				if (!success)
				{
					NSRunAlertPanel(
									NSLocalizedString(@"Could not create \\U201CSites\\U201D folder",@"Title of alert"),
									NSLocalizedString(@"Sandvox was unable create a folder called \\U201CSites\\U201D in your home directory. You will need to repair your Mac OS X installation so that you are able to create files in your home folder.",@"Message in alert"),
									nil, nil, nil);
					return;	// no point in proceeding.
				}
			}
			else	// No webserver documents folder.  Don't try to create, this is indicative of a bigger problem.
			{
				NSRunAlertPanel(
								NSLocalizedString(@"Could not find web server documents folder.",@"Title of alert"),
								NSLocalizedString(@"Sandvox was unable to find the folder at the path '%@'. You will need repair your Mac OS X installation so that this directory exists.",@"Message in alert"),
								nil, nil, nil, sitesPath);
			}
		}

		// Now create the file
		BOOL successCreating = [self createTestFileInDirectory:sitesPath];

		if (!successCreating)
		{
			if (homeDirectory)
			{
				NSRunAlertPanel(
								NSLocalizedString(@"Could not modify \\U201CSites\\U201D folder",@"Title of alert"),
								NSLocalizedString(@"Sandvox was unable create a file inside the \\U201CSites\\U201D folder in your home directory. You will need to make this folder writable (using the Finder).",@"Message in alert"),
								nil, nil, nil);
			}
			else
			{
				int button = NSRunAlertPanel(
								NSLocalizedString(@"Could not modify web server documents folder",@"Title of alert"),
								NSLocalizedString(@"Sandvox was unable create a file inside the folder at '%@' on your computer. Do you want to make this folder writable by all users on your computer?",@"Message in alert"),
								NSLocalizedString(@"Make Writable",@"Button to make web folder writable"), NSLocalizedString(@"Cancel",@"Cancel Button"), nil, sitesPath);
				if (1 == button)
				{
					// try again!
					successCreating = [self change:sitesPath toPermissions:0777];
					if (successCreating)
					{
						successCreating = [self createTestFileInDirectory:sitesPath];
					}
					if (!successCreating)
					{
						NSRunAlertPanel(
										NSLocalizedString(@"Could not modify web server documents folder",@"Title of alert"),
										NSLocalizedString(@"Sandvox was unable create a file inside the folder at '%@' on your computer. You will need to perform this adjustment using the Finder.",@"Message in alert"),
										nil, nil, nil, sitesPath);
					}
				}
			}
			return;	// no point in proceeding.
		}
		NSString *homeBaseURL = [[[NSApp delegate] homeBaseURL] absoluteString];
		NSURLConnection *theConnection = nil;
		if (nil != homeBaseURL)
		{
			NSString *testURL = [[self globalBaseURLUsingHome:homeDirectory  allowNull:YES] stringByAppendingString:[myTemporaryTestFilePath lastPathComponent]];
			if (nil != testURL)
			{
				NSString *urlString = [NSString stringWithFormat:@"%@reachable.plist?timeout=%d&url=%@", homeBaseURL, [[defaults objectForKey:@"LocalHostVerifyTimeout"] intValue], [testURL stringByAddingPercentEscapesForURLQuery:YES]];

				NSURLRequest *theRequest
				=	[NSURLRequest requestWithURL:[NSURL URLWithUnescapedString:urlString]
									 cachePolicy:NSURLRequestReloadIgnoringCacheData
								 timeoutInterval:20.0];
				// create the connection with the request and start loading the data
				theConnection=[NSURLConnection connectionWithRequest:theRequest delegate:self];
			}
		}

		if (theConnection)
		{
			[self setReachableConnection:theConnection];
			// Create the NSMutableData that will hold the received data
			[self setConnectionData:[NSMutableData data]];

		} else {
			// inform the user that the download could not be made
			NSLog(@"unable to set up connection to home base");

		}
	}
	else	// STOP, if it was loading
	{
		[myReachableConnection cancel];
		[self setReachableConnection:nil];
		[self setConnectionData:nil];
		[self setTemporaryTestFilePath:nil];		// removes file too!
	}

}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    // this method is called when the server has determined that it
    // has enough information to create the NSURLResponse
	// it can be called multiple times, for example in the case of a
	// redirect, so each time we reset the data.
    [myConnectionData setLength:0];


	if ([response respondsToSelector:@selector(statusCode)])
	{
		int statusCode = [((NSHTTPURLResponse *)response) statusCode]; 
		if (statusCode >= 400)
		{
			[connection cancel];
			[self connection:connection didFailWithError:[NSError errorWithHTTPStatusCode:statusCode URL:[response URL]]];
		}
	}

	if ( (connection == myDownloadTestConnection) && [response respondsToSelector:@selector(textEncodingName)])
	{
		NSString *statusCode = [response textEncodingName]; 
		if (statusCode)
		{
			[self setValue:statusCode forKey:@"encoding"];		// save to dictionary so we can compare later.
		}
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    // append the new data to the myConnectionData
    [myConnectionData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	NSString *errorMessage = nil;
	if (connection == myReachableConnection)
	{
		LOG((@"connectionDidFinishLoading:myReachableConnection %@", connection));
		// do something with the data
		NSDictionary *root
			= [NSPropertyListSerialization propertyListFromData:myConnectionData
											   mutabilityOption:NSPropertyListImmutable
														 format:nil
											   errorDescription:&errorMessage];

		if (nil != root)
		{
	//		NSLog(@"%@ result connecting to %@", [root objectForKey:@"result"], [root objectForKey:@"url"] );
			// Got results!  Let's see if we could reach the
			int resultCode = [[root objectForKey:@"result"] intValue];

			if (0 == resultCode)	// some sort of error reaching the host
			{
				// See if the domain name resolves to another IP address?
				NSString *hostIP = [root objectForKey:@"REMOTE_ADDR"];
				if (![hostIP isEqualToString:[root objectForKey:@"host"]])
				{
					[self setLocalHostVerifiedStatus:LOCALHOST_WRONGCOMPUTER];
				}
				else	// general unreachable .... perhaps web server is down
				{
					[self setLocalHostVerifiedStatus:LOCALHOST_UNREACHABLE];
				}
			}
			else if (resultCode >= 400)
			{
				[self setLocalHostVerifiedStatus:LOCALHOST_404];

			}
			else if (resultCode >= 200 && resultCode < 300)
			{
				[self setLocalHostVerifiedStatus:LOCALHOST_REACHABLE];	// YEAY, WE GOT IT!!!!
				
				if (nil == [self valueForKey:@"localHostName"])
				{
					[self setValue:[root objectForKey:@"REMOTE_ADDR"] forKey:@"localHostName"];
				}
			}
			else	// Couldn't figure out what to do with this status code, leave unverified
			{
				[self setLocalHostVerifiedStatus:LOCALHOST_UNVERIFIED];
			}

			if ([myCurrentState isEqualToString:@"introduction"] || [myCurrentState isEqualToString:@"summary"])
			{
				[self updateSummaryString];
			}

		}
		else
		{
			NSLog(@"error reading verification data: %@", errorMessage);
		}

		// release the connection, and the data object
		[self setReachableConnection:nil];
		[self setConnectionData:nil];
		[self setTemporaryTestFilePath:nil];		// removes file too!

		if (myWantsNextWhenDoneLoading)
		{
			[self doNext:nil];		// doNext now that we have received data
		}
	}
	else if (connection == myDownloadTestConnection)	// downloadTestConnection
	{
		LOG((@"connectionDidFinishLoading:myDownloadTestConnection %@", connection));
		[self setDownloadTestConnection:nil];
		[self setConnectionData:nil];
		[self testConnectionDidFinishLoading];
		myDidSuccessfullyDownloadTestFile = YES;
	}
	else
	{
		LOG((@"Unknown connection %@", connection));
	}
}

- (void)connection:(NSURLConnection *)connection
		didFailWithError:(NSError *)error
{
	if (connection == myReachableConnection)
	{
		// release the connection, and the data object
		[self setReachableConnection:nil];
		[self setConnectionData:nil];

		// inform the user
	//	NSLog(@"Connection failed! Error - %@ %@", [error localizedDescription], [[error userInfo] objectForKey:NSErrorFailingURLStringKey]);

		if (myWantsNextWhenDoneLoading)
		{
			[self doNext:nil];		// doNext now that we have received data
		}
	}
	else if (connection == myDownloadTestConnection)	// downloadTestConnection
	{
		[self setDownloadTestConnection:nil];
		[self setConnectionData:nil];
		[self testConnectionDidFailWithError:error];
	}
}


#pragma mark -
#pragma mark Support

- (BOOL) change:(NSString *)aPath toPermissions:(int)aPermissions
{
	NSMutableArray *args = [NSMutableArray array];

	// permissions must be a string in octal
	[args addObject:[NSString stringWithFormat:@"%o", aPermissions]];
	[args addObject:aPath];

	BOOL result = [[NTSUTaskController sharedInstance] executeCommand:NO pathToCommand:@"/bin/chmod" withArgs:args delegate:nil];

	return result;
}

- (void) clearRemoteProperties
{
	[self setValue:nil forKey:@"provider"];
	[self setValue:nil forKey:@"regions"];
	[self setValue:nil forKey:@"notes"];
	[self setValue:nil forKey:@"homePageURL"];
	[self setValue:nil forKey:@"setupURL"];
	[self setValue:nil forKey:@"hostName"];
	[self setValue:nil forKey:@"port"];
	[self setValue:nil forKey:@"docRoot"];
	[self setValue:nil forKey:@"stemURL"];
	[self setValue:nil forKey:@"subFolder"];
	[self setValue:nil forKey:@"userName"];
	[self setValue:nil forKey:@"passedUploadURL"];
	[self setValue:nil forKey:@"storageLimitMB"];
	[self setValue:@"FTP" forKey:@"protocol"];		// default
	[self setPassword:nil];
}

- (void) updatePortPlaceholder
{
	NSString *placeholderString = [KSUtilities standardPortForProtocol:[[self properties] valueForKey:@"protocol"]];
	[[oPortField cell] setPlaceholderString:placeholderString];
	[oPortField setNeedsDisplay:YES];
}

- (BOOL) createTestFileInDirectory:(NSString *)aDirectory
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *fileName = [NSString stringWithFormat:@"Temp_%@.html", [NSString shortUUIDString]];	// DO NOT LOCALIZE
	NSString *filePath = [aDirectory stringByAppendingPathComponent:fileName];
	// Put a UTF-8 marker (will this help?) into file to ensure it's parse as UTF8.
	NSString *fileContents = [NSString stringWithFormat:NSLocalizedString(
		@"%@ This temporary file can be safely deleted if it is found.\n%@ created this file to verify that this computer was reachable over the Internet.",
		@"explanation going inside temporary file"),
		@"// !$*UTF8*$!\n\n",
		[NSApplication applicationName]];
	
	// wrapping this in html separately so we don't change any localized strings
	NSString *htmlWrapper = [NSString stringWithFormat:@"<html><body><p>%@</p></body></html>", fileContents];

	BOOL successCreating = [fm createFileAtPath:filePath
									   contents:[htmlWrapper dataUsingEncoding:NSUTF8StringEncoding]
									 attributes:[NSDictionary dictionaryWithObjectsAndKeys:
										 [NSNumber numberWithUnsignedLong:0644],
										 NSFilePosixPermissions,
										 nil]];

	[self setTemporaryTestFilePath:successCreating ? filePath : nil];
	return successCreating;
}

/*!	Update the UI to get current value for dot mac member.  Sets username variable.  Only called periodically when we're viewing the dot-mac panel.
*/
- (void) updateDotMacStatus:(NSTimer *)aTimer
{
	NSString *iToolsMember = nil;
	NSString *iToolsPassword = nil;
	
	if (![[NSURLCredentialStorage sharedCredentialStorage] getDotMacAccountName:&iToolsMember password:&iToolsPassword])
	{
		[oDotMacLabel setStringValue:[NSString stringWithFormat:NSLocalizedString(@"This website cannot be published until you have set up your MobileMe account.", @"")]];
		[self setValue:nil forKey:@"userName"];
		[oGetDotMacButton setHidden:NO];
	}
	else
	{
		[oDotMacLabel setStringValue:[NSString stringWithFormat:NSLocalizedString(@"This website will be published on your \\U201C%@\\U201D account.", "format for summary of dot mac account"), iToolsMember]];
		[self setValue:iToolsMember forKey:@"userName"];
		[oGetDotMacButton setHidden:YES];
	}
}

/*!	Update the UI to get current apache settings.  Only called periodically when we're viewing the apache panel.
*/
- (void) updateApacheStatus:(NSTimer *)aTimer
{
	BOOL apacheRunning = [self isApacheRunning];
	if (apacheRunning != myWasApacheRunning)
	{
		if (apacheRunning)
		{
			[oApacheLabel setStringValue:NSLocalizedString(@"Web sharing is now active.", @"prompt shown when web sharing is turned on")];
		}
		else
		{
			[oApacheLabel setStringValue:@""];
		}
		// force a lookup of local host
		BOOL shouldVerify = [[[self properties] valueForKey:@"localHosting"] intValue];
		[self tryToReachLocalHost:shouldVerify];
		myWasApacheRunning = apacheRunning;		// remember
	}
}


- (void)loadPasswordFromKeychain:(id)bogus
{
	NSString *password = [self passwordFromKeychain];
	[self setPassword:password];
	if (nil == password)
	{
		password = @"";
	}
	[oPasswordField setStringValue:password];
}

/*!	Password -- only try to retrieve it from the keychain if we have a host name and user name set
*/
- (NSString *)passwordFromKeychain
{
	NSString *result = nil;
	
	NSString *hostName = [[self properties] valueForKey:@"hostName"];
	NSString *userName = [[self properties] valueForKey:@"userName"];
	NSString *protocol = [[self properties] valueForKey:@"protocol"];

	NSString *port = [[[self properties] valueForKey:@"port"] description];
	if ( nil == port )
	{
		port = [KSUtilities standardPortForProtocol:protocol];
	}
	
	if (nil != hostName
		&& nil != userName
		&& ![userName isEqualToString:@""]
		&& ![hostName isEqualToString:@""])
	{
//		result = [KSUtilities keychainPasswordForServer:hostName account:userName];
		
		[[EMKeychainProxy sharedProxy] setLogsErrors:NO];
		EMInternetKeychainItem *keychainItem = [[EMKeychainProxy sharedProxy] internetKeychainItemForServer:hostName
																							   withUsername:userName 
																									   path:nil 
																									   port:[port intValue] 
																								   protocol:[KSUtilities SecProtocolTypeForProtocol:protocol]];
		
		if ( nil == keychainItem )
		{
			NSLog(@"warning: host setup did not find keychain item for server %@, user %@", hostName, userName);
		}
		
		result = [keychainItem password];
	}
	
	return result;
}

- (void)setKeychainPassword:(NSString *)aPassword
{
	NSString *hostName = [myProperties valueForKey:@"hostName"];
	NSString *userName = [myProperties valueForKey:@"userName"];
	NSString *protocol = [myProperties valueForKey:@"protocol"];
	
	NSString *port = [[myProperties valueForKey:@"port"] description];
	if ( nil == port )
	{
		port = [KSUtilities standardPortForProtocol:protocol];
	}

	if (nil != aPassword
		&& nil != hostName
		&& nil != userName
		&& ![userName isEqualToString:@""]
		&& ![hostName isEqualToString:@""])
	{
//		OSStatus result = [KSUtilities keychainSetPassword:aPassword
//												 forServer:hostName
//												   account:userName];
//		if (noErr != result)
//		{
//			NSRunAlertPanel(
//							NSLocalizedString(@"Could not store password in keychain",@"Title of alert"),
//							[NSString stringWithFormat:NSLocalizedString(@"The keychain manager returned error %d, so your password was not stored in the keychain.  You may need to run the \\U201CKeychain Access\\U201D utility and repair your keychain, and then set up your host again.",@"Message in alert"), result],
//							nil, nil, nil);
//			NSLog(@"Could not set password -- status = %d", result);
//		}

#ifdef DEBUG
		[[EMKeychainProxy sharedProxy] setLogsErrors:YES];
#else
		[[EMKeychainProxy sharedProxy] setLogsErrors:NO];
#endif
		EMInternetKeychainItem *keychainItem = [[EMKeychainProxy sharedProxy] internetKeychainItemForServer:hostName
																							   withUsername:userName 
																									   path:nil 
																									   port:[port intValue] 
																								   protocol:[KSUtilities SecProtocolTypeForProtocol:protocol]];
		if ( nil != keychainItem )
		{
			[keychainItem setPassword:aPassword];
		}
		else
		{
			[[EMKeychainProxy sharedProxy] setLogsErrors:YES];
			keychainItem = [[EMKeychainProxy sharedProxy] addInternetKeychainItemForServer:hostName 
																			  withUsername:userName 
																				  password:aPassword 
																					  path:nil
																					  port:[port intValue] 
																				  protocol:[KSUtilities SecProtocolTypeForProtocol:protocol]];
			[[EMKeychainProxy sharedProxy] setLogsErrors:NO];
		}
		
		if ( nil == keychainItem )
		{
			NSLog(@"error: unable create keychain item for server %@, user %@", hostName, userName);
		}
	}
}

// no longer used but maybe useful
//- (NSAttributedString *)attributedStringWithString:(NSString *)string
//											   url:(NSURL *)url
//										attributes:(NSDictionary *)textAttr
//{
//	NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:string attributes:textAttr];
//	NSRange openTag = [[attributedString string] rangeOfString:@"<LINK>"];
//	NSRange closeTag = [[attributedString string] rangeOfString:@"</LINK>"];
//	NSRange linkRange = NSMakeRange(openTag.location + openTag.length, closeTag.location - NSMaxRange(openTag));
//		
//	[attributedString beginEditing];
//	
//	[attributedString addAttribute:NSLinkAttributeName
//							 value:url
//							 range:linkRange];
//	
//	[attributedString addAttribute:NSForegroundColorAttributeName
//							 value:[NSColor linkColor]
//							 range:linkRange];
//	
//	[attributedString addAttribute:NSUnderlineStyleAttributeName
//							 value:[NSNumber numberWithInt:NSSingleUnderlineStyle]
//							 range:linkRange];
//
//	[attributedString endEditing];
//	
//	[attributedString deleteCharactersInRange:closeTag];
//	[attributedString deleteCharactersInRange:openTag];
//	
//	return [attributedString autorelease];
//}
//
- (void)updateSummaryString;
{
	NSMutableAttributedString *theText
		= [[[NSMutableAttributedString alloc] init] autorelease];

	NSDictionary *textAttr
		= [NSDictionary dictionaryWithObjectsAndKeys:
			[NSFont systemFontOfSize:[NSFont smallSystemFontSize]], NSFontAttributeName,
			nil];
	NSFont *boldUserFont=[[NSFontManager sharedFontManager] convertFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]] toHaveTrait:NSBoldFontMask];
	NSDictionary *boldAttr
		= [NSDictionary dictionaryWithObjectsAndKeys:
			boldUserFont, NSFontAttributeName,
			nil];
	NSDictionary *boldRedAttr
		= [NSDictionary dictionaryWithObjectsAndKeys:
			boldUserFont, NSFontAttributeName,
			[NSColor redColor], NSForegroundColorAttributeName,
			nil];
	NSAttributedString *newlines
		= [[[NSAttributedString alloc]
			initWithString:@"\n\n"
				attributes:textAttr] autorelease];

	BOOL localHosting = [[[self properties] valueForKey:@"localHosting"] intValue];
	NSString *remoteSiteURL = [self remoteSiteURL];
	BOOL remoteHosting = [[[self properties] valueForKey:@"remoteHosting"] intValue];
	BOOL remoteHostingValid
		= remoteHosting
		&& [self remoteSiteURLIsValid]
		&& [[self uploadURL] isEqualToString:[[self properties] valueForKey:@"passedUploadURL"]];
	myShouldShowConnectionTroubleshooting = NO;
	
	if (localHosting)
	{
		[theText appendAttributedString:[NSAttributedString stringFromImagePath:[self iMacImagePath]]];
		[theText appendAttributedString:newlines];
		[theText appendAttributedString:[NSAttributedString stringWithString:NSLocalizedString(@"This website will be published locally on your computer.", @"introduction of local hosting") attributes:textAttr]];
		[theText appendAttributedString:newlines];

		if ([self isApacheRunning])
		{
			[theText appendAttributedString:[NSAttributedString stringWithString:[NSString stringWithFormat:NSLocalizedString(@"It can be reached from your computer and others in your local network at %@.", @"format to show URL where it is accessible from LAN"), [self localURL]] attributes:textAttr]];
			[theText appendAttributedString:newlines];

			NSString *globalSiteURL = [self globalSiteURL];
			if (nil != globalSiteURL)
			{
				switch (myLocalHostVerifiedStatus)
				{
					case LOCALHOST_REACHABLE:
						[theText appendAttributedString:[NSAttributedString stringWithString:[NSString stringWithFormat:NSLocalizedString(@"From the Internet, it will be reachable at %@.", @"format to show URL where it is accessible from Internet"), globalSiteURL] attributes:textAttr]];
						break;
					case LOCALHOST_UNVERIFIED:
						[theText appendAttributedString:[NSAttributedString stringWithString:[NSString stringWithFormat:NSLocalizedString(@"From the Internet, it should be reachable at %@. (Not yet verified)", @"format to show URL where it is accessible from Internet -- not verified though"), globalSiteURL] attributes:textAttr]];
						break;
					default:		// any other error message
						[theText appendAttributedString:
							[NSAttributedString stringWithString:[NSString stringWithFormat:NSLocalizedString(@"Your computer could not be reached from the Internet at the URL you have specified, %@. You may need to check your hostname settings, or configure your router or local network so that your computer is reachable from the Internet.", @"warning when computer could not be reached."), globalSiteURL]  attributes:boldRedAttr]];
						[theText appendAttributedString:
							[NSAttributedString stringWithString:[NSString stringWithFormat:NSLocalizedString(@"\n\nIf you are just testing, and you are OK with your site not being accessible from the Internet, then feel free to ignore this warning.", @"second half -- warning when computer could not be reached.")]  attributes:boldAttr]];
						myShouldShowConnectionTroubleshooting = YES;
						break;
				}

			}
			else
			{
				[theText appendAttributedString:[NSAttributedString stringWithString:NSLocalizedString(@"The URL from which this site should be reachable has not been determined yet.", @"Unknown URL for the localhost") attributes:boldAttr]];
			}
		}
		else
		{
			[theText appendAttributedString:[NSAttributedString stringWithString:NSLocalizedString(@"However, web sharing must be activated in order for this to be functional.", @"web sharing not activated, in summary") attributes:boldAttr]];
		}
		[theText appendAttributedString:newlines];
	}

	if (remoteHosting)
	{
		[theText appendAttributedString:[NSAttributedString stringFromImagePath:[self serverImagePath]]];
		[theText appendAttributedString:newlines];

		if (remoteHostingValid)
		{
			if ([[[self properties] valueForKey:@"protocol"] isEqualToString:@".Mac"])
			{
				NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
				NSString *iToolsMember = [defaults objectForKey:@"iToolsMember"];

				[theText appendAttributedString:[NSAttributedString stringWithString:[NSString stringWithFormat:NSLocalizedString(@"This website will be published on your \\U201C%@\\U201D MobileMe account.", @"introduction of remote hosting for MobileMe account"), iToolsMember] attributes:textAttr]];


			}
			else
			{
				[theText appendAttributedString:[NSAttributedString stringWithString:NSLocalizedString(@"This website will be published on an external host.", @"introduction of remote hosting for non-MobileMe account") attributes:textAttr]];

				[theText appendAttributedString:newlines];
				[theText appendAttributedString:[NSAttributedString stringWithString:
												 [NSString stringWithFormat:NSLocalizedString(@"It will be transmitted via %@ to your '%@' account at %@.", @"format to summarize how URL will be published on a remote host"), [KSUtilities displayNameForProtocol:[[self properties] valueForKey:@"protocol"]], [[self properties] valueForKey:@"userName"], [[self properties] valueForKey:@"hostName"]] attributes:textAttr]];

			}
			[theText appendAttributedString:newlines];
			[theText appendAttributedString:[NSAttributedString stringWithString:
					[NSString stringWithFormat:NSLocalizedString(@"It will be reachable from the Web at %@ .", @"format to summarize how URL will be retrieved from the Web"), remoteSiteURL] attributes:textAttr]];
		}
		else
		{
			[theText appendAttributedString:[NSAttributedString stringWithString:
				NSLocalizedString(@"You have chosen to publish your website on a remote host.", @"") attributes:textAttr]];
			[theText appendAttributedString:newlines];
			[theText appendAttributedString:
				[NSAttributedString stringWithString:NSLocalizedString(@"You have not fully specified and tested your connection information. You will need to fill in the connection information and verify that you can connect to your host before this website can be published.", "warning when we dont have full host setup")
				attributes:boldRedAttr]];
			myShouldShowConnectionTroubleshooting = YES;
		}
	}

	if (!localHosting && !remoteHosting)	// NEITHER
	{
		[theText appendAttributedString:newlines];
		[theText appendAttributedString:[NSAttributedString stringFromImagePath:[self cautionPath]]];
		[theText appendAttributedString:newlines];
		[theText appendAttributedString:[NSAttributedString stringWithString:NSLocalizedString(@"This website is not set up to be published on this computer or on another host.\n\nClick Edit to set up where to publish your site.", @"summary text for unpublished website") attributes:boldAttr]];
		
	}
	
	if (myShouldShowConnectionTroubleshooting)
	{
		[theText appendAttributedString:newlines];
		NSString *msg = NSLocalizedString(@"We suggest you read the troubleshooting section of our help, using the help button on this window.", @"HSA guide (Our documentation is in English only right now)");
// NOTE: the above used to be http://wiki.karelia.com/Troubleshooting_Your_Connection so be sure that URL works too
// and more recently, http://wiki.karelia.com/Troubleshooting_Publishing_and_Connections
		[theText appendAttributedString:[[[NSAttributedString alloc] initWithString:msg
																		 attributes:textAttr] autorelease]];
	}
	
	// Help -- if not set up, or not valid
	
	if ( ((!localHosting && !remoteHosting)
		 || (localHosting && ![self isApacheRunning])
		 || (remoteHosting && !remoteHostingValid)) && !myShouldShowConnectionTroubleshooting
		 )
	{
		[theText appendAttributedString:newlines];
		NSString *msg = NSLocalizedString(@"If you are not experienced configuring your host, we suggest you read our online help, using the help button on this window.", @"HSA guide (Our documentation is in English only right now)");
		// used to point to http://wiki.karelia.com/Setting_Up_Your_Host
		[theText appendAttributedString:[[[NSAttributedString alloc] initWithString:msg
															  attributes:textAttr] autorelease]];
	}
	
	
	// CYA -- only show if all OK, not if troubleshooting

	if (!myShouldShowConnectionTroubleshooting)
	{
		[theText appendAttributedString:newlines];
		[theText appendAttributedString:[NSAttributedString stringWithString:NSLocalizedString(@"Note: Before posting materials (text, images, audio, etc.) on your site, check that you own the copyright and/or control the necessary rights.", "text to make sure content is legal") attributes:boldAttr]];
			// Append legal CYA text
	}

	NSAttributedString *hypertext = [theText hyperlinkedURLs];
	[[oSummaryTextView textStorage] setAttributedString:hypertext];
	[oSummaryTextView scrollPoint:NSZeroPoint];
	[[oIntroductionTextView textStorage] setAttributedString:hypertext];
	[oIntroductionTextView scrollPoint:NSZeroPoint];
	
	// set up cursors in text
	NSEnumerator* attrRuns = [[[oIntroductionTextView textStorage] attributeRuns] objectEnumerator];
	NSTextStorage* run;
	while ((run = [attrRuns nextObject])) {
		if ([run attribute:NSLinkAttributeName atIndex:0 effectiveRange:NULL]) {
			[run addAttribute:NSCursorAttributeName value:[NSCursor pointingHandCursor] range:NSMakeRange(0,[run length])];
		}
	};
	

}

/*!	return username of this account.  A convenience for binding.  Not called username -- that would conflict with dictionary
*/

- (NSString *)accountName
{
	return NSUserName();
}


#define countof(a) (sizeof(a)/sizeof(a[0]))

- (BOOL)isApacheRunning
{
	BOOL result = 0;
	int mib[3] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL };
	size_t count;
	int err;
	struct kinfo_proc *kp = NULL;
	unsigned int paranoidCounter = 0;

	do
	{
		if (NULL != kp)
		{
			free(kp);
			kp = NULL;
		}

		//
		// The following call gets a recommended buffer size for an actual,
		// like call, to maybe succeed.
		//

		err = sysctl(mib, countof(mib), NULL, &count, NULL, 0);
		if (-1 == err)
			break;

		kp = (struct kinfo_proc *) malloc(count);
		if (NULL == kp)
			break;

		err = sysctl(mib, countof(mib), kp, &count, NULL, 0);
		if (-1 == err && ENOMEM != errno)
		{
			free(kp);
			kp = NULL;
			break;
		}

	} while (-1 == err && paranoidCounter++ < 10);

	if (NULL != kp)
	{
		const int max = count / sizeof(struct kinfo_proc);
		int i;
		for (i = 0; i < max; ++i) {
			if (0 == strcmp(kp[i].kp_proc.p_comm, "httpd"))
			{
				result = YES;
				break;
			}
		}

		free(kp);
	}

	return result;
}

- (void)appendConnectionProgressLine:(BOOL)aNewLine format:(NSString *)format, ...
{
	if (aNewLine)
	{
		if (![myConnectionProgress hasSuffix:@"\n"])	// don't allow > 1 empty line
		{
			[self setConnectionProgress:[myConnectionProgress stringByAppendingString:@"\n"]];
		}
	}

	va_list argList;
	va_start(argList, format);
	NSString *aString = [[[NSString alloc] initWithFormat:format arguments:argList] autorelease];
	va_end(argList);

// TODO: This would be better if it was NOT localized, can I do that?
	NSLog(@"## %@", aString);
	if (aNewLine)
	{
// FIXME: this use of %C may cause a bus error -- test
		[self setConnectionProgress:[myConnectionProgress stringByAppendingFormat:@"%C %@", 0x2022, aString]];
	}
	else
	{
		[self setConnectionProgress:[myConnectionProgress stringByAppendingString:aString]];
	}
}



#pragma mark -
#pragma mark Binding Support

/*!	Value of localHosting, or localHostName, has changed ... so verify host if needed.
*/
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
	if ([keyPath isEqualToString:@"userName"] || [keyPath isEqualToString:@"hostName"])
	{
		if ([myCurrentState isEqualToString:@"host"])
		{
			// new info here, so possibly new password
			[self performSelector:@selector(loadPasswordFromKeychain:) withObject:nil afterDelay:0.0];
		}
	}
	else if ([keyPath isEqualToString:@"protocol"])
	{
		[self updatePortPlaceholder];
	}
	else if ([keyPath isEqualToString:@"dotMacPersonalDomain"])
	{
		NSString *dotMacPersonalDomain = [self valueForKey:@"dotMacPersonalDomain"];
		NSString *domain = nil;
		if (dotMacPersonalDomain)
		{
			domain = [NSString stringWithFormat:@"http://www.%@/",dotMacPersonalDomain];
		}
		else
		{
			domain = @"http://";
		}
		[self setValue:domain forKey:@"stemURL"];		// to show that nothing has been entered yet
	}
	else if ([keyPath isEqualToString:@"dotMacDomainStyle"])
	{
		// This affects various properties for dot mac.
		int style = [[[self properties] valueForKey:@"dotMacDomainStyle"] intValue];
		switch(style)
		{
			case PERSONAL_DOTMAC_DOMAIN:
				[self setValue:@"/Web/Sites/" forKey:@"docRoot"];

				NSString *dotMacPersonalDomain = [self valueForKey:@"dotMacPersonalDomain"];
				NSString *domain = nil;
				if (dotMacPersonalDomain)
				{
					domain = [NSString stringWithFormat:@"http://www.%@/",dotMacPersonalDomain];
				}
				else
				{
					domain = @"http://";
				}
				[self setValue:domain forKey:@"stemURL"];
				[self setValue:dotMacPersonalDomain forKey:@"domainName"];
				break;
			case WEB_ME_COM:
				[self setValue:@"/Web/Sites/" forKey:@"docRoot"];
				[self setValue:@"http://web.me.com/?/" forKey:@"stemURL"];
				[self setValue:@"me.com" forKey:@"domainName"];
				break;
			case WEB_MAC_COM:
				[self setValue:@"/Web/Sites/" forKey:@"docRoot"];
				[self setValue:@"http://web.mac.com/?/" forKey:@"stemURL"];
				[self setValue:@"mac.com" forKey:@"domainName"];
				break;
			case HOMEPAGE_MAC_COM:
				[self setValue:@"/Sites/" forKey:@"docRoot"];
				[self setValue:@"http://homepage.mac.com/?/" forKey:@"stemURL"];
				[self setValue:@"mac.com" forKey:@"domainName"];
				break;
		}
	}
	else
	{
 		BOOL shouldVerify = [[[self properties] valueForKey:@"localHosting"] intValue];
		[self tryToReachLocalHost:shouldVerify];
	}
}

/*!	Overriding valueForUndefinedKey allows us to look up in our dictionary as a last resort, after
valueForKey tries the accessor methods.
*/

- (id)valueForUndefinedKey:(NSString *)aKey
{
	id result = [[self properties] valueForKey:aKey];

	if (nil == result)
	{
//		NSLog(@"Nothing found in %@ for key %@", [self class], aKey);
	}
	return result;
}

/*"	Overriding this allows us to set call setValueForKey and have it stored in the properties dictionary if there is no accessor method.  Note that we update the modification timestamp
"*/
- (void)setValue:(id)value forUndefinedKey:(NSString *)key
{
#ifdef DEBUG
	if (![key isKindOfClass:[NSString class]])
	{
		[NSException raise: NSInvalidArgumentException
					format: @"You cannot set the property of %@ to be a non-string, %@", [self class], [value description]];
	}
#endif
	[[self properties] setValue:value forKey:key];
}

@end

@implementation ProtocolToIndexTransformer

+ (Class)transformedValueClass;
{
    return [NSNumber class];
}

+ (BOOL)allowsReverseTransformation;
{
    return YES;
}

- (id)transformedValue:(id)value;
{
    int number = 0;
	id result = nil;
    if (value == nil)
	{
		return nil;
	}
	if ([value respondsToSelector:@selector(lowercaseString)])
	{
		NSString *key = [value lowercaseString];
		if ([key isEqualToString:@"webdav"] || [key isEqualToString:@".mac"])
					// handle conversion from .Mac back to webdav to be graceful
					// since that protocol is hidden from the user
		{
			number = 1;
		}
		else if ([key isEqualToString:@"ftp"])
		{
			number = 0;
		}
		else if ([key isEqualToString:@"sftp"])
		{
			number = 2;
		}
		result =[NSNumber numberWithInt:number];
	}
	else
	{
		NSLog(@"Value %@ (%@) is not a string.", [[value description] condenseWhiteSpace], [value class]);
    }
    return result;
}

- (id)reverseTransformedValue:(id)value;
{
	NSString *result = nil;
    if (value == nil) return nil;

    // Attempt to get a reasonable value from the
    // value object.
    if ([value respondsToSelector: @selector(intValue)])
	{
		if ([value intValue] > 2)
		{
			[NSException raise: NSInternalInconsistencyException
						format: @"Value (%@) is out of range.",
				value];
		}
		NSArray *strings = [NSArray arrayWithObjects:@"FTP", @"WebDAV", @"SFTP", @".Mac", nil];
		result = [strings objectAtIndex:[value intValue]];

    } else {
        [NSException raise: NSInternalInconsistencyException
                    format: @"Value (%@) does not respond to -intValue.",
			[value class]];
    }

    return result;
}

@end

